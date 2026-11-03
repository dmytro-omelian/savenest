import Foundation
import SQLite3
import SaveNestCore

func checkBrowserHistory() throws {
    let folder = FileManager.default.temporaryDirectory.appendingPathComponent("SaveNest-History-\(UUID().uuidString)")
    try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: folder) }
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    for kind in [HistoryDatabaseKind.chromium, .firefox, .safari] {
        let url = folder.appendingPathComponent(kind.rawValue + ".sqlite")
        var writer: OpaquePointer?
        precondition(sqlite3_open(url.path, &writer) == SQLITE_OK)
        defer { sqlite3_close(writer) }
        func sql(_ statement: String) { precondition(sqlite3_exec(writer, statement, nil, nil, nil) == SQLITE_OK, String(cString: sqlite3_errmsg(writer))) }
        sql("PRAGMA journal_mode=WAL")
        let recent: Double, old: Double
        switch kind {
        case .chromium:
            recent = (now.timeIntervalSince1970 + 11_644_473_600) * 1_000_000
            old = recent - 100 * 86400 * 1_000_000
            sql("CREATE TABLE urls(url TEXT, title TEXT, last_visit_time INTEGER, visit_count INTEGER, hidden INTEGER)")
            sql("INSERT INTO urls VALUES ('https://example.com/recent', 'Recent page', \(recent), 4, 0), ('https://example.com/old', 'Old', \(old), 1, 0), ('https://example.com/hidden', 'Hidden', \(recent), 1, 1), ('file:///private/local', 'Local', \(recent), 1, 0), ('https://user:secret@example.com', 'Credentials', \(recent), 1, 0)")
        case .firefox:
            recent = now.timeIntervalSince1970 * 1_000_000; old = recent - 100 * 86400 * 1_000_000
            sql("CREATE TABLE moz_places(url TEXT, title TEXT, last_visit_date INTEGER, visit_count INTEGER, hidden INTEGER)")
            sql("INSERT INTO moz_places VALUES ('https://example.com/recent', 'Recent page', \(recent), 4, 0), ('https://example.com/old', 'Old', \(old), 1, 0), ('https://example.com/hidden', 'Hidden', \(recent), 1, 1), ('about:config', 'Internal', \(recent), 1, 0), ('https://user:secret@example.com', 'Credentials', \(recent), 1, 0)")
        case .safari:
            recent = now.timeIntervalSince1970 - 978_307_200; old = recent - 100 * 86400
            sql("CREATE TABLE history_items(id INTEGER PRIMARY KEY, url TEXT, visit_count INTEGER)")
            sql("CREATE TABLE history_visits(history_item INTEGER, title TEXT, visit_time REAL)")
            sql("INSERT INTO history_items VALUES (1, 'https://example.com/recent', 4), (2, 'https://example.com/old', 1), (3, 'file:///private/local', 1), (4, 'https://user:secret@example.com', 1)")
            sql("INSERT INTO history_visits VALUES (1, 'Recent page', \(recent)), (1, 'Previous title', \(recent - 60)), (2, 'Old', \(old)), (3, 'Local', \(recent)), (4, 'Credentials', \(recent))")
        }
        let originalDB = try Data(contentsOf: url), originalWAL = try Data(contentsOf: URL(fileURLWithPath: url.path + "-wal"))
        let source = HistorySource(url: url, browser: kind.rawValue, profile: "Test", kind: kind)
        let entries = try BrowserHistoryReader.read(source, now: now)
        XCTAssertEqual(entries.count, 1)
        XCTAssertEqual(entries[0].title, "Recent page")
        XCTAssertEqual(entries[0].visitCount, 4)
        XCTAssertEqual(entries[0].lastVisited, now)
        // The live database is still open with uncheckpointed WAL data.
        try XCTAssertEqual(try Data(contentsOf: url), originalDB)
        try XCTAssertEqual(try Data(contentsOf: URL(fileURLWithPath: url.path + "-wal")), originalWAL)
        try XCTAssertEqual(try BrowserHistoryReader.read(source, now: now, limit: 1).count <= 1, true)
    }
    let missing = folder.appendingPathComponent("missing.sqlite")
    XCTAssertThrowsError(try BrowserHistoryReader.read(HistorySource(url: missing, browser: "Test", profile: "Test", kind: .chromium)))
    XCTAssertFalse(FileManager.default.fileExists(atPath: missing.path))
    let corrupt = folder.appendingPathComponent("corrupt.sqlite")
    try Data("not a database".utf8).write(to: corrupt)
    XCTAssertThrowsError(try BrowserHistoryReader.read(HistorySource(url: corrupt, browser: "Test", profile: "Test", kind: .safari)))
    try XCTAssertEqual(try Data(contentsOf: corrupt), Data("not a database".utf8))

    let visit = BrowserHistoryEntry(url: "https://github.com/", title: "GitHub — Build software", browser: "Chrome", lastVisited: now, visitCount: 5)
    let older = BrowserHistoryEntry(url: "https://github.com", title: "Old GitHub title", browser: "Firefox", lastVisited: now.addingTimeInterval(-60))
    let unique = BrowserHistoryEntry(url: "https://example.com/history-only", title: "History only", browser: "Firefox", lastVisited: now)
    var saved = SavedLink(url: visit.url, title: "My code projects"); saved.note = "Engineering work"; saved.tags = ["Code"]
    let tab = OpenBrowserTab(browserID: "chrome", browserName: "Chrome", windowID: "1", tabID: "5", index: 1, title: "GitHub", url: visit.url)
    let index = TabWorkspaceIndex(tabs: [tab], links: [saved], history: [older, visit, unique])
    XCTAssertEqual(index.search("", scope: .all).count, 2)
    XCTAssertEqual(index.search("", scope: .history).count, 2)
    XCTAssertEqual(index.search("", scope: .open).count, 1)
    XCTAssertEqual(index.search("", scope: .saved).count, 1)
    let merged = index.search("github", scope: .all).first!
    XCTAssertNotNil(merged.tab); XCTAssertNotNil(merged.link); XCTAssertNotNil(merged.history)
    XCTAssertEqual(merged.history?.browser, "Chrome")
    XCTAssertEqual(index.search("engineering #code", scope: .history).count, 1)
    XCTAssertEqual(index.search("ghub", scope: .all).count, 1)
    XCTAssertEqual(index.search("history only", scope: .all).first?.history?.id, unique.id)
    let removed = TabWorkspaceIndex(tabs: [tab], links: [saved], history: [], reusing: index)
    XCTAssertTrue(removed.search("", scope: .history).isEmpty)
    XCTAssertEqual(removed.search("", scope: .saved).count, 1)
    print("History: three database schemas, live WAL, read-only safety, dates, privacy filters, source merge, fuzzy search and clearing passed")
}
