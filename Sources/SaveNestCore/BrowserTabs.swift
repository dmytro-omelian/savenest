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

public struct CapturedTabTarget: Codable {
    public let windowID: String
    public let index: Int
    public let tabID: String?
    public let url: String
    public let safari: Bool
    public var browserID: String = ""
    public var processID: Int32 = 0
}
