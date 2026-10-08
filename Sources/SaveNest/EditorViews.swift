import SwiftUI
import SaveNestCore

struct AddLinkView: View {
    @ObservedObject var model: AppModel
    @Environment(\.dismiss) private var dismiss
    @State private var url = ""
    @State private var title = ""
    @State private var collection = "Inbox"
    @FocusState private var focused: Bool
    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            sheetHeading("A good find.", subtitle: "Give that link a little home.")
            VStack(alignment: .leading, spacing: 8) { fieldLabel("WEB ADDRESS"); TextField("https://…", text: $url).focused($focused) }
            VStack(alignment: .leading, spacing: 8) { fieldLabel("TITLE (OPTIONAL)"); TextField("Something worth keeping", text: $title) }
            if let error = model.error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
            HStack {
                Button("Paste URL") { if let value = NSPasteboard.general.string(forType: .string) { url = value.trimmingCharacters(in: .whitespacesAndNewlines) } }.buttonStyle(QuietButton())
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(.plain)
                Button("Save link") { Task { if await model.add(url: url, title: title, collection: collection) { dismiss() } } }.buttonStyle(SageButton()).keyboardShortcut(.defaultAction).disabled(Library.validatedURL(url) == nil)
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
                TextEditor(text: $link.note).font(.system(size: 12)).scrollContentBackground(.hidden).padding(8).frame(height: 105).background(Color.white, in: RoundedRectangle(cornerRadius: 7)).overlay(RoundedRectangle(cornerRadius: 7).stroke(Color.line))
            }
            VStack(alignment: .leading, spacing: 8) {
                fieldLabel("TAGS")
                TextField("Tags, separated by commas", text: $tagsText).textFieldStyle(.roundedBorder)
            }
            if let error = model.error { Text(error).font(.system(size: 11)).foregroundStyle(.red) }
            HStack {
                Menu {
                    Button("Copy link") { model.copy(link) }
                    Button(link.isArchived ? "Restore to library" : "Archive link") { if model.archive(link) { dismiss() } }
                    Divider()
                    Button("Delete permanently…", role: .destructive) { confirmingDelete = true }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).frame(width: 30)
                Spacer()
                Button("Cancel") { dismiss() }.keyboardShortcut(.cancelAction).buttonStyle(.plain)
                Button("Save changes") { link.tags = SavedLink.parseTags(tagsText); Task { if await model.update(link) { dismiss() } } }.buttonStyle(SageButton()).keyboardShortcut(.defaultAction)
            }
        }.padding(32).frame(width: 510).background(Color.paper).foregroundStyle(Color.ink)
            .onAppear { tagsText = link.tags.joined(separator: ", ") }
            .alert("Delete this link?", isPresented: $confirmingDelete) {
                Button("Cancel", role: .cancel) {}
                Button("Delete", role: .destructive) { model.delete(link); dismiss() }
            } message: { Text("This permanently removes the link and its note from SaveNest.") }
    }
}

struct SettingsView: View {
    @ObservedObject var model: AppModel
    var body: some View {
        ScrollView { VStack(alignment: .leading, spacing: 26) {
            sheetHeading("Make yourself at home.", subtitle: "A few small things, just how you like them.")
            Button("Account & subscription…") { model.showAccount?() }.buttonStyle(QuietButton())
            VStack(alignment: .leading, spacing: 15) {
                fieldLabel("CAPTURE SHORTCUTS")
                ForEach(CaptureAction.allCases) { action in
                    VStack(alignment: .leading, spacing: 5) {
                        HStack {
                            Text(action.title).font(.system(size: 12, weight: .medium))
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
                Text("Click a shortcut and press a new combination with ⌘, ⌥, or ⌃. Escape cancels. Note and tag capture open a small editor; plain capture saves instantly.")
                    .font(.system(size: 11)).foregroundStyle(Color.muted).fixedSize(horizontal: false, vertical: true)
                Button("Preview popup") { model.notify(CaptureError.noTabs.notice) }.buttonStyle(.link).font(.system(size: 11))
            }.padding(20).background(Color.white.opacity(0.75), in: RoundedRectangle(cornerRadius: 12))
            VStack(alignment: .leading, spacing: 10) {
                fieldLabel("BROWSERS & PRIVACY")
                Text("Capture directly from Safari and supported Chromium browsers, including Chrome, Arc, Brave, and Edge. macOS asks for Automation permission the first time you capture from each browser.").font(.system(size: 12)).lineSpacing(4)
                Text("For Firefox or another app, copy its URL and choose Add link → Paste URL. Tabs stay open. SaveNest only reads tabs when you ask and stores links and notes locally.").font(.system(size: 11)).foregroundStyle(Color.muted).lineSpacing(4)
                Text("Richer social titles use page metadata and post text when available. Your browser may require its ‘Allow JavaScript from Apple Events’ setting for this. Capture still works without it, using the tab title or a description based on the URL.").font(.system(size: 11)).foregroundStyle(Color.muted).lineSpacing(4)
                Button("Open Automation Settings ↗") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!) }.buttonStyle(.link).font(.system(size: 11))
            }
            VStack(alignment: .leading, spacing: 13) {
                fieldLabel("YOUR LIBRARY")
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
