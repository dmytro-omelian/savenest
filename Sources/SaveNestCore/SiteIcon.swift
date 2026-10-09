import Foundation

public enum SiteIcon {
    public static func origin(_ raw: String) -> URL? {
        guard let url = Library.validatedURL(raw), var parts = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return nil }
        parts.path = "/"; parts.query = nil; parts.fragment = nil
        return parts.url
    }
    public static func resolve(_ raw: String?, relativeTo base: URL) -> URL? {
        guard let raw, raw.count <= 4096,
              let url = URL(string: raw.trimmingCharacters(in: .whitespacesAndNewlines), relativeTo: base)?.absoluteURL else { return nil }
        return Library.validatedURL(url.absoluteString)
    }
    /// Read only icon link declarations; never use tracking pixels or article images as favicons.
    public static func declared(in html: String, base: URL) -> [URL] {
        let links = try! NSRegularExpression(pattern: "<link\\b[^>]*>", options: .caseInsensitive)
        let attributes = try! NSRegularExpression(pattern: #"([\w-]+)\s*=\s*(?:"([^"]*)"|'([^']*)'|([^\s>]+))"#)
        let source = html as NSString
        var regular: [URL] = [], touch: [URL] = []
        for match in links.matches(in: html, range: NSRange(location: 0, length: source.length)) {
            let tag = source.substring(with: match.range) as NSString
            var values: [String: String] = [:]
            for attribute in attributes.matches(in: tag as String, range: NSRange(location: 0, length: tag.length)) {
                let key = tag.substring(with: attribute.range(at: 1)).lowercased()
                for group in 2...4 where attribute.range(at: group).location != NSNotFound {
                    values[key] = tag.substring(with: attribute.range(at: group)).replacingOccurrences(of: "&amp;", with: "&")
                }
            }
            let rel = (values["rel"] ?? "").lowercased().split(whereSeparator: { $0.isWhitespace })
            guard let url = resolve(values["href"], relativeTo: base) else { continue }
            if rel.contains("icon") { regular.append(url) }
            else if rel.contains("apple-touch-icon") || rel.contains("apple-touch-icon-precomposed") { touch.append(url) }
        }
        var seen = Set<URL>()
        return (regular + touch).filter { seen.insert($0).inserted }.prefix(4).map { $0 }
    }
}
