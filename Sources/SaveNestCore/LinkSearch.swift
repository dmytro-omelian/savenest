import Foundation

/// AND matching across fields, with title matches ranked ahead of notes and URLs.
public enum LinkSearch {
    public static func folded(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
    public static func score(query: String, title: String, url: String, note: String = "", tags: [String] = [], extra: String = "") -> Int? {
        let query = folded(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !query.isEmpty else { return 0 }
        let title = folded(title), url = folded(url), note = folded(note), extra = folded(extra)
        let tags = tags.map(folded)
        let words = query.split(whereSeparator: \.isWhitespace).map(String.init)
        var score = title == query ? 100 : title.hasPrefix(query) ? 45 : title.contains(query) ? 25 : 0
        for word in words {
            if word.hasPrefix("#") {
                guard tags.contains(String(word.dropFirst())) else { return nil }
                score += 30
            } else if title.split(whereSeparator: { !$0.isLetter && !$0.isNumber }).contains(Substring(word)) { score += 20 }
            else if title.contains(word) { score += 12 }
            else if tags.contains(where: { $0.contains(word) }) { score += 10 }
            else if url.contains(word) { score += 6 }
            else if note.contains(word) { score += 4 }
            else if extra.contains(word) { score += 1 }
            else { return nil }
        }
        return score
    }
}

public struct TagSummary: Identifiable, Equatable {
    public var id: String { LinkSearch.folded(name) }
    public let name: String
    public let count: Int
    public static func summarize(_ links: [SavedLink]) -> [TagSummary] {
        var values: [String: (String, Int)] = [:]
        for link in links {
            for tag in SavedLink.normalizedTags(link.tags) {
                let key = LinkSearch.folded(tag)
                let previous = values[key] ?? (tag, 0)
                values[key] = (previous.0, previous.1 + 1)
            }
        }
        return values.values.map { TagSummary(name: $0.0, count: $0.1) }.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
    }
}
