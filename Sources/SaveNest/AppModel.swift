import AppKit
import SwiftUI
import SaveNestCore
import UniformTypeIdentifiers

struct CaptureDraft: Identifiable {
    var id: UUID { link.id }
    var link: SavedLink
    let action: CaptureAction
    let closeTarget: CapturedTabTarget?
}

struct TabSelectionDraft: Identifiable {
    let id = UUID()
    let links: [SavedLink]
    var selected: Set<UUID>
    init(links: [SavedLink]) { self.links = links; selected = Set(links.map(\.id)) }
}

enum TabCleanupApproval: String, CaseIterable, Identifiable {
    case ask, immediate
    var id: String { rawValue }
    var title: String { self == .ask ? "Ask before closing" : "Close immediately" }
}

struct TabCleanupDraft: Identifiable {
    let id = UUID()
    let tabs: [BrowserTabSnapshot]
    var selected: Set<String>
    init(tabs: [BrowserTabSnapshot]) { self.tabs = tabs; selected = Set(tabs.map(\.id)) }
}

enum AppSection { case library, tags, review, account, settings }

enum AppLaunch {
    static var isPreview: Bool {
        #if DEBUG
        return Bundle.main.bundleIdentifier == "app.savenest.preview" || ProcessInfo.processInfo.arguments.contains("--ui-preview")
        #else
        return false
        #endif
    }
}

@MainActor
final class AppModel: ObservableObject {
    let updater = AppUpdater()
    let account = AccountController()
    let analytics = UsageAnalytics()
    let clipboard = ClipboardMonitor()
    @Published var clipboardEnabled = UserDefaults.standard.bool(forKey: "clipboardEnabled") {
        didSet {
            guard !isPreview else { return }
            UserDefaults.standard.set(clipboardEnabled, forKey: "clipboardEnabled")
            if clipboardEnabled { clipboard.start() } else { clipboard.stop(); dismissClipboardNotice?() }
        }
    }
    @Published var analyticsEnabled = UserDefaults.standard.object(forKey: "analyticsEnabled") as? Bool ?? true {
        didSet {
            guard !isPreview else { return }
            UserDefaults.standard.set(analyticsEnabled, forKey: "analyticsEnabled")
            analytics.configure(enabled: analyticsEnabled)
        }
    }
    @Published var learningEnabled = UserDefaults.standard.object(forKey: "learningEnabled") as? Bool ?? true {
        didSet { if !isPreview { UserDefaults.standard.set(learningEnabled, forKey: "learningEnabled") } }
    }
    var dismissClipboardNotice: (() -> Void)?

