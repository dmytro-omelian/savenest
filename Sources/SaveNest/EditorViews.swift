import SwiftUI
import SaveNestCore

struct AddLinkView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var title = ""
    @State private var collection = "Inbox"
    @State private var note = ""
    @State private var tags: [String] = []
    @State private var tagInput = ""
    @State private var saving = false
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sheetHeading("A good find.", subtitle: "Give that link a little home.")
            VStack(alignment: .leading, spacing: 8) { fieldLabel("WEB ADDRESS"); TextField("https://…", text: $url).focused($focused) }
            VStack(alignment: .leading, spacing: 8) { fieldLabel("TITLE (OPTIONAL)"); TextField("Something worth keeping", text: $title) }
            VStack(alignment: .leading, spacing: 8) { fieldLabel("NOTE"); NoteEditor(text: $note, height: 90) }
            VStack(alignment: .leading, spacing: 8) { fieldLabel("TAGS"); TagEditor(tags: $tags, input: $tagInput, suggestions: model.allTags) }
            if let error = model.error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
            HStack {
                Button("Paste URL") { if let value = NSPasteboard.general.string(forType: .string) { url = value.trimmingCharacters(in: .whitespacesAndNewlines) } }.buttonStyle(QuietButton())
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(.plain)
                Button(saving ? "Saving…" : "Save link") { saving = true; Task { if await model.add(url: url, title: title, collection: collection, note: note, tags: tags + SavedLink.parseTags(tagInput)) { dismiss() }; saving = false } }.buttonStyle(SageButton()).keyboardShortcut(.return, modifiers: .command).disabled(saving || Library.validatedURL(url) == nil)
            }.padding(.top, 8)
        }.textFieldStyle(.roundedBorder).padding(32).frame(width: 470).background(Color.paper).foregroundStyle(Color.ink)
            .onAppear { focused = true; if model.library.collections.contains(model.filter) { collection = model.filter } }
    }
}
struct LinkDetailView: View {
    @ObservedObject var model: AppModel
    @State var link: SavedLink
    @Environment(\.dismiss) private var dismiss
    @State private var confirmingDelete = false
    @State private var tagsText = ""
    @State private var saving = false
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack(spacing: 12) {
                DomainIcon(domain: link.domain)
                VStack(alignment: .leading, spacing: 5) {
                    Text(link.domain).font(.system(size: 18, weight: .medium))
                    Text("Saved from \(link.browser) · \(link.createdAt.formatted(date: .abbreviated, time: .omitted))").font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                Spacer()
                Button { model.open(link) } label: { Image(systemName: "arrow.up.right") }.buttonStyle(QuietButton()).help("Open link")
            }
            VStack(alignment: .leading, spacing: 8) { fieldLabel("TITLE"); TextField("Title", text: $link.title).textFieldStyle(.roundedBorder) }
            Text(link.url).font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(3).textSelection(.enabled)
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("A NOTE TO YOUR FUTURE SELF")
                NoteEditor(text: $link.note)
            }
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("TAGS")
                TagEditor(tags: $link.tags, input: $tagsText, suggestions: model.allTags)
            }
            if let error = model.error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
            HStack {
                Menu {
                    Button("Copy link") { model.copy(link) }
                    Button(link.isArchived ? "Restore to library" : "Archive link") { if model.archive(link) { dismiss() } }
                    if link.isArchived {
                        Divider()
                        Button("Delete permanently…", role: .destructive) { confirmingDelete = true }
                    }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 30)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(.plain)
                Button(saving ? "Saving…" : "Save changes") { link.tags = SavedLink.normalizedTags(link.tags + SavedLink.parseTags(tagsText)); saving = true; Task { if await model.update(link) { dismiss() }; saving = false } }.buttonStyle(SageButton()).keyboardShortcut(.return, modifiers: .command).disabled(saving)
            }
        }.padding(32).frame(width: 510).background(Color.paper).foregroundStyle(Color.ink)
            .interactiveDismissDisabled()
            .alert("Delete this link?", isPresented: $confirmingDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { model.delete(link); dismiss() }
            } message: { Text("This permanently removes the link and its note from SaveNest.") }
    }
}

