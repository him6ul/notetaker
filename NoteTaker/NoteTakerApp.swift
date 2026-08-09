import SwiftUI

@main
struct NoteTakerApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var settings = AppSettings.shared

    var body: some Scene {
        MenuBarExtra("NoteTaker", systemImage: appState.isListening ? "waveform.circle.fill" : "waveform.circle") {
            MenuContent()
                .environmentObject(appState)
                .environmentObject(settings)
        }
        .menuBarExtraStyle(.window)

        SwiftUI.Settings {
            SettingsView()
                .environmentObject(settings)
        }
    }
}

/// The dropdown shown from the menu-bar icon.
struct MenuContent: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: appState.isListening ? "waveform.circle.fill" : "waveform.circle")
                    .foregroundStyle(appState.isListening ? .red : .secondary)
                Text("NoteTaker").font(.headline)
            }

            Text(appState.statusText)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Divider()

            if appState.isListening {
                Button {
                    appState.stop()
                } label: {
                    Label("Stop & Review Notes", systemImage: "stop.circle.fill")
                }
            } else {
                Button {
                    appState.start()
                } label: {
                    Label("Start Listening", systemImage: "record.circle")
                }
                .disabled(appState.isBusy)
            }

            if appState.canRetrySummary {
                Button {
                    appState.retrySummary()
                } label: {
                    Label("Retry Summary", systemImage: "arrow.clockwise")
                }
            }

            Divider()

            Button("Settings…") { openSettings() }
            Button("Quit NoteTaker") { NSApplication.shared.terminate(nil) }
        }
        .padding(12)
        .frame(width: 260)
    }
}
