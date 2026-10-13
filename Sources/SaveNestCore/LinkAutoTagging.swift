import Foundation

/// Local, explainable tag suggestions derived only from tags already in the library.
public enum LinkAutoTagging {
    private struct Candidate {
        let name: String
        var score = 0
        var support = 0
    }

    private static let stopWords: Set<String> = [
        "about", "after", "again", "against", "also", "because", "before", "being", "between",
        "could", "does", "doing", "during", "each", "from", "have", "having", "into", "more",
        "most", "other", "over", "same", "some", "such", "than", "that", "their", "them", "then",
        "there", "these", "they", "this", "those", "through", "under", "until", "very", "what",
        "when", "where", "which", "while", "with", "would", "your"
    ]

    public static func applyingSuggestions(to link: SavedLink, examples: [SavedLink], limit: Int = 3) -> SavedLink {
        var result = link
        result.tags = SavedLink.normalizedTags(result.tags + suggestions(for: result, examples: examples, limit: limit))
        return result
    }

    public static func suggestions(for link: SavedLink, examples: [SavedLink], limit: Int = 3) -> [String] {
        guard limit > 0 else { return [] }

        var identities = Set<String>()
        let currentIdentity = Library.identity(link.url)
        let history = examples.filter { example in
            let identity = Library.identity(example.url)
            return identity != currentIdentity && identities.insert(identity).inserted
        }
        let tagged = history.filter { !SavedLink.normalizedTags($0.tags).isEmpty }
        guard !tagged.isEmpty else { return [] }

        var canonical: [String: String] = [:]
        var globalSupport: [String: Int] = [:]
        for example in tagged {
            for tag in SavedLink.normalizedTags(example.tags) {
                let key = LinkSearch.folded(tag)
                canonical[key] = canonical[key] ?? tag
                globalSupport[key, default: 0] += 1
            }
        }

        var candidates: [String: Candidate] = [:]
        func add(_ key: String, score: Int, support: Int) {
            guard let name = canonical[key] else { return }
            var candidate = candidates[key] ?? Candidate(name: name)
            candidate.score += score
            candidate.support = max(candidate.support, support)
            candidates[key] = candidate
        }

        let titleTokens = usableTitleTokens(for: link)

        // A tag name in the title is the strongest single signal, including short exact tags such as AI or UX.
        if !titleTokens.isEmpty {
            for (key, name) in canonical {
                let tagTokens = tokens(name)
                if containsPhrase(titleTokens, phrase: tagTokens) {
                    add(key, score: 10_000, support: globalSupport[key] ?? 0)
                }
            }
        }

        // Domain evidence needs three tagged links; each suggested tag needs two uses and at least 50% agreement.
        let domain = LinkSearch.folded(link.domain)
        let sameDomain = tagged.filter { LinkSearch.folded($0.domain) == domain }
        if sameDomain.count >= 3 {
            var counts: [String: Int] = [:]
            for example in sameDomain {
                for tag in SavedLink.normalizedTags(example.tags) {
                    counts[LinkSearch.folded(tag), default: 0] += 1
                }
            }
            for (key, count) in counts {
                let confidence = Double(count) / Double(sameDomain.count)
                if count >= 2, confidence >= 0.5 {
                    add(key, score: Int((confidence * 8_000).rounded()), support: count)
                }
            }
        }

        // Learn repeated title-keyword to tag mappings across websites.
        if !titleTokens.isEmpty {
            var keywordExamples: [String: Int] = [:]
            var keywordTags: [String: [String: Int]] = [:]
            for example in tagged {
                let keywords = Set(learnableTokens(for: example))
                guard !keywords.isEmpty else { continue }
                let tagKeys = Set(SavedLink.normalizedTags(example.tags).map(LinkSearch.folded))
                for keyword in keywords {
                    keywordExamples[keyword, default: 0] += 1
                    for key in tagKeys { keywordTags[keyword, default: [:]][key, default: 0] += 1 }
                }
            }

            var learned: [String: (confidence: Double, support: Int)] = [:]
            for (keyword, tagCounts) in keywordTags {
                guard titleTokens.contains(where: { fuzzyMatch($0, keyword) }),
                      let exampleCount = keywordExamples[keyword], exampleCount > 0 else { continue }
                for (key, count) in tagCounts {
                    let confidence = Double(count) / Double(exampleCount)
                    guard count >= 2, confidence >= 0.6 else { continue }
                    let previous = learned[key]
                    if previous == nil || confidence > previous!.confidence || (confidence == previous!.confidence && count > previous!.support) {
                        learned[key] = (confidence, count)
                    }
                }
            }
            for (key, evidence) in learned {
                add(key, score: Int((evidence.confidence * 6_000).rounded()), support: evidence.support)
            }
        }

        let caseStyle = TagCaseStyle.inferred(from: tagged.flatMap { SavedLink.normalizedTags($0.tags) })
        return candidates.values.sorted {
            if $0.score != $1.score { return $0.score > $1.score }
            if $0.support != $1.support { return $0.support > $1.support }
            return $0.name.localizedStandardCompare($1.name) == .orderedAscending
        }.prefix(limit).map { caseStyle.apply(to: $0.name) }
    }

