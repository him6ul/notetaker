import Foundation

/// The two audio sources we label in the transcript.
enum Speaker: String {
    case me = "Me"
    case others = "Others"
}

/// One transcribed utterance, tagged with who spoke and when (for chronological merge).
struct TranscriptSegment: Identifiable {
    let id = UUID()
    let speaker: Speaker
    let startTime: Date
    let text: String
}

/// Thread-safe collection of labeled, timestamped segments. Renders a merged transcript.
final class TranscriptStore {
    private var segments: [TranscriptSegment] = []
    private let lock = NSLock()

    var count: Int {
        lock.lock(); defer { lock.unlock() }
        return segments.count
    }

    func append(speaker: Speaker, startTime: Date, text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        lock.lock()
        segments.append(TranscriptSegment(speaker: speaker, startTime: startTime, text: trimmed))
        lock.unlock()
    }

    func reset() {
        lock.lock(); segments.removeAll(); lock.unlock()
    }

    /// The full transcript, sorted by time, with "Me:" / "Others:" labels.
    func rendered() -> String {
        lock.lock(); let sorted = segments.sorted { $0.startTime < $1.startTime }; lock.unlock()
        return sorted
            .map { "\($0.speaker.rawValue): \($0.text)" }
            .joined(separator: "\n")
    }
}
