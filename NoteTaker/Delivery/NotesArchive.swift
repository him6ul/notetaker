import Foundation

/// Persists a session's notes to `~/Documents/NoteTaker` as a Markdown file, so notes
/// survive even if the review window is closed, discarded, or the app quits.
enum NotesArchive {
    /// The folder all sessions are written to.
    static var folder: URL {
        let base = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Documents")
        return base.appendingPathComponent("NoteTaker", isDirectory: true)
    }

    /// Filename is derived from the session date, so re-saving the *same* session
    /// (e.g. after the user edits and sends) overwrites its file rather than duplicating it.
    static func fileURL(for date: Date) -> URL {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = "yyyy-MM-dd HHmmss"
        return folder.appendingPathComponent("Meeting Notes \(df.string(from: date)).md")
    }

    @discardableResult
    static func save(_ markdown: String, for date: Date) throws -> URL {
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = fileURL(for: date)
        try markdown.write(to: url, atomically: true, encoding: .utf8)
        return url
    }
}
