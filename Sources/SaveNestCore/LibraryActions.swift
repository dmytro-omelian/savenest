import Foundation

public extension Library {
    @discardableResult mutating func renameTag(_ tag: String, to replacement: String) -> Int {
        let source = LinkSearch.folded(tag.trimmingCharacters(in: .whitespacesAndNewlines))
        let normalized = SavedLink.normalizedTags([replacement]).first
        guard !source.isEmpty, let normalized else { return 0 }
        var changed = 0
        for index in links.indices {
            guard links[index].tags.contains(where: { LinkSearch.folded($0) == source }) else { continue }
            let updated = SavedLink.normalizedTags(links[index].tags.map { LinkSearch.folded($0) == source ? normalized : $0 })
            if updated != links[index].tags { links[index].tags = updated; changed += 1 }
        }
        return changed
    }

    @discardableResult mutating func deleteTag(_ tag: String) -> Int {
        let folded = LinkSearch.folded(tag)
        var changed = 0
        for index in links.indices {
            let updated = links[index].tags.filter { LinkSearch.folded($0) != folded }
            if updated != links[index].tags { links[index].tags = updated; changed += 1 }
        }
        return changed
    }

    /// Return only changed IDs, so Undo never restores unrelated archive entries.
    @discardableResult mutating func setArchived(_ archived: Bool, ids: Set<UUID>) -> Set<UUID> {
        var changed = Set<UUID>()
        for index in links.indices where ids.contains(links[index].id) && links[index].isArchived != archived {
            links[index].isArchived = archived
            changed.insert(links[index].id)
        }
        return changed
    }

    /// A confirmation owns a snapshot: later additions and restored links survive.
    @discardableResult mutating func deleteArchived(ids: Set<UUID>) -> Int {
        let before = links.count
        links.removeAll { $0.isArchived && ids.contains($0.id) }
        return before - links.count
    }
}

public enum EmailShare {
    public static func subject(_ title: String) -> String {
        title.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespacesAndNewlines)
    }
    public static func body(link: SavedLink, note: String, includeNote: Bool) -> String {
        let message = note.trimmingCharacters(in: .whitespacesAndNewlines)
        let article = subject(link.title) + "\n" + link.url
        return includeNote && !message.isEmpty ? message + "\n\n" + article : article
    }
}

/// Direction locks once per gesture; normal vertical scrolling never reveals actions.
public struct RowSwipe {
    public enum Axis { case undecided, horizontal, vertical }
    public private(set) var axis: Axis = .undecided
    public private(set) var x = 0.0
    private var y = 0.0
    public init() {}
    public mutating func move(x dx: Double, y dy: Double) {
        x += dx; y += dy
        if axis == .undecided && max(abs(x), abs(y)) >= 8 {
            axis = abs(x) > abs(y) * 1.5 ? .horizontal : .vertical
        }
    }
    public enum Outcome: Equatable { case closed, archive, archiveButton, shareButtons }
    public static func finish(offset: Double, cancelled: Bool = false) -> Outcome {
        guard !cancelled else { return .closed }
        if offset <= -170 { return .archive }
        if offset <= -40 { return .archiveButton }
        if offset >= 40 { return .shareButtons }
        return .closed
    }
}
