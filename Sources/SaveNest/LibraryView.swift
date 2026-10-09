import SwiftUI
import SaveNestCore

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool
    @State private var now = Date()
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private var groups: [LinkDay] { LinkDay.group(model.visibleLinks, now: now) }
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            AccountBanner(account: model.account, openAccount: { model.showAccount?() })
            ScrollView {
                VStack(alignment: .leading, spacing: 30) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(model.filter == "Archive" ? "Archived" : "Saved for later").font(.system(size: 28, weight: .regular, design: .serif)).tracking(-0.6)
                        Spacer()
                        Text("\(model.visibleLinks.count) \(model.visibleLinks.count == 1 ? "link" : "links")").font(.system(size: 11)).foregroundStyle(Color.muted)
                    }.padding(.top, 7)
                    if model.visibleLinks.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            ForEach(groups) { day in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(day.label).font(.system(size: 11, weight: .medium)).foregroundStyle(Color.muted).padding(.leading, 2)
                                    VStack(spacing: 0) {
                                        ForEach(Array(day.links.enumerated()), id: \.element.id) { index, link in
                                            LinkRow(link: link, model: model)
                                            if index < day.links.count - 1 { Rectangle().fill(Color.line.opacity(0.65)).frame(height: 1).padding(.leading, 65) }
                                        }
                                    }.background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color.line.opacity(0.8), lineWidth: 1))
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 34).padding(.top, 24).padding(.bottom, 34)
            }
            footer
        }
        .background(Color.paper).foregroundStyle(Color.ink).preferredColorScheme(.light)
        .frame(minWidth: 590, minHeight: 440)
        .sheet(isPresented: $model.showingAdd) { AddLinkView(model: model) }
        .sheet(item: Binding(get: { model.selected }, set: { model.selectedID = $0?.id })) { link in LinkDetailView(model: model, link: link) }
        .alert("Couldn’t finish that", isPresented: Binding(get: { model.error != nil && !model.showingAdd && model.selectedID == nil }, set: { if !$0 { model.error = nil } })) {
            Button("OK", role: .cancel) { model.error = nil }
            if model.error?.contains("Automation") == true {
                Button("Automation Settings") { NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!) }
            }
        } message: { Text(model.error ?? "") }
        .onReceive(clock) { now = $0 }
        .onReceive(NotificationCenter.default.publisher(for: .focusSearch)) { _ in searchFocused = true }
    }
    private var toolbar: some View {
        HStack(spacing: 16) {
            HStack(spacing: 6) { NestMark().frame(width: 27, height: 27); Text("savenest").font(.system(size: 21, weight: .semibold)).tracking(-0.8) }
            Spacer(minLength: 20)
            HStack(spacing: 7) {
                Image(systemName: "magnifyingglass").font(.system(size: 12)).foregroundStyle(Color.muted)
                TextField("Search links", text: $model.query).textFieldStyle(.plain).font(.system(size: 12)).focused($searchFocused)
                if !model.query.isEmpty { Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill").foregroundStyle(Color.muted) }.buttonStyle(.plain).help("Clear search") }
            }.padding(.horizontal, 10).padding(.vertical, 8).background(Color.sage.opacity(0.045), in: RoundedRectangle(cornerRadius: 7)).frame(width: 180)
            Button { model.presentAdd() } label: { Image(systemName: "plus").font(.system(size: 15)) }.buttonStyle(.plain).help("Add a link (⌘N)").accessibilityLabel("Add link")
            Menu {
                Button("All saved links") { model.filter = "All links" }
                Button("Archived links") { model.filter = "Archive" }
                Divider()
                Button("Account…") { model.showAccount?() }
                Button("Settings…") { model.showSettings?() }
            } label: { Image(systemName: "ellipsis").font(.system(size: 15)) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Library options")
        }.padding(.horizontal, 34).padding(.top, 26).padding(.bottom, 20)
            .overlay(alignment: .bottom) { Rectangle().fill(Color.line).frame(height: 1) }
    }
    private var emptyState: some View {
        VStack(spacing: 0) {
            NestMark().frame(width: 52, height: 52).padding(22).background(Color.sage.opacity(0.055), in: RoundedRectangle(cornerRadius: 25)).padding(.bottom, 24)
            Text(model.query.isEmpty ? (model.filter == "Archive" ? "Nothing archived." : "A little room for good things.") : "No matching links.")
                .font(.system(size: 23, weight: .regular, design: .serif)).padding(.bottom, 12)
            Text(model.query.isEmpty ? "Open a browser tab and press" : "Try a title, website, or a word from your notes.")
                .font(.system(size: 12)).foregroundStyle(Color.muted)
            if model.query.isEmpty {
                Text(model.shortcut.label).font(.system(size: 17, weight: .medium, design: .monospaced))
                    .padding(.horizontal, 17).padding(.vertical, 10).background(Color.white, in: RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.line)).padding(.top, 15)
                Text("Saved instantly. Right here when you need it.").font(.system(size: 11)).foregroundStyle(Color.muted).padding(.top, 18)
            }
        }.frame(maxWidth: .infinity).padding(.vertical, 44)
    }
    private var footer: some View {
        HStack(spacing: 7) {
            if let notice = model.toast {
                Image(systemName: notice.isError ? "exclamationmark.circle" : "checkmark.circle.fill").foregroundStyle(notice.isError ? Color.orange : Color.sage)
                Text(notice.title)
            } else if model.isCapturing {
                ProgressView().controlSize(.mini)
                Text("Saving…")
            } else {
                Button { model.showSettings?() } label: {
                    HStack(spacing: 8) {
                        Text(model.shortcut.label).font(.system(size: 11, weight: .medium, design: .monospaced)).foregroundStyle(Color.sage)
                        Text("to save a tab")
                    }
                }.buttonStyle(.plain).help("Change capture shortcut")
            }
            Spacer()
            Image(systemName: "lock").font(.system(size: 9))
            Text("Only on your Mac")
        }.font(.system(size: 10)).foregroundStyle(Color.muted).padding(.horizontal, 34).padding(.vertical, 16)
            .overlay(alignment: .top) { Rectangle().fill(Color.line).frame(height: 1) }
    }
}

