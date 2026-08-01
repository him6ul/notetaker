import Foundation
import Combine
import UserNotifications
import AppKit
import SwiftUI

/// Accumulates float samples from one audio source and drains them in chunks.
private final class SourceBuffer {
    private var samples: [Float] = []
    private var startTime: Date?
    private let lock = NSLock()

    func append(_ incoming: [Float]) {
        lock.lock()
        if samples.isEmpty { startTime = Date() }
        samples.append(contentsOf: incoming)
        lock.unlock()
    }

    /// Returns and clears the accumulated samples, plus when the chunk began.
    func drain() -> (samples: [Float], start: Date)? {
        lock.lock(); defer { lock.unlock() }
        guard !samples.isEmpty, let start = startTime else { return nil }
        let out = samples
        samples.removeAll(keepingCapacity: true)
        startTime = nil
        return (out, start)
    }
}

/// Orchestrates the whole pipeline: capture → transcribe → summarize → email.
@MainActor
final class AppState: ObservableObject {
    enum Phase: Equatable {
        case idle
        case preparing
        case listening
        case processing
        case reviewing
        case error(String)
    }

    @Published private(set) var phase: Phase = .idle
    @Published private(set) var statusText = "Ready"
    @Published private(set) var segmentCount = 0

    var isListening: Bool { phase == .listening }
    var isBusy: Bool { phase == .preparing || phase == .processing || phase == .reviewing }

    private let settings = AppSettings.shared
    private let micCapture = MicCapture()
    private let systemCapture = SystemAudioCapture()
    private let store = TranscriptStore()
    private var transcriber: Transcriber?

    private let micBuffer = SourceBuffer()
    private let systemBuffer = SourceBuffer()

    private var flushTimer: Timer?
    private var clockTimer: Timer?
    private var startedAt: Date?

    private var reviewWindow: NSWindow?
    private var reviewModel: ReviewModel?
    private var reviewWindowDelegate: WindowCloseDelegate?

    private let chunkSeconds: TimeInterval = 8

