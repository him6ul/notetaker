import Foundation
import Combine

/// Editable contents of the review window shown after Stop, before anything is emailed.
@MainActor
final class ReviewModel: ObservableObject {
    @Published var recipient: String
    @Published var summary: String
    @Published var observations: String   // one per line
    @Published var actions: String        // one per line
    @Published var ideas: String          // one per line
    @Published var transcript: String

    /// Set by AppState while a send is in flight / after a failure.
    @Published var isSending = false
    @Published var statusLine = ""

    /// Where this session was auto-saved on disk (set by AppState).
    @Published var savedURL: URL?

    let date: Date

    init(recipient: String, notes: MeetingNotes, transcript: String, date: Date) {
        self.recipient = recipient
        self.date = date
        self.summary = notes.summary
        self.observations = notes.observations.joined(separator: "\n")
        self.actions = notes.actions.map { item in
            var line = item.task
            if let owner = item.owner, !owner.isEmpty { line += " — owner: \(owner)" }
            if let due = item.due, !due.isEmpty { line += " — due: \(due)" }
            return line
        }.joined(separator: "\n")
        self.ideas = notes.ideas.joined(separator: "\n")
        self.transcript = transcript
    }

    var subject: String {
        let stamp = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        return "Meeting Notes — \(stamp)"
    }

    /// Renders the (possibly edited) fields into the plaintext email body.
    func emailBody() -> String {
        func bullets(_ text: String) -> [String] {
            let lines = text
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return lines.isEmpty ? ["(none)"] : lines.map { "• \($0)" }
        }

        let stamp = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        var lines: [String] = []
        lines.append("Meeting Notes — \(stamp)")
        lines.append(String(repeating: "=", count: 40))
        lines.append("")
        lines.append("SUMMARY")
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append(trimmedSummary.isEmpty ? "(none)" : trimmedSummary)
        lines.append("")
        lines.append("OBSERVATIONS")
        lines.append(contentsOf: bullets(observations))
        lines.append("")
        lines.append("ACTIONS")
        lines.append(contentsOf: bullets(actions))
        lines.append("")
        lines.append("IDEAS")
        lines.append(contentsOf: bullets(ideas))
        lines.append("")
        lines.append(String(repeating: "-", count: 40))
        lines.append("FULL TRANSCRIPT")
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append(trimmedTranscript.isEmpty ? "(empty)" : trimmedTranscript)
        return lines.joined(separator: "\n")
    }

    /// Renders the (possibly edited) fields into a Markdown document for the on-disk archive.
    func markdown() -> String {
        func bullets(_ text: String) -> String {
            let items = text
                .split(separator: "\n", omittingEmptySubsequences: true)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
            return items.isEmpty ? "_(none)_" : items.map { "- \($0)" }.joined(separator: "\n")
        }

        let stamp = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        let trimmedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)

        return """
        # Meeting Notes — \(stamp)

        ## Summary
        \(trimmedSummary.isEmpty ? "_(none)_" : trimmedSummary)

        ## Observations
        \(bullets(observations))

        ## Actions
        \(bullets(actions))

        ## Ideas
        \(bullets(ideas))

        ---

        ## Full Transcript
        \(trimmedTranscript.isEmpty ? "_(empty)_" : trimmedTranscript)
        """
    }
}
