import AppKit
import SwiftUI
import SaveNestCore
import UniformTypeIdentifiers

struct CaptureDraft: Identifiable {
    var id: UUID { link.id }
    var link: SavedLink
    let action: CaptureAction
}

struct TabSelectionDraft: Identifiable {
    let id = UUID()
    let links: [SavedLink]
    var selected: Set<UUID>
    init(links: [SavedLink]) { self.links = links; selected = Set(links.map(\.id)) }
}

@MainActor
final class AppModel: ObservableObject {
    let account = AccountController()
    @Published private(set) var library = Library()
    @Published var closeAfterQuickSave = UserDefaults.standard.bool(forKey: "closeAfterQuickSave") {
        didSet { UserDefaults.standard.set(closeAfterQuickSave, forKey: "closeAfterQuickSave") }
    }
    @Published var filter = "All links"
    @Published var query = ""
    @Published var selectedTag: String?
    @Published var notesOnly = false
    let tabSearch = TabSearchModel()
    var showTabSearch: (() -> Void)?
    @Published var selectedID: UUID?
    @Published var sharingLink: SavedLink?
    @Published var swipedLinkID: UUID?
    @Published private(set) var archiveUndo: ArchiveUndo?
    struct ArchiveUndo {
        let ids: Set<UUID>
        let archived: Bool
        var message: String { "\(ids.count) " + (ids.count == 1 ? "link " : "links ") + (archived ? "archived" : "restored") }
    }
    var activeIDs: Set<UUID> { Set(library.links.filter { !$0.isArchived }.map(\.id)) }
    var archivedIDs: Set<UUID> { Set(library.links.filter(\.isArchived).map(\.id)) }
    @Published var error: String?
    @Published var isCapturing = false
    @Published var showingAdd = false
    @Published var shortcuts: [CaptureAction: CaptureShortcut]
    @Published var shortcutErrors: [CaptureAction: String] = [:]
    @Published var draft: CaptureDraft?
    @Published var tabSelection: TabSelectionDraft?
    var shortcut: CaptureShortcut { shortcuts[.quick] ?? .standard }
    var shortcutError: String? { shortcutErrors.values.first }
    @Published var toast: CaptureNotice?
    private let file: LibraryFile
    private var loadFailed = false
    let captureService = BrowserCapture()
    let hotkey = GlobalShortcut()
    var showLibrary: (() -> Void)?
    var showSettings: (() -> Void)?
    var showAccount: (() -> Void)?
    var showToast: ((CaptureNotice) -> Void)?
    var showCaptureEditor: ((CaptureDraft) -> Void)?
    var closeCaptureEditor: (() -> Void)?
    var showTabSelection: ((TabSelectionDraft) -> Void)?
    var closeTabSelection: (() -> Void)?

