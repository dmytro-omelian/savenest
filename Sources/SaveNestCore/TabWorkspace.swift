import Foundation

public enum TabScope: String, CaseIterable, Identifiable {
    case all = "All", open = "Open", saved = "Saved", history = "History", favorites = "Favorites", notes = "Notes", archive = "Archive"
    public var id: String { rawValue }
}

public struct TabWorkspaceItem: Identifiable, Equatable {
    public let tab: OpenBrowserTab?
    public let link: SavedLink?
    public let context: String
    public let history: BrowserHistoryEntry?
    public init(tab: OpenBrowserTab?, link: SavedLink?, context: String, history: BrowserHistoryEntry? = nil) {
        self.tab = tab; self.link = link; self.context = context; self.history = history
    }
    public var id: String { tab.map { "tab:" + $0.id } ?? link.map { "saved:" + $0.id.uuidString } ?? "history:" + (history?.id ?? "") }
    public var title: String { tab?.title ?? link?.title ?? history?.title ?? "" }
    public var url: String { tab?.url ?? link?.url ?? history?.url ?? "" }
    public var domain: String { tab?.domain ?? link?.domain ?? history?.domain ?? "" }
}

/// Fold fields once, outside the UI thread. Keystrokes only scan this local index.
public struct TabWorkspaceIndex {
    private struct Document {
        let item: TabWorkspaceItem
        let identity: String
        let title: String
        let savedTitle: String
        let historyTitle: String
        let titleWords: Set<String>
        let url: String
        let note: String
        let tags: [String]
        let context: String
        let browser: String
        init(_ item: TabWorkspaceItem) {
            self.item = item
            identity = Library.identity(item.url)
            title = LinkSearch.folded(item.title)
            savedTitle = LinkSearch.folded(item.link?.title ?? "")
            historyTitle = LinkSearch.folded(item.history?.title ?? "")
            titleWords = Set(title.split { !$0.isLetter && !$0.isNumber }.map(String.init))
            url = LinkSearch.folded(item.url)
            note = LinkSearch.folded(item.link?.note ?? "")
            tags = (item.link?.tags ?? []).map(LinkSearch.folded)
            context = LinkSearch.folded(String(item.context.prefix(8_000)))
            browser = LinkSearch.folded((item.tab?.browserName ?? item.link?.browser ?? "") + " " + (item.history?.browser ?? "") + " " + (item.history?.profile ?? ""))
        }
        func score(_ query: String, words: [String]) -> Int? {
            guard !query.isEmpty else { return 0 }
            var result = title == query ? 100 : title.hasPrefix(query) ? 45 : title.contains(query) ? 25 : 0
            for word in words {
                if word.hasPrefix("#") {
                    guard tags.contains(String(word.dropFirst())) else { return nil }
                    result += 30
                } else if titleWords.contains(word) { result += 20 }
                else if title.contains(word) || savedTitle.contains(word) || historyTitle.contains(word) { result += 12 }
                else if tags.contains(where: { $0.contains(word) }) { result += 10 }
                else if url.contains(word) { result += 6 }
                else if note.contains(word) { result += 4 }
                else if context.contains(word) || browser.contains(word) { result += 1 }
                else if words.count == 1 && word.count >= 3 && titleWords.contains(where: { Self.isAbbreviation(word, of: $0) }) { result += 0 }
                else { return nil }
            }
            return result
        }
        private static func isAbbreviation(_ query: String, of word: String) -> Bool {
            guard query.count < word.count, word.count <= query.count * 3, query.first == word.first else { return false }
            var remainder = query[...]
            for character in word where character == remainder.first { remainder.removeFirst(); if remainder.isEmpty { return true } }
            return false
        }
    }
    private let openDocuments: [Document]
    private let savedDocuments: [Document]
    private let historyDocuments: [Document]
    private let openIdentities: Set<String>
    private let savedIdentities: Set<String>

