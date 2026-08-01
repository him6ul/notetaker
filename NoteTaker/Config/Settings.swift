import Foundation
import Combine

/// User-facing configuration, persisted in UserDefaults (the App Password lives in Keychain).
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    @Published var recipient: String {
        didSet { defaults.set(recipient, forKey: "recipient") }
    }
    @Published var sender: String {
        didSet { defaults.set(sender, forKey: "sender") }
    }
    @Published var whisperModel: String {
        didSet { defaults.set(whisperModel, forKey: "whisperModel") }
    }
    @Published var ollamaModel: String {
        didSet { defaults.set(ollamaModel, forKey: "ollamaModel") }
    }

    private let defaults = UserDefaults.standard

    private init() {
        recipient = defaults.string(forKey: "recipient") ?? "him6ul@gmail.com"
        sender = defaults.string(forKey: "sender") ?? "him6ul@gmail.com"
        whisperModel = defaults.string(forKey: "whisperModel") ?? "openai_whisper-base.en"
        ollamaModel = defaults.string(forKey: "ollamaModel") ?? "llama3.1:8b"
    }

    /// The Gmail App Password for the sender account (from Keychain).
    var appPassword: String {
        get { Keychain.password(account: sender) ?? "" }
        set { Keychain.setPassword(newValue, account: sender) }
    }
}