    #if DEBUG
    var isPreview: Bool { ProcessInfo.processInfo.arguments.contains("--ui-preview") }
    #else
    let isPreview = false
    #endif
    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = LibraryFile(url: support.appendingPathComponent("SaveNest/library.json"))
        let stored = UserDefaults.standard.data(forKey: "captureShortcuts").flatMap { try? JSONDecoder().decode([String: CaptureShortcut].self, from: $0) } ?? [:]
        let legacy = UserDefaults.standard.data(forKey: "captureShortcut").flatMap { try? JSONDecoder().decode(CaptureShortcut.self, from: $0) }
        shortcuts = Dictionary(uniqueKeysWithValues: CaptureAction.allCases.map { action in
            (action, stored[action.rawValue] ?? (action == .quick ? legacy : nil) ?? action.defaultShortcut)
        })
        #if DEBUG
        if isPreview {
            var design = SavedLink(url: "https://example.com/design", title: "The details that make a Mac app feel at home", browser: "Safari")
            design.note = "Bring this into the next design pass. Clear hierarchy, quiet surfaces, and keyboard shortcuts that stay out of the way."
            design.tags = ["Design", "Inspiration"]; design.isFavorite = true
            var reading = SavedLink(url: "https://example.com/reading", title: "A small collection of things worth keeping", browser: "Chrome")
            reading.tags = ["Read later"]; reading.createdAt = Date().addingTimeInterval(-86400)
            library.insert([design, reading])
            return
        }
        #endif
        do { library = try file.load() }
        catch { loadFailed = true; self.error = "Your saved library couldn’t be opened. The original file has been kept untouched at \(file.url.path). Restore a valid backup there, then restart SaveNest. \(error.localizedDescription)" }
        account.onChange = { [weak self] in self?.objectWillChange.send() }
        hotkey.action = { [weak self] action in self?.capture(action: action) }
        for action in hotkey.register(shortcuts) { shortcutErrors[action] = "Already in use. Choose another shortcut." }
    }
    var visibleLinks: [SavedLink] {
        library.links.filter { link in
            let included: Bool
            switch filter {
            case "All links": included = !link.isArchived
            case "Favorites": included = link.isFavorite && !link.isArchived
            case "Archive": included = link.isArchived
            default: included = link.collection == filter && !link.isArchived
            }
            return included && link.matches(query) && (!notesOnly || !link.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && (selectedTag == nil || link.tags.contains { LinkSearch.folded($0) == LinkSearch.folded(selectedTag!) })
        }
    }
    var tagSummaries: [TagSummary] { TagSummary.summarize(library.links.filter { $0.isArchived == (filter == "Archive") }) }
    var allTags: [String] { TagSummary.summarize(library.links).map(\.name) }
    func clearFilters() { query = ""; selectedTag = nil; notesOnly = false }
    var selected: SavedLink? { library.links.first { $0.id == selectedID } }
    var activeCount: Int { library.links.filter { !$0.isArchived }.count }
    @discardableResult private func commit(_ next: Library, captureFeedback: Bool = false) -> Bool {
        func report(_ message: String) {
            if captureFeedback { notify(CaptureNotice(title: "Couldn’t save your tab", message: message, isError: true)) }
            else { error = message }
        }
        // The preview owns an in-memory fixture and never loads or writes the user's library.
        if isPreview { library = next; return true }
        guard !loadFailed else { report("Your library couldn’t be opened. Restore a valid backup and restart SaveNest. Your original file is unchanged."); return false }
        do { try file.save(next); library = next; return true }
        catch { report("Couldn’t write to your library. \(error.localizedDescription)"); return false }
    }
    func capture(action: CaptureAction = .quick) {
        if action == .search { showTabSearch?(); return }
        if let draft { showCaptureEditor?(draft); return }
        guard !isCapturing else { return }
        isCapturing = true
        let shouldClose = action == .quick && closeAfterQuickSave
        Task { @MainActor in
            defer { isCapturing = false }
            guard await authorizeSaving() else { return }
            let result: Result<CapturedTabs, Error> = await withCheckedContinuation { continuation in
                captureService.capture(allTabs: action == .window || action == .selected, prepareClose: shouldClose) { continuation.resume(returning: $0) }
            }
            switch result {
            case .success(let captured):
                let links = captured.links
                // A capture or permission dialog may have outlasted the account lease.
                guard await authorizeSaving() else { return }
                if action == .selected {
                    let selection = TabSelectionDraft(links: links)
                    tabSelection = selection
                    showTabSelection?(selection)
                    return
                }
                if action == .note || action == .tags, var link = links.first {
                    if let existing = library.links.first(where: { Library.identity($0.url) == Library.identity(link.url) }) {
                        let improved = link.title
                        link = existing
                        if LinkTitle.isGeneric(link.title) { link.title = improved }
                    }
                    beginDraft(link, action: action)
                    return
                }
                let saved = saveCaptured(links)
                if saved && shouldClose {
                    let closed: Bool
                    if let target = captured.closeTarget { closed = await captureService.closeSavedTab(target) }
                    else { closed = false }
                    notify(CaptureNotice(title: closed ? "Saved & closed" : "Saved · tab left open", message: closed ? "Ready in your library whenever you need it." : "The tab changed or couldn’t be closed safely. Your link is saved."))
                }
            case .failure(let failure):
                let notice = (failure as? CaptureError)?.notice ?? CaptureNotice(title: "Couldn’t capture this tab", message: "Try again with a web page open in your browser.", isError: true)
                notify(notice)
            }
        }
    }
    @discardableResult private func saveCaptured(_ links: [SavedLink]) -> Bool {
        var next = library
        for link in links {
            if let index = next.links.firstIndex(where: { Library.identity($0.url) == Library.identity(link.url) }),
               LinkTitle.isGeneric(next.links[index].title), !LinkTitle.isGeneric(link.title) { next.links[index].title = link.title }
        }
        let added = next.insert(links)
        guard commit(next, captureFeedback: true) else { return false }
        let title = added == 0 ? "Already saved" : (added == 1 ? "Tab saved" : "\(added) tabs saved")
        let message = added == 0 ? "Already in your library. No duplicate added." : "Ready in your library whenever you need it."
        notify(CaptureNotice(title: title, message: message))
        return true
    }
    func updateTabSelection(_ selection: Set<UUID>) {
        guard var draft = tabSelection else { return }
        draft.selected = selection; tabSelection = draft
    }
    func saveTabSelection() {
        guard let draft = tabSelection else { return }
        let links = draft.links.filter { draft.selected.contains($0.id) }
        guard !links.isEmpty else { return }
        tabSelection = nil; closeTabSelection?(); saveCaptured(links)
    }
    func cancelTabSelection() { tabSelection = nil; closeTabSelection?() }
    private func authorizeSaving() async -> Bool {
        guard await account.authorize() else {
            notify(CaptureNotice(title: account.hasLogin ? "Check your subscription" : "Sign in to save", message: account.message ?? "Open Account to start saving.", isError: true, opensAccount: true))
            return false
        }
        return true
    }
    func presentAdd() {
        Task { @MainActor in
            if await authorizeSaving() { showingAdd = true }
            else { showAccount?() }
        }
    }
    @discardableResult func add(url: String, title: String, collection: String, note: String = "", tags: [String] = []) async -> Bool {
        guard await authorizeSaving() else { return false }
        guard let valid = Library.validatedURL(url) else { error = "Enter a complete web address beginning with https:// or http://."; return false }
        var next = library
        var link = SavedLink(url: valid.absoluteString, title: title, collection: collection)
        link.note = note; link.tags = SavedLink.normalizedTags(tags)
        if next.links.contains(where: { Library.identity($0.url) == Library.identity(link.url) }) {
            error = "This link is already saved. Open its note and tags from your library to edit it."
            return false
        }
        let added = next.insert([link])
        guard commit(next) else { return false }
        notify(added == 0 ? "Already tucked away in your nest" : "Link saved")
        return true
    }
    @discardableResult func update(_ link: SavedLink) async -> Bool {
        guard await authorizeSaving() else { return false }
        var next = library
        guard let index = next.links.firstIndex(where: { $0.id == link.id }) else { return false }
        next.links[index] = link; return commit(next)
    }
    func favorite(_ link: SavedLink) { var next = link; next.isFavorite.toggle(); Task { await update(next) } }
    @discardableResult func archive(_ link: SavedLink) -> Bool {
        setArchived(!link.isArchived, ids: [link.id])
    }
    @discardableResult func setArchived(_ archived: Bool, ids: Set<UUID>) -> Bool {
        var next = library
        let changed = next.setArchived(archived, ids: ids)
        guard !changed.isEmpty, commit(next) else { return false }
        selectedID = nil; swipedLinkID = nil
        archiveUndo = ArchiveUndo(ids: changed, archived: archived)
        return true
    }
    func undoArchive() {
        guard let undo = archiveUndo else { return }
        var next = library
        next.setArchived(!undo.archived, ids: undo.ids)
        if commit(next) { archiveUndo = nil }
    }
    func dismissArchiveUndo() { archiveUndo = nil }
    func emptyArchive(ids: Set<UUID>) {
        var next = library
        let removed = next.deleteArchived(ids: ids)
        guard removed > 0, commit(next) else { return }
        archiveUndo = nil; selectedID = nil; swipedLinkID = nil
        notify(CaptureNotice(title: "Archive emptied", message: "\(removed) " + (removed == 1 ? "link permanently deleted." : "links permanently deleted.")))
    }
    func share(_ link: SavedLink) { swipedLinkID = nil; sharingLink = link }

    func delete(_ link: SavedLink) {
        var next = library; next.links.removeAll { $0.id == link.id }
        if commit(next) { selectedID = nil; notify("Link deleted") }
    }
    func configureShortcut(_ value: CaptureShortcut?, for action: CaptureAction) {
        guard let value else { restoreShortcuts(); return }
        if let duplicate = shortcuts.first(where: { $0.key != action && $0.value.keyCode == value.keyCode && $0.value.modifiers == value.modifiers }) {
            restoreShortcuts(); shortcutErrors[action] = "Already used by ‘\(duplicate.key.title)’."; return
        }
        let previous = shortcuts
        var candidate = shortcuts; candidate[action] = value
        let failed = hotkey.register(candidate)
        if failed.contains(action) {
            _ = hotkey.register(previous)
            shortcutErrors[action] = "Unavailable. Your previous shortcut is unchanged."
        } else {
            shortcuts = candidate; shortcutErrors[action] = nil
            for other in failed { shortcutErrors[other] = "Already in use. Choose another shortcut." }
            let saved = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
            UserDefaults.standard.set(try? JSONEncoder().encode(saved), forKey: "captureShortcuts")
        }
    }
    private func restoreShortcuts() {
        for action in hotkey.register(shortcuts) { shortcutErrors[action] = "Unavailable. Choose another shortcut." }
    }
    func beginDraft(_ link: SavedLink, action: CaptureAction) {
        if let draft { showCaptureEditor?(draft); return }
        let draft = CaptureDraft(link: link, action: action)
        self.draft = draft; showCaptureEditor?(draft)
    }
    @discardableResult func saveDraft(_ link: SavedLink) async -> Bool {
        guard await authorizeSaving() else { return false }
        var next = library
        guard next.saveAnnotated(link) else { notify(CaptureNotice(title: "Couldn’t save this link", message: "The web address is invalid.", isError: true)); return false }
        guard commit(next, captureFeedback: true) else { return false }
        draft = nil; closeCaptureEditor?()
        notify(CaptureNotice(title: "Link saved", message: "Your note and tags are safely in your library."))
        return true
    }
    func cancelDraft() { draft = nil; closeCaptureEditor?() }
    func notify(_ message: String) { notify(CaptureNotice(title: "SaveNest", message: message)) }
    func notify(_ notice: CaptureNotice) {
        toast = notice; showToast?(notice)
        DispatchQueue.main.asyncAfter(deadline: .now() + notice.duration) { [weak self] in
            if self?.toast?.id == notice.id { self?.toast = nil }
        }
    }
    func open(_ link: SavedLink) {
        guard let url = Library.validatedURL(link.url) else { error = "This link is not a valid web address."; return }
        NSWorkspace.shared.open(url)
    }
    func copy(_ link: SavedLink) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(link.url, forType: .string); notify("Link copied") }
    func exportLibrary() {
        let panel = NSSavePanel(); panel.allowedContentTypes = [.json]; panel.nameFieldStringValue = "SaveNest-backup.json"
        guard panel.runModal() == .OK, let url = panel.url else { return }
        do { try LibraryFile(url: url).save(library); notify("Library exported") }
        catch { self.error = "Export failed: \(error.localizedDescription)" }
    }
    func importLibrary() {
        Task { @MainActor in
        guard await authorizeSaving() else { showAccount?(); return }
        let panel = NSOpenPanel(); panel.allowedContentTypes = [.json]; panel.allowsMultipleSelection = false
        guard panel.runModal() == .OK, let url = panel.url else { return }
        guard await authorizeSaving() else { return }
        do {
            let imported = try LibraryFile(url: url).load()
            var next = library
            // Imported identities must not collide with existing SwiftUI identities.
            let links = imported.links.map { link -> SavedLink in var result = link; result.id = UUID(); return result }
            let added = next.insert(links)
            for name in imported.collections where !next.collections.contains(name) && !["All links", "Favorites", "Archive"].contains(name) { next.collections.append(name) }
            if commit(next) { notify("Imported \(added) links") }
        } catch { self.error = "This backup couldn’t be imported. \(error.localizedDescription)" }
        }
    }
    func revealLibrary() { NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path) }
}