    private static func usableTitleTokens(for link: SavedLink) -> [String] {
        guard !LinkTitle.isGeneric(link.title) else { return [] }
        let title = LinkSearch.folded(LinkTitle.clean(link.title))
        let domain = LinkSearch.folded(link.domain)
        guard title != domain, !title.hasPrefix(domain + " ·") else { return [] }
        return tokens(title)
    }

    private static func learnableTokens(for link: SavedLink) -> [String] {
        usableTitleTokens(for: link).compactMap { token in
            let value = stem(token)
            guard value.count >= 4, !value.allSatisfy(\.isNumber), !stopWords.contains(value) else { return nil }
            return value
        }
    }

    private static func tokens(_ value: String) -> [String] {
        LinkSearch.folded(value).split { !$0.isLetter && !$0.isNumber }.map(String.init)
    }

    private static func containsPhrase(_ title: [String], phrase: [String]) -> Bool {
        guard !phrase.isEmpty, phrase.count <= title.count else { return false }
        for start in 0...(title.count - phrase.count) {
            var matches = true
            for offset in phrase.indices where !fuzzyMatch(title[start + offset], phrase[offset], allowShortExact: true) {
                matches = false
                break
            }
            if matches { return true }
        }
        return false
    }

    private static func fuzzyMatch(_ lhs: String, _ rhs: String, allowShortExact: Bool = false) -> Bool {
        if lhs == rhs { return allowShortExact || lhs.count >= 4 }
        guard lhs.count >= 4, rhs.count >= 4 else { return false }
        if stem(lhs) == stem(rhs) { return true }
        guard lhs.count >= 5, rhs.count >= 5, lhs.first == rhs.first else { return false }
        return oneEditApart(lhs, rhs)
    }

    private static func stem(_ value: String) -> String {
        var result = value
        if result.hasSuffix("ies"), result.count >= 6 {
            result = String(result.dropLast(3)) + "y"
        } else if result.hasSuffix("ing"), result.count >= 7 {
            result = String(result.dropLast(3))
            result = dropRepeatedEnding(result)
        } else if result.hasSuffix("ed"), result.count >= 6 {
            result = String(result.dropLast(2))
            result = dropRepeatedEnding(result)
        } else if result.hasSuffix("es"), result.count >= 6 {
            result = String(result.dropLast(2))
        } else if result.hasSuffix("s"), result.count >= 5 {
            result = String(result.dropLast())
        }
        return result
    }

    private static func dropRepeatedEnding(_ value: String) -> String {
        guard value.count >= 2, value.last == value.dropLast().last else { return value }
        return String(value.dropLast())
    }

    private static func oneEditApart(_ lhs: String, _ rhs: String) -> Bool {
        let left = Array(lhs), right = Array(rhs)
        guard abs(left.count - right.count) <= 1 else { return false }
        if left.count == right.count {
            let differences = left.indices.filter { left[$0] != right[$0] }
            if differences.count == 1 { return true }
            return differences.count == 2 && differences[1] == differences[0] + 1 &&
                left[differences[0]] == right[differences[1]] && left[differences[1]] == right[differences[0]]
        }
        let shorter = left.count < right.count ? left : right
        let longer = left.count < right.count ? right : left
        var shortIndex = 0, longIndex = 0, skipped = false
        while shortIndex < shorter.count, longIndex < longer.count {
            if shorter[shortIndex] == longer[longIndex] {
                shortIndex += 1; longIndex += 1
            } else if skipped {
                return false
            } else {
                skipped = true; longIndex += 1
            }
        }
        return true
    }
}
