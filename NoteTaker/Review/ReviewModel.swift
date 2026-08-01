import Foundation
import Combine

/// Editable contents of the review window shown after Stop, before anything is emailed.
@MainActor
final class ReviewModel: ObservableObject {
    @Published var recipient: String
    @Published var summary: String
    @Published var ideas: String          // one per line
    @Published var actionItems: String    // one per line
    @Published var transcript: String

    /// Set by AppState while a send is in flight / after a failure.
    @Published var isSending = false
    @Published var statusLine = ""

    let date: Date

    init(recipient: String, notes: MeetingNotes, transcript: String, date: Date) {
        self.recipient = recipient
        self.date = date
        self.summary = notes.summary
        self.ideas = notes.ideas.joined(separator: "\n")
        self.actionItems = notes.action_items.map { item in
            var line = item.task
            if let owner = item.owner, !owner.isEmpty { line += " — owner: \(owner)" }
            if let due = item.due, !due.isEmpty { line += " — due: \(due)" }
            return line
        }.joined(separator: "\n")
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
        lines.append("IDEAS")
        lines.append(contentsOf: bullets(ideas))
        lines.append("")
        lines.append("ACTION ITEMS")
        lines.append(contentsOf: bullets(actionItems))
        lines.append("")
        lines.append(String(repeating: "-", count: 40))
        lines.append("FULL TRANSCRIPT")
        let trimmedTranscript = transcript.trimmingCharacters(in: .whitespacesAndNewlines)
        lines.append(trimmedTranscript.isEmpty ? "(empty)" : trimmedTranscript)
        return lines.joined(separator: "\n")
    }
}
