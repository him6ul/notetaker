import AVFoundation
import ScreenCaptureKit

/// Captures system audio (the far side of a call, anything playing through the speakers)
/// via ScreenCaptureKit and emits 16 kHz mono float samples.
///
/// ScreenCaptureKit requires the Screen Recording permission; the first `start()` triggers
/// the system prompt. We capture the smallest possible video (audio-only isn't supported
/// standalone before macOS 15, so we attach a tiny display filter) and only consume audio.
final class SystemAudioCapture: NSObject, SCStreamOutput {
    private var stream: SCStream?
    private let resampler = Resampler()
    private var onSamples: (([Float]) -> Void)?
    private let audioQueue = DispatchQueue(label: "com.egain.notetaker.systemaudio")

    func start(onSamples: @escaping ([Float]) -> Void) async throws {
        self.onSamples = onSamples

        let content = try await SCShareableContent.excludingDesktopWindows(false, onScreenWindowsOnly: false)
        guard let display = content.displays.first else {
            throw NSError(domain: "NoteTaker", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "No display available for system-audio capture."])
        }

        // Exclude our own app so we never record our own output.
        let ourApp = content.applications.first { $0.bundleIdentifier == Bundle.main.bundleIdentifier }
        let filter = SCContentFilter(
            display: display,
            excludingApplications: ourApp.map { [$0] } ?? [],
            exceptingWindows: []
        )

        let config = SCStreamConfiguration()
        config.capturesAudio = true
        config.excludesCurrentProcessAudio = true
        config.sampleRate = 48_000
        config.channelCount = 2
        // Keep the mandatory video stream tiny and slow — we discard it.
        config.width = 2
        config.height = 2
        config.minimumFrameInterval = CMTime(value: 1, timescale: 1)
        config.queueDepth = 5

        let stream = SCStream(filter: filter, configuration: config, delegate: nil)
        try stream.addStreamOutput(self, type: .audio, sampleHandlerQueue: audioQueue)
        try await stream.startCapture()
        self.stream = stream
    }

    func stop() async {
        if let stream {
            try? await stream.stopCapture()
        }
        stream = nil
        onSamples = nil
    }

    // MARK: SCStreamOutput

    func stream(_ stream: SCStream, didOutputSampleBuffer sampleBuffer: CMSampleBuffer, of type: SCStreamOutputType) {
        guard type == .audio, sampleBuffer.isValid,
              let pcm = Self.pcmBuffer(from: sampleBuffer) else { return }
        guard let samples = resampler.resample(pcm), !samples.isEmpty else { return }
        onSamples?(samples)
    }

    /// Builds an AVAudioPCMBuffer from a CoreMedia audio sample buffer.
    private static func pcmBuffer(from sampleBuffer: CMSampleBuffer) -> AVAudioPCMBuffer? {
        guard let formatDesc = CMSampleBufferGetFormatDescription(sampleBuffer),
              var asbd = CMAudioFormatDescriptionGetStreamBasicDescription(formatDesc)?.pointee,
              let format = AVAudioFormat(streamDescription: &asbd) else { return nil }

        let frameCount = AVAudioFrameCount(CMSampleBufferGetNumSamples(sampleBuffer))
        guard frameCount > 0,
              let pcm = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else { return nil }
        pcm.frameLength = frameCount

        let status = CMSampleBufferCopyPCMDataIntoAudioBufferList(
            sampleBuffer,
            at: 0,
            frameCount: Int32(frameCount),
            into: pcm.mutableAudioBufferList
        )
        return status == noErr ? pcm : nil
    }
}
