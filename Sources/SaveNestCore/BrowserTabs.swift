import Foundation

// Browser scripting IDs are opaque strings: Chrome returns text, Safari returns numbers.
public struct OpenBrowserTab: Identifiable, Decodable {
    public let browserID: String
    public let browserName: String
    public let windowID: String
    public let tabID: String
    public let index: Int
    public let title: String
    public let url: String
    public var id: String { "\(browserID):\(windowID):\(tabID):\(index)" }
    public var domain: String { URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") ?? url }
}

public struct BrowserTabSnapshot: Identifiable, Codable, Equatable {
    public let browserID: String
    public let browserName: String
    public let windowID: String
    public let windowIndex: Int
    public let tabID: String
    public let index: Int
    public let title: String
    public let url: String
    public let isActive: Bool
    public let isEmpty: Bool
    public var id: String { "\(browserID):\(windowID):\(tabID):\(index)" }
    public var domain: String { URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") ?? "" }

    public init(browserID: String, browserName: String, windowID: String, windowIndex: Int, tabID: String, index: Int, title: String, url: String, isActive: Bool, isEmpty: Bool) {
        self.browserID = browserID; self.browserName = browserName; self.windowID = windowID
        self.windowIndex = windowIndex; self.tabID = tabID; self.index = index
        self.title = title; self.url = url; self.isActive = isActive; self.isEmpty = isEmpty
    }
}

public enum TabCleanupPlanner {
    public static func normalizedDomain(_ raw: String) -> String? {
        let value = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !value.isEmpty, !value.contains(where: { $0.isWhitespace }) else { return nil }
        let candidate = value.contains("://") ? value : "https://" + value
        guard let url = URL(string: candidate), url.user == nil, url.password == nil,
              var host = url.host?.trimmingCharacters(in: CharacterSet(charactersIn: ".")), !host.isEmpty else { return nil }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        return host
    }

    public static func duplicateAndEmptyCandidates(_ tabs: [BrowserTabSnapshot]) -> [BrowserTabSnapshot] {
        var selected: [String: BrowserTabSnapshot] = [:]
        for tab in tabs where tab.isEmpty { selected[tab.id] = tab }
        let webTabs = tabs.filter { !$0.isEmpty && Library.validatedURL($0.url) != nil }
        // Browser scripting does not expose Chromium profile identity. Limit the
        // automatic shortcut to one window so matching URLs in separate profiles
        // are never treated as duplicates.
        let groups = Dictionary(grouping: webTabs) { "\($0.browserID)|\($0.windowID)|\(Library.identity($0.url))" }
        for group in groups.values where group.count > 1 {
            let ordered = group.sorted {
                if $0.isActive != $1.isActive { return $0.isActive && !$1.isActive }
                if $0.windowIndex != $1.windowIndex { return $0.windowIndex < $1.windowIndex }
                return $0.index < $1.index
            }
            for tab in ordered.dropFirst() { selected[tab.id] = tab }
        }
        return selected.values.sorted(by: closeOrder)
    }

    public static func domainCandidates(_ tabs: [BrowserTabSnapshot], domains: [String]) -> [BrowserTabSnapshot] {
        let domains = Set(domains.compactMap(normalizedDomain))
        guard !domains.isEmpty else { return [] }
        return tabs.filter { tab in
            guard Library.validatedURL(tab.url) != nil, let host = normalizedDomain(tab.domain) else { return false }
            return domains.contains { host == $0 || host.hasSuffix("." + $0) }
        }.sorted(by: closeOrder)
    }

    private static func closeOrder(_ lhs: BrowserTabSnapshot, _ rhs: BrowserTabSnapshot) -> Bool {
        if lhs.browserID != rhs.browserID { return lhs.browserID < rhs.browserID }
        if lhs.windowIndex != rhs.windowIndex { return lhs.windowIndex < rhs.windowIndex }
        return lhs.index > rhs.index
    }
}

public struct CapturedTabTarget: Codable {
    public let windowID: String
    public let index: Int
    public let tabID: String?
    public let url: String
    public let safari: Bool
    public var browserID: String = ""
    public var processID: Int32 = 0
}
