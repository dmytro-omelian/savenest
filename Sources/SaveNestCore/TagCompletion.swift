import Foundation

public enum TagCaseStyle: Equatable {
    case lowercase, leadingUppercase, preserve

    public static func matching(_ input: String) -> TagCaseStyle {
        for character in input.trimmingCharacters(in: .whitespacesAndNewlines) {
            let value = String(character)
            let lower = value.lowercased(), upper = value.uppercased()
            guard lower != upper else { continue }
            return value == upper ? .leadingUppercase : .lowercase
        }
        return .preserve
    }

    public static func inferred(from tags: [String]) -> TagCaseStyle {
        var lower = 0, upper = 0
        for tag in tags {
            switch matching(tag) {
            case .lowercase: lower += 1
            case .leadingUppercase: upper += 1
            case .preserve: break
            }
        }
        if lower > upper { return .lowercase }
        if upper > lower { return .leadingUppercase }
        return .preserve
    }

    public func apply(to tag: String) -> String {
        switch self {
        case .lowercase:
            return tag.lowercased()
        case .leadingUppercase:
            guard let range = tag.rangeOfCharacter(from: .letters) else { return tag }
            return String(tag[..<range.lowerBound]) + tag[range].uppercased() + String(tag[range.upperBound...])
        case .preserve:
            return tag
        }
    }
}

public enum TagCompletion {
    public static func matches(input: String, selected: [String], suggestions: [String], limit: Int = 6) -> [String] {
        guard limit > 0 else { return [] }
        let query = input.trimmingCharacters(in: .whitespaces)
        let style = TagCaseStyle.matching(query)
        return suggestions.filter { suggestion in
            !selected.contains { LinkSearch.folded($0) == LinkSearch.folded(suggestion) } &&
                (query.isEmpty || suggestion.localizedCaseInsensitiveContains(query))
        }.prefix(limit).map { style.apply(to: $0) }
    }

    public static func firstMatch(input: String, selected: [String], suggestions: [String]) -> String? {
        guard !input.trimmingCharacters(in: .whitespaces).isEmpty else { return nil }
        return matches(input: input, selected: selected, suggestions: suggestions, limit: 1).first
    }
}