    @Published private(set) var library = Library()
    @Published var closeAfterQuickSave = UserDefaults.standard.bool(forKey: "closeAfterQuickSave") {
        didSet { UserDefaults.standard.set(closeAfterQuickSave, forKey: "closeAfterQuickSave") }
    }
    @Published var filter = "All links"
    @Published var query = ""
    @Published var searchEverywhere = true
    @Published var selectedTag: String?
    @Published var selectedDomain: String?
    @Published var notesOnly = false
    @Published var section: AppSection = .library
    let tabSearch = TabSearchModel()
    var showTabSearch: (() -> Void)?
    @Published var selectedID: UUID?
    @Published var sharingLink: SavedLink?
    @Published var swipedLinkID: UUID?
    @Published var showingOnboarding = false
    @Published private(set) var onboardingCompleted = true
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
    @Published var cleanupReview: TabCleanupDraft?
    @Published private(set) var cleanupOpenTabs: [BrowserTabSnapshot] = []
    @Published private(set) var isCleaningTabs = false
    @Published var tabCleanupEnabled = UserDefaults.standard.bool(forKey: "tabCleanupEnabled") {
        didSet { if !isPreview { UserDefaults.standard.set(tabCleanupEnabled, forKey: "tabCleanupEnabled") } }
    }
    @Published var tabCleanupApproval = TabCleanupApproval(rawValue: UserDefaults.standard.string(forKey: "tabCleanupApproval") ?? "ask") ?? .ask {
        didSet { if !isPreview { UserDefaults.standard.set(tabCleanupApproval.rawValue, forKey: "tabCleanupApproval") } }
    }
    @Published private(set) var tabCleanupDomains: [String] = {
        guard let data = UserDefaults.standard.data(forKey: "tabCleanupDomains"),
              let values = try? JSONDecoder().decode([String].self, from: data) else { return [] }
        return values
    }()
    var shortcut: CaptureShortcut { shortcuts[.quick] ?? .standard }
    var shortcutError: String? { shortcutErrors.values.first }
    @Published var toast: CaptureNotice?
    private let file: LibraryFile
    private var loadFailed = false
    let captureService = BrowserCapture()
    let tabCleanupService = BrowserTabCleanupService()
    let hotkey = GlobalShortcut()
    var showLibrary: (() -> Void)?
    var showSettings: (() -> Void)?
    var showAccount: (() -> Void)?
    var showToast: ((CaptureNotice) -> Void)?
    var showCaptureEditor: ((CaptureDraft) -> Void)?
    var closeCaptureEditor: (() -> Void)?
    var showTabSelection: ((TabSelectionDraft) -> Void)?
    var closeTabSelection: (() -> Void)?