struct LinkRow: View {
    let link: SavedLink
    @ObservedObject var model: AppModel
    @State private var hovered = false
    private var notePreview: String { link.note.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ") }
    private var hasNote: Bool { !notePreview.isEmpty }
    var body: some View {
        HStack(spacing: 13) {
            Button { model.open(link) } label: {
                HStack(spacing: 13) {
                    DomainIcon(domain: link.domain).scaleEffect(0.8).frame(width: 34, height: 34)
                    VStack(alignment: .leading, spacing: 4) {
                        Text(link.title).font(.system(size: 13, weight: .medium)).foregroundStyle(Color.ink).lineLimit(1)
                        Text(([link.domain] + link.tags.map { "#" + $0 }).joined(separator: "  ·  ")).font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(1)
                        if hasNote {
                            HStack(spacing: 5) {
                                Image(systemName: "text.quote").font(.system(size: 9, weight: .medium))
                                Text(notePreview).font(.system(size: 10.5)).lineLimit(1)
                            }.foregroundStyle(Color.sage)
                        }
                    }
                    Spacer(minLength: 8)
                    Text(link.createdAt.formatted(date: .omitted, time: .shortened)).font(.system(size: 10)).monospacedDigit().foregroundStyle(Color.muted.opacity(0.8))
                    Image(systemName: "arrow.up.right").font(.system(size: 11)).foregroundStyle(Color.sage.opacity(hovered ? 1 : 0.35))
                }.contentShape(Rectangle())
            }.buttonStyle(.plain).help("Open \(link.domain)")
            Menu {
                Button("Open in browser") { model.open(link) }
                Button("Copy link") { model.copy(link) }
                Button(hasNote ? "Edit note…" : "Add a note…") { model.beginDraft(link, action: .note) }
                Button("Add tags…") { model.beginDraft(link, action: .tags) }
                Button("Edit title, note & tags…") { model.selectedID = link.id }
                Divider()
                Button(link.isArchived ? "Restore to library" : "Archive") { model.archive(link) }
            } label: { Image(systemName: "ellipsis").font(.system(size: 12)).foregroundStyle(Color.muted) }.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 19).help("Link options")
        }.padding(.horizontal, 16).padding(.vertical, hasNote ? 11 : 14)
            .background(hovered ? Color.sage.opacity(0.035) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .onHover { hovered = $0 }
            .contextMenu {
                Button("Copy link") { model.copy(link) }
                Button(hasNote ? "Edit note…" : "Add a note…") { model.beginDraft(link, action: .note) }
                Button("Add tags…") { model.beginDraft(link, action: .tags) }
                Button("Edit title, note & tags…") { model.selectedID = link.id }
                Button(link.isArchived ? "Restore to library" : "Archive") { model.archive(link) }
            }
    }
}

extension Notification.Name { static let focusSearch = Notification.Name("SaveNest.focusSearch") }
