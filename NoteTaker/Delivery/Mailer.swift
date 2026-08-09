import Foundation

/// Sends the notes email via Gmail SMTP by shelling out to the system `curl`
/// (which speaks SMTP-over-TLS natively — no third-party SMTP library needed).
struct Mailer {
    let sender: String
    let recipient: String
    let appPassword: String

    enum MailError: LocalizedError {
        case missingPassword
        case sendFailed(String)

        var errorDescription: String? {
            switch self {
            case .missingPassword:
                return "No Gmail App Password set. Add one in NoteTaker → Settings."
            case .sendFailed(let detail):
                return "Email send failed: \(detail)"
            }
        }
    }

    /// Renders the plaintext email body from transcript + extracted notes.
    static func body(notes: MeetingNotes, transcript: String, date: Date) -> String {
        var lines: [String] = []
        let stamp = DateFormatter.localizedString(from: date, dateStyle: .medium, timeStyle: .short)
        lines.append("Meeting Notes — \(stamp)")
        lines.append(String(repeating: "=", count: 40))
        lines.append("")
        lines.append("SUMMARY")
        lines.append(notes.summary.isEmpty ? "(none)" : notes.summary)
        lines.append("")
        lines.append("OBSERVATIONS")
        if notes.observations.isEmpty {
            lines.append("(none)")
        } else {
            for obs in notes.observations { lines.append("• \(obs)") }
        }
        lines.append("")
        lines.append("ACTIONS")
        if notes.actions.isEmpty {
            lines.append("(none)")
        } else {
            for item in notes.actions {
                var detail = "• \(item.task)"
                if let owner = item.owner, !owner.isEmpty { detail += " — owner: \(owner)" }
                if let due = item.due, !due.isEmpty { detail += " — due: \(due)" }
                lines.append(detail)
            }
        }
        lines.append("")
        lines.append("IDEAS")
        if notes.ideas.isEmpty {
            lines.append("(none)")
        } else {
            for idea in notes.ideas { lines.append("• \(idea)") }
        }
        lines.append("")
        lines.append(String(repeating: "-", count: 40))
        lines.append("FULL TRANSCRIPT")
        lines.append(transcript.isEmpty ? "(empty)" : transcript)
        return lines.joined(separator: "\n")
    }

    /// Builds the RFC-822 message (CRLF line endings, required by SMTP).
    private func message(subject: String, body: String, date: Date) -> String {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        let headers = [
            "From: \(sender)",
            "To: \(recipient)",
            "Subject: \(subject)",
            "Date: \(df.string(from: date))",
            "MIME-Version: 1.0",
            "Content-Type: text/plain; charset=UTF-8",
            ""
        ]
        return (headers.joined(separator: "\r\n") + "\r\n" + body.replacingOccurrences(of: "\n", with: "\r\n"))
    }

    /// Writes the message to a temp file and sends it via curl. Returns the curl argument
    /// list actually used (password redacted) for logging/dry-run.
    @discardableResult
    func send(subject: String, body: String, date: Date, dryRun: Bool = false) throws -> [String] {
        let cleanPassword = appPassword.replacingOccurrences(of: " ", with: "")
        guard !cleanPassword.isEmpty else { throw MailError.missingPassword }

        let eml = message(subject: subject, body: body, date: date)
        let tmp = FileManager.default.temporaryDirectory
            .appendingPathComponent("notetaker-\(UUID().uuidString).eml")
        try eml.write(to: tmp, atomically: true, encoding: .utf8)
        defer { if !dryRun { try? FileManager.default.removeItem(at: tmp) } }

        let args = [
            "--silent", "--show-error",
            "--url", "smtps://smtp.gmail.com:465",
            "--ssl-reqd",
            "--mail-from", sender,
            "--mail-rcpt", recipient,
            "--user", "\(sender):\(cleanPassword)",
            "--upload-file", tmp.path
        ]

        if dryRun {
            var redacted = args
            if let i = redacted.firstIndex(of: "\(sender):\(cleanPassword)") {
                redacted[i] = "\(sender):********"
            }
            return ["/usr/bin/curl"] + redacted
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/curl")
        process.arguments = args
        let errPipe = Pipe()
        process.standardError = errPipe
        try process.run()
        process.waitUntilExit()

        if process.terminationStatus != 0 {
            let errData = errPipe.fileHandleForReading.readDataToEndOfFile()
            let msg = String(data: errData, encoding: .utf8) ?? "curl exited \(process.terminationStatus)"
            throw MailError.sendFailed(msg.isEmpty ? "curl exited \(process.terminationStatus)" : msg)
        }

        var redacted = args
        if let i = redacted.firstIndex(of: "\(sender):\(cleanPassword)") {
            redacted[i] = "\(sender):********"
        }
        return ["/usr/bin/curl"] + redacted
    }
}
