import Foundation

public enum LinkTitle {
    public static func clean(_ text: String) -> String {
        String(text.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines).prefix(180))
    }
    public static func isGeneric(_ text: String) -> Bool {
        let value = clean(text).lowercased().replacingOccurrences(of: #"^\(\d+\)\s*"#, with: "", options: .regularExpression)
        return value.isEmpty || ["instagram", "linkedin", "x", "twitter", "x.com", "home / x", "home / twitter", "feed | linkedin", "feed | linkedin.com", "login • instagram", "log in • instagram", "login on x", "sign in | linkedin"].contains(value)
            || value.hasPrefix("log in to ") || value.hasPrefix("sign up for ")
            || value.contains("log in or sign up") || value.contains("sign in or sign up")
            || value.contains("join instagram") || value.contains("professional community")
    }
    public static func best(url: String, browserTitle: String, metadata: [String: String] = [:]) -> String {
        // Post text is scoped to the current permalink by the browser reader.
        for key in ["post", "ogTitle", "twitterTitle", "pageTitle"] {
            if let value = metadata[key], !isGeneric(value) { return clean(value) }
        }
        if !isGeneric(browserTitle) { return clean(browserTitle) }
        for key in ["description", "heading"] {
            if let value = metadata[key], !isGeneric(value), value.count > 12,
               !value.lowercased().contains("sign up"), !value.lowercased().contains("log in"),
               !value.lowercased().contains("join instagram"), !value.lowercased().contains("professional community") {
                return clean(value)
            }
        }
        guard let parsed = URL(string: url), let host = parsed.host else { return clean(browserTitle) }
        let parts = parsed.pathComponents.filter { $0 != "/" }
        let domain = host.replacingOccurrences(of: "www.", with: "")
        if domain == "instagram.com" || domain.hasSuffix(".instagram.com") {
            if parts.count > 1, ["p", "reel", "reels", "tv"].contains(parts[0]) {
                return "Instagram \(parts[0].hasPrefix("reel") ? "reel" : "post") · \(parts[1])"
            }
            if let user = parts.first { return "@\(user) on Instagram" }
        }
        if ["x.com", "twitter.com", "mobile.twitter.com"].contains(domain) {
            if parts.count > 2, parts[1] == "status" { return "@\(parts[0]) on X · \(parts[2])" }
            if let user = parts.first, !["home", "i", "explore", "notifications"].contains(user) { return "@\(user) on X" }
        }
        if domain == "linkedin.com" || domain.hasSuffix(".linkedin.com"), let last = parts.last {
            let readable = last.removingPercentEncoding?.replacingOccurrences(of: "-", with: " ") ?? last
            return clean("LinkedIn · \(readable)")
        }
        return parts.isEmpty ? domain : clean("\(domain) · \(parts.last!.removingPercentEncoding ?? parts.last!)")
    }
}
