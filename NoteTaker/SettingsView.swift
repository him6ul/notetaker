import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settings: AppSettings
    @State private var appPassword = ""
    @State private var savedNote = ""

    var body: some View {
        Form {
            Section("General") {
                Toggle("Open NoteTaker at login", isOn: $settings.launchAtLogin)
                Text("NoteTaker lives in the menu bar. Enable this to have it ready every time you log in.")
                    .font(.caption).foregroundStyle(.secondary)
            }

            Section("Email") {
                TextField("Send notes to", text: $settings.recipient)
                TextField("From (Gmail account)", text: $settings.sender)
                SecureField("Gmail App Password", text: $appPassword)
                HStack {
                    Button("Save Password") {
                        settings.appPassword = appPassword
                        savedNote = appPassword.isEmpty ? "Password cleared." : "Password saved to Keychain."
                    }
                    Text(savedNote).font(.caption).foregroundStyle(.secondary)
                }
                Text("Generate an App Password at Google Account → Security → 2-Step Verification → App passwords.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Models") {
                TextField("Whisper model", text: $settings.whisperModel)
                Text("e.g. openai_whisper-base.en (fast) or openai_whisper-small.en (more accurate).")
                    .font(.caption).foregroundStyle(.secondary)
                TextField("Ollama model", text: $settings.ollamaModel)
                Text("Must be pulled locally, e.g. `ollama pull llama3.1:8b`.")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
        .frame(width: 460, height: 460)
        .onAppear { appPassword = settings.appPassword }
    }
}