    public init(tabs: [OpenBrowserTab] = [], links: [SavedLink] = [], contexts: [String: String] = [:], history: [BrowserHistoryEntry] = [], reusing previous: TabWorkspaceIndex? = nil) {
        let linksByURL = Dictionary(links.map { (Library.identity($0.url), $0) }, uniquingKeysWith: { first, _ in first })
        let tabsByURL = Dictionary(tabs.map { (Library.identity($0.url), $0) }, uniquingKeysWith: { first, _ in first })
        openIdentities = Set(tabsByURL.keys)
        savedIdentities = Set(linksByURL.keys)
        let visits = BrowserHistoryReader.merged(history)
        let historyByURL = Dictionary(uniqueKeysWithValues: visits.map { (Library.identity($0.url), $0) })
        let previousOpen = Dictionary((previous?.openDocuments ?? []).map { ($0.item.id, $0) }, uniquingKeysWith: { first, _ in first })
        let previousSaved = Dictionary((previous?.savedDocuments ?? []).compactMap { document in document.item.link.map { ($0.id, document) } }, uniquingKeysWith: { first, _ in first })
        openDocuments = tabs.map {
            let item = TabWorkspaceItem(tab: $0, link: linksByURL[Library.identity($0.url)], context: contexts[$0.contextKey] ?? "", history: historyByURL[Library.identity($0.url)])
            if let cached = previousOpen[item.id], cached.item == item { return cached }
            return Document(item)
        }
        savedDocuments = links.sorted { $0.createdAt > $1.createdAt }.map { link in
            let tab = tabsByURL[Library.identity(link.url)]
            let item = TabWorkspaceItem(tab: tab, link: link, context: tab.flatMap { contexts[$0.contextKey] } ?? "", history: historyByURL[Library.identity(link.url)])
            if let cached = previousSaved[link.id], cached.item == item { return cached }
            return Document(item)
        }
        let previousHistory = Dictionary((previous?.historyDocuments ?? []).compactMap { document in document.item.history.map { ($0.id, document) } }, uniquingKeysWith: { first, _ in first })
        historyDocuments = visits.map { visit in
            let tab = tabsByURL[Library.identity(visit.url)]
            let item = TabWorkspaceItem(tab: tab, link: linksByURL[Library.identity(visit.url)], context: tab.flatMap { contexts[$0.contextKey] } ?? "", history: visit)
            if let cached = previousHistory[visit.id], cached.item == item { return cached }
            return Document(item)
        }
    }

    public func search(_ raw: String, scope: TabScope) -> [TabWorkspaceItem] {
        let query = LinkSearch.folded(raw.trimmingCharacters(in: .whitespacesAndNewlines))
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        let candidates: [Document]
        switch scope {
        case .all:
            candidates = openDocuments + savedDocuments.filter {
                !openIdentities.contains($0.identity) && (!($0.item.link?.isArchived ?? false) || !query.isEmpty)
            } + historyDocuments.filter { !openIdentities.contains($0.identity) && !savedIdentities.contains($0.identity) }
        case .open: candidates = openDocuments
        case .history: candidates = historyDocuments
        case .saved: candidates = savedDocuments.filter { !($0.item.link?.isArchived ?? false) }
        case .favorites: candidates = savedDocuments.filter { $0.item.link?.isFavorite == true && $0.item.link?.isArchived == false }
        case .notes: candidates = savedDocuments.filter { !$0.note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && $0.item.link?.isArchived == false }
        case .archive: candidates = savedDocuments.filter { $0.item.link?.isArchived == true }
        }
        return candidates.enumerated().compactMap { offset, document -> (Int, Int, TabWorkspaceItem)? in
            guard let score = document.score(query, words: words) else { return nil }
            return (score, offset, document.item)
        }.sorted { $0.0 == $1.0 ? $0.1 < $1.1 : $0.0 > $1.0 }.map { $0.2 }
    }
}

/// Context never goes to disk. Navigation, closed tabs, expiry, and memory limits evict entries.
public struct TabContextCache {
    private struct Entry { let text: String; let date: Date }
    private var entries: [String: Entry] = [:]
    public init() {}
    public mutating func store(_ text: String, for tab: OpenBrowserTab, now: Date = Date()) {
        entries[tab.contextKey] = Entry(text: String(text.prefix(8_000)), date: now)
        if entries.count > 500, let oldest = entries.min(by: { $0.value.date < $1.value.date })?.key { entries[oldest] = nil }
    }
    public func text(for tab: OpenBrowserTab, now: Date = Date()) -> String? {
        guard let entry = entries[tab.contextKey], now.timeIntervalSince(entry.date) < 300 else { return nil }
        return entry.text
    }
    public mutating func prune(tabs: [OpenBrowserTab], now: Date = Date()) {
        let keys = Set(tabs.map(\.contextKey))
        entries = entries.filter { keys.contains($0.key) && now.timeIntervalSince($0.value.date) < 300 }
    }
}
