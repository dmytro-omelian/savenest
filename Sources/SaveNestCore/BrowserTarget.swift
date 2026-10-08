import Foundation

/// Resolve a capture source without depending on an app activation caused by the shortcut.
public enum BrowserTarget {
    public static func resolve(front: String?, supported: Set<String>, running: Set<String>, remembered: String?, visible: [String]) -> String? {
        if let front, supported.contains(front), running.contains(front) { return front }
        if let remembered, supported.contains(remembered), running.contains(remembered) { return remembered }
        if let browser = visible.first(where: { supported.contains($0) && running.contains($0) }) { return browser }
        let candidates = running.intersection(supported)
        return candidates.count == 1 ? candidates.first : nil
    }
}
