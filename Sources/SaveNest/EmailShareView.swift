import SwiftUI
import AppKit
import SaveNestCore

struct EmailShareView: View {
    let link: SavedLink
    @Environment(\.dismiss) private var dismiss
    @State private var subject: String
    @State private var note: String
    @State private var includeNote = false
    @State private var error: String?
    @State private var service: NSSharingService?

    init(link: SavedLink) {
        self.link = link
        _subject = State(initialValue: EmailShare.subject(link.title))
        _note = State(initialValue: link.note)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sheetHeading("Pass it along.", subtitle: "A link, and a thought if you like.")
            VStack(alignment: .leading, spacing: 7) {
                fieldLabel("SUBJECT")
                TextField("An article for you", text: $subject).textFieldStyle(.roundedBorder)
                Text(link.url).font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(2).textSelection(.enabled)
            }
            Toggle("Include a note", isOn: $includeNote).toggleStyle(.checkbox).font(.system(size: 12))
            if includeNote {
                NoteEditor(text: $note, height: 120)
                Text("For this email only. Your saved note stays the same.").font(.system(size: 11)).foregroundStyle(Color.muted)
            }
            Text("Choose a recipient and send from Mail.").font(.system(size: 11)).foregroundStyle(Color.muted)
            if let error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
            HStack {
                if error != nil {
                    Button("Copy email text") {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(EmailShare.body(link: link, note: note, includeNote: includeNote), forType: .string)
                        dismiss()
                    }.buttonStyle(QuietButton())
                }
                Spacer()
                Button("Cancel") { dismiss() }.buttonStyle(.plain).keyboardShortcut(.cancelAction)
                Button("Open Mail ↗") { openMail() }.buttonStyle(SageButton()).keyboardShortcut(.return, modifiers: .command)
            }
        }.padding(28).frame(width: 460).background(Color.paper).foregroundStyle(Color.ink)
    }

    private func openMail() {
        let body = EmailShare.body(link: link, note: note, includeNote: includeNote)
        guard let email = NSSharingService(named: .composeEmail), email.canPerform(withItems: [body]) else {
            error = "Mail isn’t available. Set up an email app, or copy this draft."; return
        }
        email.subject = EmailShare.subject(subject)
        service = email
        email.perform(withItems: [body])
        dismiss()
    }
}
