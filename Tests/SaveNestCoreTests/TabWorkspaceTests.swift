import Foundation
import SaveNestCore

func checkTabWorkspace() {
    let safari = OpenBrowserTab(browserID: "safari", browserName: "Safari", windowID: "1", tabID: "", index: 1, title: "A browser page", url: "https://example.com/read")
    let chrome = OpenBrowserTab(browserID: "chrome", browserName: "Chrome", windowID: "2", tabID: "99", index: 1, title: "Another profile", url: safari.url)
    var saved = SavedLink(url: safari.url, title: "My research bookmark")
    saved.note = "Remember the meeting"; saved.tags = ["Research"]; saved.isFavorite = true
    let titleMatch = SavedLink(url: "https://example.com/ritual", title: "Weekly ritual")
    var archived = SavedLink(url: "https://example.com/old", title: "Old project")
    archived.isArchived = true
    let index = TabWorkspaceIndex(tabs: [safari, chrome], links: [saved, titleMatch, archived], contexts: [safari.contextKey: "A weekly ritual for reading and research."])
    XCTAssertEqual(index.search("", scope: .all).count, 3) // both open instances, no duplicate saved row
    XCTAssertEqual(index.search("", scope: .open).count, 2)
    XCTAssertEqual(index.search("", scope: .saved).count, 2)
    XCTAssertEqual(index.search("", scope: .favorites).map(\.link?.id), [saved.id])
    XCTAssertEqual(index.search("", scope: .notes).map(\.link?.id), [saved.id])
    XCTAssertEqual(index.search("", scope: .archive).map(\.link?.id), [archived.id])
    XCTAssertEqual(index.search("old", scope: .all).map(\.link?.id), [archived.id])
    XCTAssertTrue(index.search("old", scope: .saved).isEmpty)
    XCTAssertEqual(index.search("ritual", scope: .all).first?.link?.id, titleMatch.id)
    XCTAssertEqual(index.search("browser ritual #research", scope: .all).map(\.tab?.id), [safari.id])
    XCTAssertEqual(index.search("bookmark", scope: .open).count, 2) // renamed saved titles remain searchable
    XCTAssertEqual(index.search("meeting", scope: .open).count, 2)
    XCTAssertTrue(index.search("#researching", scope: .all).isEmpty)
    XCTAssertTrue(index.search("ritual missing", scope: .all).isEmpty)
    XCTAssertEqual(index.search("safari", scope: .open).count, 1)
    XCTAssertTrue(index.search("ritual", scope: .open).allSatisfy { $0.tab?.browserID == "safari" }) // no context leak across profiles
    XCTAssertEqual(Set(index.search("", scope: .all).map(\.id)).count, 3)

    let now = Date(timeIntervalSince1970: 1_000)
    var cache = TabContextCache()
    cache.store(String(repeating: "a", count: 9_000), for: safari, now: now)
    XCTAssertEqual(cache.text(for: safari, now: now)?.count, 8_000)
    XCTAssertNil(cache.text(for: chrome, now: now))
    XCTAssertNil(cache.text(for: safari, now: now.addingTimeInterval(301)))
    let navigated = OpenBrowserTab(browserID: safari.browserID, browserName: safari.browserName, windowID: safari.windowID, tabID: safari.tabID, index: safari.index, title: "Changed", url: "https://example.com/changed")
    XCTAssertNil(cache.text(for: navigated, now: now))
    cache.prune(tabs: [navigated], now: now)
    XCTAssertNil(cache.text(for: safari, now: now))
    cache.store("", for: chrome, now: now)
    XCTAssertEqual(cache.text(for: chrome, now: now), "") // an empty page is cached too
    cache.prune(tabs: [], now: now)
    XCTAssertNil(cache.text(for: chrome, now: now))

    let tabs = (0..<1_000).map { OpenBrowserTab(browserID: "chrome", browserName: "Chrome", windowID: "1", tabID: String($0), index: $0 + 1, title: "Research page \($0)", url: "https://example.com/\($0)") }
    let context = String(repeating: "Useful page context about design and engineering. ", count: 160)
    let large = TabWorkspaceIndex(tabs: tabs, contexts: Dictionary(uniqueKeysWithValues: tabs.map { ($0.contextKey, context) }))
    let start = Date()
    for _ in 0..<20 { XCTAssertEqual(large.search("research engineering", scope: .all).count, 1_000) }
    let elapsed = Date().timeIntervalSince(start) * 1_000 / 20
    print(String(format: "Workspace: scopes, merge, ranking, privacy and cache checks passed; 1,000-tab search averaged %.1f ms", elapsed))
}
