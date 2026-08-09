import SwiftUI

/// The editable review window: tweak the notes and transcript, then Send or Discard.
struct ReviewView: View {
    @ObservedObject var model: ReviewModel
    let onSend: () -> Void
    let onDiscard: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "doc.text.magnifyingglass")
                Text("Review Notes").font(.title3).bold()
                Spacer()
                Text(DateFormatter.localizedString(from: model.date, dateStyle: .medium, timeStyle: .short))
                    .font(.caption).foregroundStyle(.secondary)
            }

            HStack {
                Text("To:").foregroundStyle(.secondary)
                TextField("recipient@example.com", text: $model.recipient)
                    .textFieldStyle(.roundedBorder)
                    .disabled(model.isSending)
            }

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    field("Summary", text: $model.summary, minHeight: 70)
                    field("Observations (one per line)", text: $model.observations, minHeight: 90)
                    field("Actions (one per line)", text: $model.actions, minHeight: 90)
                    field("Ideas (one per line)", text: $model.ideas, minHeight: 90)
                    field("Transcript", text: $model.transcript, minHeight: 160)
                }
            }

            if let url = model.savedURL {
                Label("Saved to \(url.path(percentEncoded: false))", systemImage: "checkmark.circle")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
            }

            if !model.statusLine.isEmpty {
                Text(model.statusLine)
                    .font(.caption)
                    .foregroundStyle(model.isSending ? Color.secondary : Color.red)
            }

            HStack {
                Button(role: .destructive) { onDiscard() } label: {
                    Label("Discard", systemImage: "trash")
                }
                .disabled(model.isSending)

                Spacer()

                if model.isSending {
                    ProgressView().controlSize(.small)
                }

                Button { onSend() } label: {
                    Label("Send Notes", systemImage: "paperplane.fill")
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isSending)
            }
        }
        .padding(16)
        .frame(minWidth: 560, minHeight: 620)
    }

    private func field(_ title: String, text: Binding<String>, minHeight: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            TextEditor(text: text)
                .font(.body)
                .frame(minHeight: minHeight)
                .padding(4)
                .overlay(RoundedRectangle(cornerRadius: 6).stroke(Color.secondary.opacity(0.25)))
                .disabled(model.isSending)
        }
    }
}