    var isPreview: Bool { AppLaunch.isPreview }
    init() {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        file = LibraryFile(url: support.appendingPathComponent("SaveNest/library.json"))
        let stored = UserDefaults.standard.data(forKey: "captureShortcuts").flatMap { try? JSONDecoder().decode([String: CaptureShortcut].self, from: $0) } ?? [:]
        let legacy = UserDefaults.standard.data(forKey: "captureShortcut").flatMap { try? JSONDecoder().decode(CaptureShortcut.self, from: $0) }
        shortcuts = Dictionary(uniqueKeysWithValues: CaptureAction.allCases.map { action in
            (action, stored[action.rawValue] ?? (action == .quick ? legacy : nil) ?? action.defaultShortcut)
        })
        if shortcuts[.quick] == CaptureAction.quick.memorableShortcut,
           shortcuts[.note] == CaptureAction.note.memorableShortcut,
           shortcuts[.tags] == CaptureShortcut.legacyTagsPreset {
            shortcuts[.tags] = CaptureAction.tags.memorableShortcut
            if !isPreview {
                let migrated = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
                UserDefaults.standard.set(try? JSONEncoder().encode(migrated), forKey: "captureShortcuts")
            }
        }
        tabSearch.save = { [weak self] tab in
            guard let self else { return false }
            return await self.saveOpenTab(tab)
        }
        #if DEBUG
        if isPreview {
            var design = SavedLink(url: "https://example.com/design", title: "The details that make a Mac app feel at home", browser: "Safari")
            design.note = "Bring this into the next design pass. Clear hierarchy, quiet surfaces, and keyboard shortcuts that stay out of the way."
            design.tags = ["Design", "Inspiration"]; design.isFavorite = true
            var reading = SavedLink(url: "https://example.com/reading", title: "A small collection of things worth keeping", browser: "Chrome")
            reading.tags = ["Read later"]; reading.createdAt = Date().addingTimeInterval(-86400)
            design.createdAt = Date().addingTimeInterval(-86400)
            let samples = [
                ("https://truto.one/", "Unified Accounting API — 25 Resources, 11 Integrations"),
                ("https://www.swift.org/", "Swift — Build something great"),
                ("https://developer.apple.com/design/", "Human Interface Guidelines — Apple Developer"),
                ("https://www.wikipedia.org/", "A place to start exploring"),
                ("https://www.w3.org/", "Web standards for everyone"),
                ("https://example.org/", "A small collection of things worth reading")
            ].map { SavedLink(url: $0.0, title: $0.1, browser: "Safari") }
            library.insert(samples + [design, reading])
            return
        }
        #endif
        do { library = try file.load() }
        catch { loadFailed = true; self.error = "Your saved library couldn’t be opened. The original file has been kept untouched at \(file.url.path). Restore a valid backup there, then restart SaveNest. \(error.localizedDescription)" }
        if !isPreview && !loadFailed {
            onboardingCompleted = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
            showingOnboarding = !onboardingCompleted
        }
        account.onChange = { [weak self] in
            guard let self else { return }
            self.showOnboardingIfNeededForActiveAccount()
            self.objectWillChange.send()
        }
        analytics.configure(enabled: analyticsEnabled)
        analytics.record(.appOpened)
        clipboard.onLink = { [weak self] url in self?.offerClipboard(url) }
        if clipboardEnabled { clipboard.start() }
        hotkey.action = { [weak self] action in self?.capture(action: action) }
        for action in hotkey.register(shortcuts) { shortcutErrors[action] = "Already in use. Choose another shortcut." }
    }
    var visibleLinks: [SavedLink] {
        let searchingEverywhere = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && searchEverywhere
        return library.links.filter { link in
            let included = searchingEverywhere || linkIsInCurrentSection(link)
            let domainMatches = selectedDomain == nil || LinkSearch.folded(link.domain) == LinkSearch.folded(selectedDomain!)
            return included && domainMatches && link.matches(query) && (!notesOnly || !link.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) && (selectedTag == nil || link.tags.contains { LinkSearch.folded($0) == LinkSearch.folded(selectedTag!) })
        }
    }
    private func linkIsInCurrentSection(_ link: SavedLink) -> Bool {
        switch filter {
        case "All links": return !link.isArchived
        case "Favorites": return link.isFavorite && !link.isArchived
        case "Archive": return link.isArchived
        default: return link.collection == filter && !link.isArchived
        }
    }
    var tagSummaries: [TagSummary] {
        let everywhere = !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && searchEverywhere
        return TagSummary.summarize(library.links.filter { everywhere || linkIsInCurrentSection($0) })
    }
    var domainOptions: [String] {
        Array(Set(library.links.map(\.domain).filter { !$0.isEmpty })).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
    }
    var allTags: [String] { TagSummary.summarize(library.links).map(\.name) }
    var allTagSummaries: [TagSummary] { TagSummary.summarize(library.links) }
    var isTagSearch: Bool { query.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("#") }
    var tagSearchSuggestions: [TagSummary] {
        guard isTagSearch else { return [] }
        let text = query.trimmingCharacters(in: .whitespacesAndNewlines).dropFirst()
        let folded = LinkSearch.folded(String(text))
        return allTagSummaries.filter { folded.isEmpty || LinkSearch.folded($0.name).contains(folded) }.prefix(8).map { $0 }
    }
    var searchScopeTitle: String {
        if searchEverywhere { return "Everywhere" }
        return filter == "All links" ? "Library" : filter
    }
    var hasRefinements: Bool { selectedTag != nil || selectedDomain != nil || notesOnly }
    func clearFilters() { query = ""; selectedTag = nil; selectedDomain = nil; notesOnly = false; searchEverywhere = true }
    func selectTag(_ tag: String) { section = .library; filter = "All links"; notesOnly = false; selectedDomain = nil; selectedTag = tag; query = "" }
    @discardableResult func renameTag(_ tag: String, to replacement: String) -> Bool {
        var next = library
        let changed = next.renameTag(tag, to: replacement)
        guard changed > 0, commit(next) else { return false }
        if LinkSearch.folded(selectedTag ?? "") == LinkSearch.folded(tag) { selectedTag = SavedLink.normalizedTags([replacement]).first }
        notify(changed == 1 ? "Tag updated on 1 link" : "Tag updated on (changed) links")
        return true
    }
    @discardableResult func deleteTag(_ tag: String) -> Bool {
        var next = library
        let changed = next.deleteTag(tag)
        guard changed > 0, commit(next) else { return false }
        if LinkSearch.folded(selectedTag ?? "") == LinkSearch.folded(tag) { selectedTag = nil }
        notify(changed == 1 ? "Tag removed from 1 link" : "Tag removed from (changed) links")
        return true
    }
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
        if action == .duplicates { closeDuplicateTabs(); return }
        if let draft { showCaptureEditor?(draft); return }
        guard !isCapturing else { return }
        isCapturing = true
        let shouldClose = [.quick, .note, .tags].contains(action) && closeAfterQuickSave
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
                        let iconURL = link.iconURL
                        link = existing
                        if let iconURL { link.iconURL = iconURL }
                        if LinkTitle.isGeneric(link.title) { link.title = improved }
                    }
                    beginDraft(link, action: action, closeTarget: captured.closeTarget)
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
    private func saveOpenTab(_ tab: OpenBrowserTab) async -> Bool {
        guard await authorizeSaving() else { return false }
        guard let url = Library.validatedURL(tab.url) else {
            notify(CaptureError.noTabs.notice)
            return false
        }
        // Save the selected search result, irrespective of which browser has focus.
        let link = SavedLink(url: url.absoluteString, title: LinkTitle.best(url: tab.url, browserTitle: tab.title, metadata: [:]), browser: tab.browserName)
        return saveCaptured([link])
    }
    @discardableResult private func saveCaptured(_ links: [SavedLink]) -> Bool {
        var next = library
        for link in links {
            if let iconURL = link.iconURL, let index = next.links.firstIndex(where: { Library.identity($0.url) == Library.identity(link.url) }) { next.links[index].iconURL = iconURL }
            if let index = next.links.firstIndex(where: { Library.identity($0.url) == Library.identity(link.url) }),
               LinkTitle.isGeneric(next.links[index].title), !LinkTitle.isGeneric(link.title) { next.links[index].title = link.title }
        }
        let added = next.insert(links)
        guard commit(next, captureFeedback: true) else { return false }
        analytics.record(.linksSaved, count: added)
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
        if isPreview { return true }
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
        analytics.record(.linksSaved, count: added)
        if !note.isEmpty { analytics.record(.noteSaved) }
        if !tags.isEmpty { analytics.record(.tagsSaved) }
        notify(added == 0 ? "Already tucked away in your nest" : "Link saved")
        return true
    }
    @discardableResult func update(_ link: SavedLink) async -> Bool {
        guard await authorizeSaving() else { return false }
        var next = library
        guard let index = next.links.firstIndex(where: { $0.id == link.id }) else { return false }
        let previous = next.links[index]
        // Editors may have been open while review/archive state changed.
        next.links[index].title = link.title
        next.links[index].note = link.note
        next.links[index].tags = SavedLink.normalizedTags(link.tags)
        next.links[index].isFavorite = link.isFavorite
        guard commit(next) else { return false }
        if previous.note != link.note { analytics.record(.noteSaved) }
        if previous.tags != next.links[index].tags { analytics.record(.tagsSaved) }
        return true
    }
    func favorite(_ link: SavedLink) {
        Task { @MainActor in
            guard await authorizeSaving() else { return }
            var next = library
            guard let index = next.links.firstIndex(where: { $0.id == link.id }) else { return }
            next.links[index].isFavorite.toggle(); _ = commit(next)
        }
    }
    @discardableResult func archive(_ link: SavedLink) -> Bool {
        setArchived(!link.isArchived, ids: [link.id])
    }
    @discardableResult func setArchived(_ archived: Bool, ids: Set<UUID>) -> Bool {
        var next = library
        let changed = next.setArchived(archived, ids: ids)
        guard !changed.isEmpty, commit(next) else { return false }
        selectedID = nil; swipedLinkID = nil
        archiveUndo = ArchiveUndo(ids: changed, archived: archived)
        if archived { analytics.record(.linksArchived, count: changed.count) }
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

    func completeOnboarding() {
        if let accountID = account.account?.user.id {
            UserDefaults.standard.set(true, forKey: onboardingKey(for: accountID))
        } else {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        }
        onboardingCompleted = true
        showingOnboarding = false
    }
    func showOnboarding() { showingOnboarding = true }

    private func onboardingKey(for accountID: String) -> String {
        "hasCompletedOnboarding.\(accountID)"
    }

    private func showOnboardingIfNeededForActiveAccount() {
        guard !isPreview, !loadFailed, account.canSave else { return }
        let completed = if let accountID = account.account?.user.id {
            UserDefaults.standard.bool(forKey: onboardingKey(for: accountID))
        } else {
            UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        }
        onboardingCompleted = completed
        if !completed { showingOnboarding = true }
    }

    func delete(_ link: SavedLink) {
        var next = library; next.links.removeAll { $0.id == link.id }
        if commit(next) { selectedID = nil; notify("Link deleted") }
    }
    func configureShortcut(_ value: CaptureShortcut?, for action: CaptureAction) {
        if isPreview { if let value { shortcuts[action] = value }; return }
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
    func beginDraft(_ link: SavedLink, action: CaptureAction, closeTarget: CapturedTabTarget? = nil) {
        if let draft { showCaptureEditor?(draft); return }
        let draft = CaptureDraft(link: link, action: action, closeTarget: closeTarget)
        self.draft = draft; showCaptureEditor?(draft)
    }
    @discardableResult func saveDraft(_ link: SavedLink) async -> Bool {
        guard await authorizeSaving() else { return false }
        let closeTarget = draft?.id == link.id ? draft?.closeTarget : nil
        var next = library
        let isNew = !next.links.contains { Library.identity($0.url) == Library.identity(link.url) }
        guard next.saveAnnotated(link) else { notify(CaptureNotice(title: "Couldn’t save this link", message: "The web address is invalid.", isError: true)); return false }
        guard commit(next, captureFeedback: true) else { return false }
        analytics.record(.linksSaved, count: isNew ? 1 : 0)
        if link.browser == "Clipboard" && isNew { analytics.record(.clipboardSaved) }
        if !link.note.isEmpty { analytics.record(.noteSaved) }
        if !link.tags.isEmpty { analytics.record(.tagsSaved) }
        draft = nil; closeCaptureEditor?()
        if let closeTarget {
            let closed = await captureService.closeSavedTab(closeTarget)
            notify(CaptureNotice(title: closed ? "Saved & closed" : "Saved · tab left open", message: closed ? "Your note and tags are safely in your library." : "The tab changed or couldn’t be closed safely. Your note and tags are saved."))
        } else {
            notify(CaptureNotice(title: "Link saved", message: "Your note and tags are safely in your library."))
        }
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
        if NSWorkspace.shared.open(url) { analytics.record(.linkOpened) }
    }
    func copy(_ link: SavedLink) { NSPasteboard.general.clearContents(); NSPasteboard.general.setString(link.url, forType: .string); analytics.record(.linkCopied); notify("Link copied") }
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
            if commit(next) { analytics.record(.linksSaved, count: added); notify("Imported \(added) links") }
        } catch { self.error = "This backup couldn’t be imported. \(error.localizedDescription)" }
        }
    }
    private func offerClipboard(_ url: URL) {
        guard clipboardEnabled, !isCapturing, draft == nil, tabSelection == nil,
              !library.links.contains(where: { Library.identity($0.url) == Library.identity(url.absoluteString) }) else { return }
        notify(CaptureNotice(title: "Save copied link?", message: url.host ?? "Copied web link", clipboardURL: url))
    }
    func saveClipboard(_ url: URL, withNote: Bool = false) {
        Task { @MainActor in
            guard await authorizeSaving() else { return }
            // The prompt owns its URL, even if the clipboard changes before it is clicked.
            let link = SavedLink(url: url.absoluteString, title: LinkTitle.best(url: url.absoluteString, browserTitle: ""), browser: "Clipboard")
            if withNote {
                let existing = library.links.first { Library.identity($0.url) == Library.identity(link.url) }
                beginDraft(existing ?? link, action: .note)
            } else {
                let isNew = !library.links.contains { Library.identity($0.url) == Library.identity(link.url) }
                if saveCaptured([link]) && isNew { analytics.record(.clipboardSaved) }
            }
        }
    }
    func saveCurrentClipboard() {
        guard let text = NSPasteboard.general.string(forType: .string), let url = ClipboardLink.parse(text) else {
            notify(CaptureNotice(title: "No copied link", message: "Copy a complete http:// or https:// web address first.", isError: true)); return
        }
        saveClipboard(url)
    }
    func labelImportance(_ link: SavedLink, _ importance: LinkImportance?) {
        Task { @MainActor in
            guard await authorizeSaving() else { return }
            var next = library
            guard let index = next.links.firstIndex(where: { $0.id == link.id }) else { return }
            next.links[index].importance = importance
            if commit(next), importance != nil { analytics.record(.importanceLabeled) }
        }
    }
    func resetLearning() {
        var next = library
        for index in next.links.indices { next.links[index].importance = nil }
        if commit(next) { notify("Importance feedback reset") }
    }
    func applyMemorableShortcuts() {
        let previous = shortcuts
        var candidate = shortcuts
        for action in [CaptureAction.quick, .note, .tags] { candidate[action] = action.memorableShortcut }
        let all = Array(candidate.values)
        guard Set(all.map { "\($0.keyCode):\($0.modifiers)" }).count == all.count else {
            error = "The preset conflicts with another SaveNest shortcut. Change that shortcut first."; return
        }
        if isPreview { shortcuts = candidate; return }
        let failed = hotkey.register(candidate)
        guard failed.isEmpty else {
            _ = hotkey.register(previous); error = "One of the preset shortcuts is unavailable. Your shortcuts are unchanged."; return
        }
        shortcuts = candidate; shortcutErrors = [:]
        let saved = Dictionary(uniqueKeysWithValues: shortcuts.map { ($0.key.rawValue, $0.value) })
        UserDefaults.standard.set(try? JSONEncoder().encode(saved), forKey: "captureShortcuts")
    }
    @discardableResult func addCleanupDomain(_ raw: String) -> Bool {
        guard let domain = TabCleanupPlanner.normalizedDomain(raw) else {
            error = "Enter a website such as example.com."
            return false
        }
        guard !tabCleanupDomains.contains(domain) else { return true }
        tabCleanupDomains.append(domain)
        tabCleanupDomains.sort { $0.localizedStandardCompare($1) == .orderedAscending }
        persistCleanupDomains()
        return true
    }
    func removeCleanupDomain(_ domain: String) {
        tabCleanupDomains.removeAll { $0 == domain }
        persistCleanupDomains()
    }
    private func persistCleanupDomains() {
        guard !isPreview else { return }
        UserDefaults.standard.set(try? JSONEncoder().encode(tabCleanupDomains), forKey: "tabCleanupDomains")
    }
    func refreshCleanupOpenTabs() {
        guard !isCleaningTabs else { return }
        isCleaningTabs = true
        Task { @MainActor in
            let result = await tabCleanupService.readTabs()
            cleanupOpenTabs = result.tabs
            isCleaningTabs = false
            if !result.failedBrowsers.isEmpty {
                error = "Couldn’t read \(result.failedBrowsers.joined(separator: ", ")). Check Automation access and try again."
            }
        }
    }
    func closeDuplicateTabs() {
        guard !isCleaningTabs else { return }
        isCleaningTabs = true
        Task { @MainActor in
            let read = await tabCleanupService.readTabs()
            let candidates = TabCleanupPlanner.duplicateAndEmptyCandidates(read.tabs)
            guard !candidates.isEmpty else {
                isCleaningTabs = false
                if !read.failedBrowsers.isEmpty {
                    notify(CaptureNotice(title: "Couldn’t inspect every browser", message: "Check Automation access for \(read.failedBrowsers.joined(separator: ", ")), then try again.", isError: true))
                } else {
                    let message = read.foundBrowser ? "No duplicate or empty tabs found." : "Open a supported browser, then try again."
                    notify(CaptureNotice(title: "Tabs already tidy", message: message, isError: !read.foundBrowser))
                }
                return
            }
            let result = await tabCleanupService.close(candidates)
            isCleaningTabs = false
            notifyCleanupResult(result, title: "Duplicate tabs cleaned up")
        }
    }
    func runTabCleanup() {
        guard tabCleanupEnabled else {
            notify(CaptureNotice(title: "Tab Cleanup is off", message: "Turn it on in Settings before running a website cleanup.", isError: true))
            return
        }
        guard !tabCleanupDomains.isEmpty else {
            notify(CaptureNotice(title: "Choose cleanup websites", message: "Add at least one website in Settings before running cleanup.", isError: true))
            return
        }
        guard !isCleaningTabs else { return }
        isCleaningTabs = true
        Task { @MainActor in
            let read = await tabCleanupService.readTabs()
            cleanupOpenTabs = read.tabs
            let candidates = TabCleanupPlanner.domainCandidates(read.tabs, domains: tabCleanupDomains)
            isCleaningTabs = false
            guard !candidates.isEmpty else {
                if !read.failedBrowsers.isEmpty {
                    notify(CaptureNotice(title: "Couldn’t inspect every browser", message: "Check Automation access for \(read.failedBrowsers.joined(separator: ", ")), then try again.", isError: true))
                } else {
                    notify(CaptureNotice(title: "Nothing to clean up", message: read.foundBrowser ? "No open tabs match your cleanup websites." : "Open a supported browser, then try again.", isError: !read.foundBrowser))
                }
                return
            }
            if tabCleanupApproval == .ask {
                cleanupReview = TabCleanupDraft(tabs: candidates)
                showLibrary?()
            } else {
                isCleaningTabs = true
                let result = await tabCleanupService.close(candidates)
                isCleaningTabs = false
                notifyCleanupResult(result, title: "Tabs cleaned up")
            }
        }
    }
    func updateCleanupSelection(_ selected: Set<String>) {
        guard var draft = cleanupReview else { return }
        draft.selected = selected; cleanupReview = draft
    }
    func cancelCleanupReview() { cleanupReview = nil }
    func confirmCleanupReview() {
        guard let draft = cleanupReview else { return }
        let tabs = draft.tabs.filter { draft.selected.contains($0.id) }
        guard !tabs.isEmpty else { return }
        cleanupReview = nil; isCleaningTabs = true
        Task { @MainActor in
            let result = await tabCleanupService.close(tabs)
            isCleaningTabs = false
            notifyCleanupResult(result, title: "Tabs cleaned up")
        }
    }
    private func notifyCleanupResult(_ result: TabCleanupCloseResult, title: String) {
        if result.closed == 0 {
            notify(CaptureNotice(title: "No tabs closed", message: "The tabs moved, changed, or couldn’t be closed safely.", isError: true))
            return
        }
        let skipped = result.requested - result.closed
        let detail = skipped == 0 ? "\(result.closed) \(result.closed == 1 ? "tab" : "tabs") closed." : "\(result.closed) closed · \(skipped) left open because they changed or moved."
        notify(CaptureNotice(title: title, message: detail, isError: !result.failedBrowsers.isEmpty))
    }
    func revealLibrary() { NSWorkspace.shared.selectFile(file.url.path, inFileViewerRootedAtPath: file.url.deletingLastPathComponent().path) }
}
