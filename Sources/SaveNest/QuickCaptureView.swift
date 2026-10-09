import SwiftUI
import SaveNestCore

struct QuickCaptureView: View {
    @ObservedObject var model: AppModel
    let draft: CaptureDraft
    @State private var link: SavedLink
    @State private var tags = ""
    @State private var saving = false
    @FocusState private var focus: Field?
    private enum Field: Hashable { case note }
    init(model: AppModel, draft: CaptureDraft) {
        self.model = model; self.draft = draft
        _link = State(initialValue: draft.link)
    }
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 8) {
                NestMark().frame(width: 24, height: 24)
                Text(draft.action == .note ? "Save with a note" : "Save with tags").font(.system(size: 17, weight: .medium))
                Spacer()
            }
            VStack(alignment: .leading, spacing: 6) {
                TextField("Link title", text: $link.title).textFieldStyle(.plain).font(.system(size: 14, weight: .medium))
                Text(link.domain).font(.system(size: 11)).foregroundStyle(Color.muted)
            }.padding(13).frame(maxWidth: .infinity, alignment: .leading).background(Color.white, in: RoundedRectangle(cornerRadius: 9))
            if draft.action == .tags { tagsField; noteField } else { noteField; tagsField }
            HStack {
                Text("⌘↵ to save · Esc to cancel").font(.system(size: 10)).foregroundStyle(Color.muted)
                Spacer()
                Button("Cancel") { model.cancelDraft() }.keyboardShortcut(.cancelAction).buttonStyle(.plain)
                Button(saving ? "Saving…" : "Save") {
                    link.tags = SavedLink.normalizedTags(link.tags + SavedLink.parseTags(tags))
                    saving = true
                    Task { _ = await model.saveDraft(link); saving = false }
                }.buttonStyle(SageButton()).keyboardShortcut(.return, modifiers: .command).disabled(saving)
            }
        }.padding(24).frame(width: 460).background(Color.paper).foregroundStyle(Color.ink).preferredColorScheme(.light)
            .onAppear { if draft.action == .note { focus = .note } }
    }
    private var noteField: some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLabel("NOTE")
            TextEditor(text: $link.note).focused($focus, equals: .note).font(.system(size: 13))
                .scrollContentBackground(.hidden).padding(8).frame(height: draft.action == .note ? 100 : 65)
                .background(Color.white, in: RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.line))
        }
    }
    private var tagsField: some View {
        VStack(alignment: .leading, spacing: 7) {
            fieldLabel("TAGS")
            TagEditor(tags: $link.tags, input: $tags, suggestions: model.allTags, initiallyFocused: draft.action == .tags)
        }
    }
}
