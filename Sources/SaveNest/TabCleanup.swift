import AppKit
import Foundation
import SaveNestCore
import SwiftUI

struct TabCleanupReadResult {
    let tabs: [BrowserTabSnapshot]
    let failedBrowsers: [String]
    let foundBrowser: Bool
}

struct TabCleanupCloseResult {
    let requested: Int
    let closed: Int
    let failedBrowsers: [String]
}

final class BrowserTabCleanupService {
    func readTabs() async -> TabCleanupReadResult {
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let browsers = Browser.supported.filter { running.contains($0.id) }
        var tabs: [BrowserTabSnapshot] = []
        var failures: [String] = []
        for browser in browsers {
            do {
                let script = """
                \(BrowserTabScript.script)
                function run() {
                    return JSON.stringify(readBrowserTabsForCleanup(Application('\(browser.id)'), {id:'\(browser.id)', name:'\(browser.name)', safari:\(browser.safari)}));
                }
                """
                let data = try await BrowserScript.run(script)
                tabs += try JSONDecoder().decode([BrowserTabSnapshot].self, from: data)
            } catch {
                failures.append(browser.name)
            }
        }
        return TabCleanupReadResult(tabs: tabs, failedBrowsers: failures, foundBrowser: !browsers.isEmpty)
    }

    func close(_ tabs: [BrowserTabSnapshot]) async -> TabCleanupCloseResult {
        var total = 0
        var failures: [String] = []
        for group in Dictionary(grouping: tabs, by: \.browserID).values {
            guard let first = group.first, let browser = Browser.supported.first(where: { $0.id == first.browserID }) else { continue }
            let payload = group.map { tab in
                ClosePayload(windowID: tab.windowID, tabID: tab.tabID, index: tab.index, url: tab.url, safari: browser.safari)
            }
            do {
                let json = String(data: try JSONEncoder().encode(payload), encoding: .utf8)!
                let data = try await BrowserScript.run(TabCloseScript.script + "\nfunction run() { return String(closeBrowserTabs(Application('" + browser.id + "'), " + json + ")); }")
                total += Int(String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? 0
            } catch {
                failures.append(browser.name)
            }
        }
        return TabCleanupCloseResult(requested: tabs.count, closed: total, failedBrowsers: failures)
    }

    private struct ClosePayload: Encodable {
        let windowID: String
        let tabID: String
        let index: Int
        let url: String
        let safari: Bool
    }
}

struct TabCleanupReviewView: View {
    @ObservedObject var model: AppModel
    let draftID: UUID

    private var draft: TabCleanupDraft? {
        guard model.cleanupReview?.id == draftID else { return nil }
        return model.cleanupReview
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            sheetHeading("Review tabs to close", subtitle: "Cleanup only includes websites you selected. Uncheck anything you want to keep open.")
            if let draft {
                HStack {
                    Button("Select all") { model.updateCleanupSelection(Set(draft.tabs.map(\.id))) }.buttonStyle(.link)
                    Button("Select none") { model.updateCleanupSelection([]) }.buttonStyle(.link)
                    Spacer()
                    Text("\(draft.selected.count) selected").font(.system(size: 11)).foregroundStyle(Color.muted)
                }
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 14) {
                        ForEach(grouped(draft.tabs), id: \.domain) { group in
                            VStack(alignment: .leading, spacing: 6) {
                                HStack {
                                    Text(group.domain).font(.system(size: 11, weight: .semibold)).foregroundStyle(Color.muted)
                                    Text("\(group.tabs.count)").font(.system(size: 10, design: .monospaced)).foregroundStyle(Color.muted)
                                }
                                VStack(spacing: 3) {
                                    ForEach(group.tabs) { tab in
                                        Button {
                                            var selected = draft.selected
                                            if selected.contains(tab.id) { selected.remove(tab.id) } else { selected.insert(tab.id) }
                                            model.updateCleanupSelection(selected)
                                        } label: {
                                            HStack(spacing: 10) {
                                                Image(systemName: draft.selected.contains(tab.id) ? "checkmark.square.fill" : "square")
                                                    .foregroundStyle(draft.selected.contains(tab.id) ? Color.sage : Color.muted)
                                                DomainIcon(domain: tab.domain, url: tab.url).scaleEffect(0.65).frame(width: 28, height: 28)
                                                VStack(alignment: .leading, spacing: 3) {
                                                    Text(tab.title).font(.system(size: 12, weight: .medium)).lineLimit(1)
                                                    Text("\(tab.browserName) · \(tab.url)").font(.system(size: 9)).foregroundStyle(Color.muted).lineLimit(1)
                                                }
                                                Spacer()
                                            }.padding(9).contentShape(Rectangle())
                                        }.buttonStyle(.plain)
                                    }
                                }.nestSurface(radius: 12)
                            }
                        }
                    }
                }.frame(height: min(CGFloat(draft.tabs.count) * 55, 390))
                HStack {
                    Spacer()
                    Button("Cancel") { model.cancelCleanupReview() }.keyboardShortcut(.cancelAction).buttonStyle(.plain)
                    Button(draft.selected.count == 1 ? "Close 1 tab" : "Close \(draft.selected.count) tabs") { model.confirmCleanupReview() }
                        .buttonStyle(SageButton()).keyboardShortcut(.defaultAction).disabled(draft.selected.isEmpty)
                }
            }
        }.padding(28).frame(width: 600).background(Color.paper).foregroundStyle(Color.ink).nestAppearance()
    }

    private func grouped(_ tabs: [BrowserTabSnapshot]) -> [(domain: String, tabs: [BrowserTabSnapshot])] {
        Dictionary(grouping: tabs, by: { $0.domain }).map { ($0.key, $0.value) }
            .sorted { $0.domain.localizedStandardCompare($1.domain) == .orderedAscending }
    }
}