    init() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
    }

    // MARK: - Control

    func start() {
        guard phase == .idle || isError else { return }
        phase = .preparing
        statusText = "Requesting microphone…"

        MicCapture.requestPermission { [weak self] granted in
            guard let self else { return }
            guard granted else {
                self.fail("Microphone permission denied. Enable it in System Settings → Privacy.")
                return
            }
            Task { await self.beginCapture() }
        }
    }

    private func beginCapture() async {
        store.reset()
        segmentCount = 0
        statusText = "Loading Whisper model…"

        do {
            let transcriber = Transcriber(modelName: settings.whisperModel)
            try await transcriber.prepare()
            self.transcriber = transcriber

            statusText = "Starting audio…"
            try micCapture.start { [weak self] samples in self?.micBuffer.append(samples) }
            try await systemCapture.start { [weak self] samples in self?.systemBuffer.append(samples) }

            startedAt = Date()
            phase = .listening
            startTimers()
            updateStatus()
        } catch {
            micCapture.stop()
            await systemCapture.stop()
            fail("Couldn't start capture: \(error.localizedDescription)")
        }
    }

    func stop() {
        guard phase == .listening else { return }
        stopTimers()
        micCapture.stop()
        Task {
            await systemCapture.stop()
            await flush()          // catch the final partial chunks
            await finishAndReview()
        }
    }

    // MARK: - Timers

    private func startTimers() {
        flushTimer = Timer.scheduledTimer(withTimeInterval: chunkSeconds, repeats: true) { [weak self] _ in
            Task { await self?.flush() }
        }
        clockTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.updateStatus() }
        }
    }

    private func stopTimers() {
        flushTimer?.invalidate(); flushTimer = nil
        clockTimer?.invalidate(); clockTimer = nil
    }

    // MARK: - Pipeline

    private func flush() async {
        guard let transcriber else { return }
        await transcribeDrain(micBuffer.drain(), speaker: .me, using: transcriber)
        await transcribeDrain(systemBuffer.drain(), speaker: .others, using: transcriber)
        segmentCount = store.count
    }

    private func transcribeDrain(_ chunk: (samples: [Float], start: Date)?,
                                 speaker: Speaker,
                                 using transcriber: Transcriber) async {
        guard let chunk else { return }
        do {
            let text = try await transcriber.transcribe(chunk.samples)
            if !text.isEmpty {
                store.append(speaker: speaker, startTime: chunk.start, text: text)
            }
        } catch {
            // Non-fatal: drop this chunk, keep listening.
        }
    }

    /// After Stop: extract notes, then open the editable review window. Nothing is
    /// emailed until the user presses Send in that window.
    private func finishAndReview() async {
        phase = .processing
        let date = Date()
        let transcript = store.rendered()

        guard !transcript.isEmpty else {
            notify(title: "NoteTaker", body: "Nothing was transcribed — no email sent.")
            reset()
            return
        }

        statusText = "Extracting ideas & action items…"
        let notes: MeetingNotes
        do {
            notes = try await Summarizer(model: settings.ollamaModel).extract(from: transcript)
        } catch {
            fail("Analysis failed: \(error.localizedDescription)")
            notify(title: "NoteTaker — analysis failed", body: error.localizedDescription)
            return
        }

        let model = ReviewModel(recipient: settings.recipient,
                                notes: notes,
                                transcript: transcript,
                                date: date)
        presentReview(model)
    }

    // MARK: - Review window

    private func presentReview(_ model: ReviewModel) {
        reviewModel = model
        phase = .reviewing
        statusText = "Review your notes, then send."

        let view = ReviewView(
            model: model,
            onSend: { [weak self] in self?.sendReviewed() },
            onDiscard: { [weak self] in self?.discardReview() }
        )
        let window = NSWindow(contentViewController: NSHostingController(rootView: view))
        window.title = "Review Notes"
        window.styleMask = [.titled, .closable, .resizable]
        window.setContentSize(NSSize(width: 620, height: 700))
        window.center()
        window.isReleasedWhenClosed = false
        let delegate = WindowCloseDelegate { [weak self] in
            MainActor.assumeIsolated { self?.userClosedReviewWindow() }
        }
        window.delegate = delegate
        reviewWindow = window
        reviewWindowDelegate = delegate

        // A menu-bar (accessory) app can't front a normal window until it becomes a
        // regular app; restore accessory mode when the review window closes.
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    private func sendReviewed() {
        guard let model = reviewModel else { return }
        model.isSending = true
        model.statusLine = "Sending…"

        Task {
            do {
                let body = model.emailBody()
                let mailer = Mailer(sender: settings.sender,
                                    recipient: model.recipient,
                                    appPassword: settings.appPassword)
                try mailer.send(subject: model.subject, body: body, date: model.date)
                notify(title: "NoteTaker", body: "Notes emailed to \(model.recipient).")
                closeReview()
                reset()
            } catch {
                // Keep the window open so the user can fix (e.g. set the App Password) and retry.
                model.isSending = false
                model.statusLine = "Send failed: \(error.localizedDescription)"
                notify(title: "NoteTaker — send failed", body: error.localizedDescription)
            }
        }
    }

    private func discardReview() {
        notify(title: "NoteTaker", body: "Notes discarded — nothing was sent.")
        closeReview()
        reset()
    }

    /// The user clicked the window's red close button (not a Send/Discard button).
    private func userClosedReviewWindow() {
        guard reviewModel != nil else { return }   // ignore programmatic closes
        reviewModel = nil
        reviewWindow = nil
        reviewWindowDelegate = nil
        NSApp.setActivationPolicy(.accessory)
        notify(title: "NoteTaker", body: "Notes discarded — nothing was sent.")
        reset()
    }

    private func closeReview() {
        reviewModel = nil          // marks this as a programmatic close for the delegate
        reviewWindowDelegate = nil
        let window = reviewWindow
        reviewWindow = nil
        window?.delegate = nil
        NSApp.setActivationPolicy(.accessory)
        window?.close()
    }

    // MARK: - Status helpers

    private var isError: Bool { if case .error = phase { return true }; return false }

    private func updateStatus() {
        guard phase == .listening, let startedAt else { return }
        let elapsed = Int(Date().timeIntervalSince(startedAt))
        statusText = String(format: "Listening %02d:%02d · %d segments", elapsed / 60, elapsed % 60, store.count)
        segmentCount = store.count
    }

    private func reset() {
        phase = .idle
        statusText = "Ready"
        transcriber = nil
        startedAt = nil
    }

    private func fail(_ message: String) {
        stopTimers()
        phase = .error(message)
        statusText = message
    }

    private func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: nil)
        UNUserNotificationCenter.current().add(request)
    }
}

/// Bridges NSWindow's close event to a closure (delegate is held weakly by NSWindow).
final class WindowCloseDelegate: NSObject, NSWindowDelegate {
    private let onClose: () -> Void
    init(onClose: @escaping () -> Void) { self.onClose = onClose }
    func windowWillClose(_ notification: Notification) { onClose() }
}
