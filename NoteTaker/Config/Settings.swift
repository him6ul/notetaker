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
    /// Whether NoteTaker launches automatically at login. Changes are applied to the OS immediately.
    @Published var launchAtLogin: Bool {
        didSet {
            defaults.set(launchAtLogin, forKey: "launchAtLogin")
            LoginItem.setEnabled(launchAtLogin)
        }
    }

    private let defaults = UserDefaults.standard

    private init() {
        recipient = defaults.string(forKey: "recipient") ?? "him6ul@gmail.com"
        sender = defaults.string(forKey: "sender") ?? "him6ul@gmail.com"
        whisperModel = defaults.string(forKey: "whisperModel") ?? "openai_whisper-base.en"
        ollamaModel = defaults.string(forKey: "ollamaModel") ?? "llama3.1:8b"
        launchAtLogin = defaults.object(forKey: "launchAtLogin") as? Bool ?? true
        // Reconcile the OS login-item registration with the stored preference on every launch.
        LoginItem.setEnabled(launchAtLogin)
    }

    /// The Gmail App Password for the sender account (from Keychain).
    var appPassword: String {
        get { Keychain.password(account: sender) ?? "" }
        set { Keychain.setPassword(newValue, account: sender) }
    }
}
