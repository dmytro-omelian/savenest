import SwiftUI
import SaveNestCore

struct LibraryView: View {
    @ObservedObject var model: AppModel
    @FocusState private var searchFocused: Bool
    @State private var now = Date()
    private let clock = Timer.publish(every: 60, on: .main, in: .common).autoconnect()
    private var groups: [LinkDay] {
        guard !model.query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return LinkDay.group(model.visibleLinks, now: now) }
        let ranked = model.visibleLinks.sorted { a, b in
            let aScore = LinkSearch.score(query: model.query, title: a.title, url: a.url, note: a.note, tags: a.tags) ?? 0
            let bScore = LinkSearch.score(query: model.query, title: b.title, url: b.url, note: b.note, tags: b.tags) ?? 0
            return aScore == bScore ? a.createdAt > b.createdAt : aScore > bScore
        }
        return [LinkDay(id: .distantPast, label: "Best matches", links: ranked)]
    }
    var body: some View {
        VStack(spacing: 0) {
            toolbar
            if !model.isPreview { AccountBanner(account: model.account, openAccount: { model.showAccount?() }) }
            filters
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    if !model.query.isEmpty || model.selectedTag != nil || model.notesOnly {
                        HStack {
                            Text(model.query.isEmpty ? "Filtered library" : "Results for “\(model.query)”").font(.system(size: 12)).foregroundStyle(Color.muted).lineLimit(1)
                            Spacer()
                            Button("Clear filters") { model.clearFilters() }.buttonStyle(.link).font(.system(size: 11))
                        }
                    }
                    if model.visibleLinks.isEmpty {
                        emptyState
                    } else {
                        LazyVStack(alignment: .leading, spacing: 28) {
                            ForEach(groups) { day in
                                VStack(alignment: .leading, spacing: 10) {
                                    Text(day.label.uppercased()).font(.system(size: 9, weight: .medium)).tracking(1).foregroundStyle(Color.muted.opacity(0.7)).padding(.leading, 4)
                                    VStack(spacing: 0) {
                                        ForEach(Array(day.links.enumerated()), id: \.element.id) { index, link in
                                            LinkRow(link: link, model: model)
                                            if index < day.links.count - 1 { Rectangle().fill(Color.line.opacity(0.65)).frame(height: 1).padding(.leading, 65) }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }.padding(.horizontal, 34).padding(.top, 24).padding(.bottom, 34)
            }
            footer
        }
        .background(Color.paper).foregroundStyle(Color.ink).preferredColorScheme(.light)
        .frame(minWidth: 640, minHeight: 480)
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
    private var filters: some View {
        HStack(spacing: 20) {
            scope("All", filter: "All links")
            scope("Favorites", filter: "Favorites")
            Button { model.notesOnly.toggle() } label: {
                Text("Notes").font(.system(size: 12, weight: model.notesOnly ? .semibold : .regular)).foregroundStyle(model.notesOnly ? Color.ink : Color.muted)
            }.buttonStyle(.plain).help("Show links with notes")
            scope("Archive", filter: "Archive")
            Spacer()
            Menu {
                Button("All tags") { model.selectedTag = nil }
                Divider()
                ForEach(model.tagSummaries) { tag in
                    Button("\(tag.name)  ·  \(tag.count)") { model.selectedTag = tag.name }
                }
            } label: { Label(model.selectedTag.map { "#" + $0 } ?? "Tags", systemImage: "line.3.horizontal.decrease") }
                .menuStyle(.borderlessButton).fixedSize().font(.system(size: 11)).foregroundStyle(Color.muted)
            Text("\(model.visibleLinks.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted.opacity(0.7))
        }.padding(.horizontal, 38).padding(.top, 19).padding(.bottom, 7)
    }
    private func scope(_ title: String, filter: String) -> some View {
        Button { model.filter = filter; model.notesOnly = false; model.selectedTag = nil } label: {
            Text(title).font(.system(size: 12, weight: model.filter == filter && !model.notesOnly ? .semibold : .regular))
                .foregroundStyle(model.filter == filter && !model.notesOnly ? Color.ink : Color.muted)
        }.buttonStyle(.plain)
    }
    private var toolbar: some View {
        VStack(spacing: 23) {
            HStack(spacing: 16) {
                HStack(spacing: 7) { NestMark().frame(width: 22, height: 22); Text("savenest").font(.system(size: 18, weight: .semibold)).tracking(-0.6) }
                Spacer()
                Button { model.showTabSearch?() } label: {
                    HStack(spacing: 6) { Image(systemName: "rectangle.on.rectangle"); Text(model.shortcuts[.search]?.label ?? "⇧⌘O").font(.system(size: 10, design: .monospaced)) }
                }.buttonStyle(.plain).foregroundStyle(Color.muted).help("Search open tabs").accessibilityLabel("Search open tabs")
                Button { model.presentAdd() } label: { Image(systemName: "plus").font(.system(size: 15)) }.buttonStyle(.plain).help("Add a link (⌘N)").accessibilityLabel("Add link")
                Menu {
                    Button("Account…") { model.showAccount?() }
                    Button("Settings…") { model.showSettings?() }
                } label: { Image(systemName: "ellipsis").font(.system(size: 14)) }.menuStyle(.borderlessButton).menuIndicator(.hidden).fixedSize().help("Library options")
            }
            HStack(spacing: 9) {
                Image(systemName: "magnifyingglass").font(.system(size: 14)).foregroundStyle(Color.muted)
                TextField("Search your library", text: $model.query).textFieldStyle(.plain).font(.system(size: 14)).focused($searchFocused)
                    .help("Search titles, websites, notes, and tags. Use #tag for an exact tag.")
                if !model.query.isEmpty {
                    Button { model.query = "" } label: { Image(systemName: "xmark.circle.fill") }.buttonStyle(.plain).foregroundStyle(Color.muted).help("Clear search")
                } else { Text("⌘F").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted.opacity(0.55)) }
            }.padding(12).background(Color.white.opacity(0.65), in: RoundedRectangle(cornerRadius: 9)).overlay(RoundedRectangle(cornerRadius: 9).stroke(Color.line.opacity(searchFocused ? 1 : 0.55)))
        }.padding(.horizontal, 34).padding(.top, 22).padding(.bottom, 0)
    }
    private var emptyState: some View {
        VStack(spacing: 0) {
            NestMark().frame(width: 52, height: 52).padding(22).background(Color.sage.opacity(0.055), in: RoundedRectangle(cornerRadius: 25)).padding(.bottom, 24)
            Text(model.query.isEmpty && model.selectedTag == nil && !model.notesOnly ? (model.filter == "Archive" ? "Nothing archived." : "A little room for good things.") : "No matching links.")
                .font(.system(size: 23, weight: .regular, design: .serif)).padding(.bottom, 12)
            Text(model.query.isEmpty && model.selectedTag == nil && !model.notesOnly ? "Open a browser tab and press" : "Try fewer words, another tag, or clear your filters.")
                .font(.system(size: 12)).foregroundStyle(Color.muted)
            if model.query.isEmpty && model.selectedTag == nil && !model.notesOnly {
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
                        Text(model.closeAfterQuickSave ? "to save & close a tab" : "to save a tab")
                    }
                }.buttonStyle(.plain).help("Change capture shortcut")
            }
            Spacer()
            Image(systemName: "lock").font(.system(size: 9))
            Text("Only on your Mac")
        }.font(.system(size: 10)).foregroundStyle(Color.muted).padding(.horizontal, 34).padding(.vertical, 16)

    }
}

struct LinkRow: View {
    let link: SavedLink
    @ObservedObject var model: AppModel
    @State private var hovered = false
    private var hasNote: Bool { !link.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            DomainIcon(domain: link.domain).scaleEffect(0.62).frame(width: 26, height: 26)
            VStack(alignment: .leading, spacing: 8) {
                Button { model.open(link) } label: {
                    VStack(alignment: .leading, spacing: 5) {
                        Text(link.title).font(.system(size: 14, weight: .medium)).foregroundStyle(Color.ink).lineLimit(2).multilineTextAlignment(.leading)
                        Text(link.domain).font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(1)
                    }.frame(maxWidth: .infinity, alignment: .leading).contentShape(Rectangle())
                }.buttonStyle(.plain).help("Open in browser")
                if hasNote {
                    Button { model.selectedID = link.id } label: {
                        HStack(alignment: .top, spacing: 7) {
                            Image(systemName: "text.quote").font(.system(size: 10)).padding(.top, 2)
                            Text(link.note).font(.system(size: 12)).lineSpacing(3).lineLimit(2).multilineTextAlignment(.leading).frame(maxWidth: .infinity, alignment: .leading)
                        }.foregroundStyle(Color.muted)
                    }.buttonStyle(.plain).help("Edit note")
                }
                if !link.tags.isEmpty {
                    TagFlowLayout(spacing: 5) {
                        ForEach(link.tags, id: \.self) { tag in
                            Button { model.selectedTag = tag } label: { Text("#" + tag).font(.system(size: 10, weight: .medium)).padding(.horizontal, 8).padding(.vertical, 4).background(Color.sage.opacity(0.07), in: Capsule()) }.buttonStyle(.plain).foregroundStyle(Color.sage).help("Find links tagged \(tag)")
                        }
                    }
                }

            }
            HStack(spacing: 13) {
                Button { model.selectedID = link.id } label: { Image(systemName: "square.and.pencil") }.buttonStyle(.plain).help("Edit note and tags").accessibilityLabel("Edit note and tags")
                Button { model.favorite(link) } label: { Image(systemName: link.isFavorite ? "star.fill" : "star").foregroundStyle(link.isFavorite ? Color.sage : Color.muted.opacity(0.5)) }.buttonStyle(.plain).help(link.isFavorite ? "Remove favorite" : "Favorite link").accessibilityLabel(link.isFavorite ? "Remove favorite" : "Favorite link")
                Menu {
                    Button("Open in browser") { model.open(link) }
                    Button("Copy link") { model.copy(link) }
                    Button("Edit title, note & tags…") { model.selectedID = link.id }
                    Divider()
                    Button(link.isArchived ? "Restore to library" : "Archive") { model.archive(link) }
                } label: { Image(systemName: "ellipsis") }.menuStyle(.borderlessButton).menuIndicator(.hidden).frame(width: 18).help("Link options")
            }.font(.system(size: 12)).foregroundStyle(Color.muted).opacity(hovered ? 1 : link.isFavorite ? 0.55 : 0.18)
        }.padding(.horizontal, 4).padding(.vertical, 16).background(hovered ? Color.sage.opacity(0.025) : .clear, in: RoundedRectangle(cornerRadius: 12))
            .onHover { hovered = $0 }
            .contextMenu {
                Button("Open in browser") { model.open(link) }
                Button("Copy link") { model.copy(link) }
                Button("Edit note & tags…") { model.selectedID = link.id }
                Button(link.isArchived ? "Restore to library" : "Archive") { model.archive(link) }
            }
    }
}

extension Notification.Name { static let focusSearch = Notification.Name("SaveNest.focusSearch") }