struct TabSelectionView: View {
    @ObservedObject var model: AppModel
    let draftID: UUID
    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sheetHeading("Choose what stays.", subtitle: "Select the tabs you want to save. Nothing closes in your browser.")
            if let draft = model.tabSelection, draft.id == draftID {
                HStack {
                    Button("Select all") { model.updateTabSelection(Set(draft.links.map(\.id))) }.buttonStyle(.link)
                    Button("Select none") { model.updateTabSelection([]) }.buttonStyle(.link)
                    Spacer()
                    Text("\(draft.selected.count) selected").font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                ScrollView {
                    LazyVStack(spacing: 7) {
                        ForEach(draft.links) { link in
                            Button {
                                var selected = draft.selected
                                if selected.contains(link.id) { selected.remove(link.id) } else { selected.insert(link.id) }
                                model.updateTabSelection(selected)
                            } label: {
                                HStack(spacing: 11) {
                                    Image(systemName: draft.selected.contains(link.id) ? "checkmark.square.fill" : "square")
                                        .foregroundStyle(draft.selected.contains(link.id) ? Color.sage : Color.muted)
                                    DomainIcon(domain: link.domain)
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(link.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                        Text(link.domain).font(.system(size: 10)).foregroundStyle(Color.muted).lineLimit(1)
                                    }
                                    Spacer()
                                }.padding(10).contentShape(Rectangle())
                            }.buttonStyle(.plain)
                        }
                    }
                }.frame(height: min(CGFloat(draft.links.count) * 58, 360))
                    .background(Color.white.opacity(0.72), in: RoundedRectangle(cornerRadius: 10))
                HStack {
                    Spacer()
                    Button("Cancel") { model.cancelTabSelection() }.keyboardShortcut(.cancelAction).buttonStyle(.plain)
                    Button(draft.selected.count == 1 ? "Save tab" : "Save \(draft.selected.count) tabs") { model.saveTabSelection() }
                        .buttonStyle(SageButton()).keyboardShortcut(.defaultAction).disabled(draft.selected.isEmpty)
                }
            }
        }.padding(28).frame(width: 520).background(Color.paper).foregroundStyle(Color.ink)
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 26) {
            sheetHeading("Make yourself at home.", subtitle: "A few small things, just how you like them.")
            Button("Account & subscription…") { model.showAccount?() }.buttonStyle(QuietButton())
            VStack(alignment: .leading, spacing: 15) {
                fieldLabel("KEYBOARD SHORTCUTS")
                ForEach(CaptureAction.allCases) { action in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            if action == .quick {
                                Picker("Save link behavior", selection: $model.closeAfterQuickSave) {
                                    Text("Save link").tag(false)
                                    Text("Save & close tab").tag(true)
                                }.labelsHidden().fixedSize().help("Choose what the Save link shortcut does")
                            } else { Text(action.title).font(.system(size: 12, weight: .medium)) }
                            Spacer()
                            ShortcutRecorder(label: (model.shortcuts[action] ?? action.defaultShortcut).label,
                                onStart: { model.hotkey.unregister() },
                                onRecord: { model.configureShortcut($0, for: action) }).frame(width: 145, height: 30)
                            Button { model.configureShortcut(action.defaultShortcut, for: action) } label: { Image(systemName: "arrow.counterclockwise") }
                                .buttonStyle(.plain).foregroundStyle(Color.muted).help("Reset \(action.title) shortcut")
                        }
                        if let error = model.shortcutErrors[action] { Text(error).font(.system(size: 10)).foregroundStyle(.red) }
                    }
                }
                Text("Save & close tab closes only after saving successfully. Other capture shortcuts leave tabs open.\n\nClick a shortcut and press a new combination with ⌘, ⌥, or ⌃. Escape cancels. Selected tabs open a quick checklist; note and tag capture open a small editor.")
                    .font(.system(size: 11)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                Button("Preview popup") { model.notify(CaptureError.noTabs.notice) }.buttonStyle(.link).font(.system(size: 11))
            }.padding(20).background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("BROWSERS & PRIVACY")
                Text("Capture directly from Safari and supported Chromium browsers, including Chrome, Arc, Brave, and Edge. macOS asks for Automation permission the first time you capture from each browser.").font(.system(size: 12)).lineSpacing(4)
                Text("For Firefox or another app, copy its URL and choose Add link → Paste URL. Tabs stay open unless you choose Save & close tab for quick capture. SaveNest only reads tabs when you ask and stores links and notes locally.").font(.system(size: 11)).foregroundStyle(Color.muted).lineSpacing(4)
                Text("Richer social titles use page metadata and post text when available. Your browser may require its ‘Allow JavaScript from Apple Events’ setting for this. Capture still works without it, using the tab title or a description based on the URL.").font(.system(size: 11)).foregroundStyle(Color.muted).lineSpacing(4)
                Button("Open Automation Settings ↗") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!) }.buttonStyle(.link).font(.system(size: 11))
            }
            VStack(alignment: .leading, spacing: 13) {
                fieldLabel("YOUR LIBRARY")
                Text("Swipe left to archive a link, or right for Email and Copy. A long left swipe archives immediately; Undo appears at the bottom. In Archive, swipe left to restore.").font(.system(size: 11)).foregroundStyle(Color.muted).lineSpacing(4)
                Text("Archive all links is in the library menu. Empty archive is inside Archive and asks before deleting permanently.").font(.system(size: 11)).foregroundStyle(Color.muted).lineSpacing(4)
                HStack {
                    Button("Export backup…") { model.exportLibrary() }.buttonStyle(QuietButton())
                    Button("Import backup…") { model.importLibrary() }.buttonStyle(QuietButton())
                    Spacer()
                    Button("Show in Finder") { model.revealLibrary() }.buttonStyle(.link).font(.system(size: 11))
                }
            }
            HStack { NestMark().frame(width: 20, height: 20); Text("SaveNest " + (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development")); Spacer(); Text("A small app for a clearer mind.") }.font(.system(size: 10)).foregroundStyle(Color.muted)
        }.padding(32) }.frame(width: 610, height: 680).background(Color.paper).foregroundStyle(Color.ink).preferredColorScheme(.light)
    }
}
func fieldLabel(_ text: String) -> some View { Text(text).font(.system(size: 9, weight: .semibold)).tracking(1.3).foregroundStyle(Color.muted) }
func sheetHeading(_ title: String, subtitle: String) -> some View {
    VStack(alignment: .leading, spacing: 9) {
        Text(title).font(.system(size: 27, weight: .regular, design: .serif)).tracking(-0.6)
        Text(subtitle).font(.system(size: 12)).foregroundStyle(Color.muted)
    }
}
