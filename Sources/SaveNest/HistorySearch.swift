import Foundation
import SaveNestCore

enum HistoryDiscovery {
    struct Scan { var entries: [BrowserHistoryEntry] = []; var statuses: [HistorySourceStatus] = [] }

    static func scan() -> Scan {
        let home = FileManager.default.homeDirectoryForCurrentUser
        let support = home.appendingPathComponent("Library/Application Support")
        let chromium: [(String, String)] = [
            ("Chrome", "Google/Chrome"), ("Chrome Beta", "Google/Chrome Beta"),
            ("Brave", "BraveSoftware/Brave-Browser"), ("Edge", "Microsoft Edge"),
            ("Arc", "Arc/User Data"), ("Vivaldi", "Vivaldi"), ("Chromium", "Chromium"),
            ("Opera", "com.operasoftware.Opera")
        ]
        var sources: [HistorySource] = [], statuses: [HistorySourceStatus] = []
        func discover(_ directory: URL, browser: String, kind: HistoryDatabaseKind, file: String, nested: Bool) {
            do {
                let children = try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: [.isDirectoryKey], options: [.skipsHiddenFiles])
                if children.contains(where: { $0.lastPathComponent == file }) {
                    sources.append(HistorySource(url: directory.appendingPathComponent(file), browser: browser, profile: "Default", kind: kind))
                }
                if nested {
                    for folder in children.sorted(by: { $0.lastPathComponent < $1.lastPathComponent }).prefix(100) {
                        let name = folder.lastPathComponent
                        if kind == .chromium && name != "Default" && !name.hasPrefix("Profile ") { continue }
                        guard (try? folder.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { continue }
                        let path = folder.appendingPathComponent(file)
                        if FileManager.default.fileExists(atPath: path.path) {
                            sources.append(HistorySource(url: path, browser: browser, profile: name, kind: kind))
                        }
                    }
                }
            } catch {
                let failure = error as NSError
                if failure.domain == NSCocoaErrorDomain && [NSFileNoSuchFileError, NSFileReadNoSuchFileError].contains(failure.code) { return }
                let source = HistorySource(url: directory.appendingPathComponent(file), browser: browser, profile: "Browser data", kind: kind)
                statuses.append(HistorySourceStatus(source: source, count: 0, issue: "Browser files aren’t accessible. Check macOS Privacy & Security."))
            }
        }
        for (browser, directory) in chromium { discover(support.appendingPathComponent(directory), browser: browser, kind: .chromium, file: "History", nested: true) }
        discover(support.appendingPathComponent("Firefox/Profiles"), browser: "Firefox", kind: .firefox, file: "places.sqlite", nested: true)
        discover(home.appendingPathComponent("Library/Safari"), browser: "Safari", kind: .safari, file: "History.db", nested: false)
        var scan = Scan(statuses: statuses)
        let deadline = Date().addingTimeInterval(12)
        for source in sources.prefix(30) {
            if Task<Never, Never>.isCancelled { break }
            if Date() > deadline {
                scan.statuses.append(HistorySourceStatus(source: source, count: 0, issue: "History refresh timed out. Try again.")); continue
            }
            do {
                let entries = try BrowserHistoryReader.read(source)
                scan.entries += entries; scan.statuses.append(HistorySourceStatus(source: source, count: entries.count))
            } catch { scan.statuses.append(HistorySourceStatus(source: source, count: 0, issue: error.localizedDescription)) }
        }
        scan.entries = BrowserHistoryReader.merged(scan.entries)
        return scan
    }
}
