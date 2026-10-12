import AppKit
import SwiftUI
import SaveNestCore

struct OpenBrowserTab: Identifiable, Decodable {
    let browserID: String
    let browserName: String
    let windowID: Int
    let tabID: Int
    let index: Int
    let title: String
    let url: String
    var id: String { "\(browserID):\(windowID):\(tabID):\(index)" }
    var domain: String { URL(string: url)?.host?.replacingOccurrences(of: "www.", with: "") ?? url }
}

enum BrowserScript {
    static func run(_ script: String) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let process = Process(), output = Pipe(), errors = Pipe()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
                process.arguments = ["-l", "JavaScript", "-e", script]
                process.standardOutput = output; process.standardError = errors
                do {
                    try process.run()
                    let errorBox = ScriptErrorOutput(), drain = DispatchGroup()
                    drain.enter()
                    DispatchQueue.global().async { errorBox.data = errors.fileHandleForReading.readDataToEndOfFile(); drain.leave() }
                    let timeout = DispatchWorkItem { if process.isRunning { process.terminate() } }
                    DispatchQueue.global().asyncAfter(deadline: .now() + 15, execute: timeout)
                    let data = output.fileHandleForReading.readDataToEndOfFile()
                    process.waitUntilExit(); timeout.cancel(); drain.wait()
                    guard process.terminationStatus == 0 else {
                        let message = String(data: errorBox.data, encoding: .utf8) ?? ""
                        throw CaptureError.failed(message.contains("1743") ? "Allow SaveNest in System Settings → Privacy & Security → Automation." : "The browser did not respond. Try refreshing.")
                    }
                    continuation.resume(returning: data)
                } catch { continuation.resume(throwing: error) }
            }
        }
    }
}
private final class ScriptErrorOutput: @unchecked Sendable { var data = Data() }

@MainActor
final class TabSearchModel: ObservableObject {
    @Published var query = ""
    @Published private(set) var tabs: [OpenBrowserTab] = []
    @Published private(set) var loading = false
    @Published private(set) var switching = false
    @Published private(set) var message: String?
    @Published var selectedIndex = 0
    var close: (() -> Void)?
    private var generation = UUID()
    var results: [OpenBrowserTab] {
        tabs.compactMap { tab -> (OpenBrowserTab, Int)? in
            guard let score = LinkSearch.score(query: query, title: tab.title, url: tab.url, extra: tab.browserName) else { return nil }
            return (tab, score)
        }.sorted { a, b in a.1 == b.1 ? a.0.title.localizedStandardCompare(b.0.title) == .orderedAscending : a.1 > b.1 }.prefix(9).map { $0.0 }
    }
    func refresh() {
        let current = UUID(); generation = current
        loading = true; message = nil; selectedIndex = 0
        let running = Set(NSWorkspace.shared.runningApplications.compactMap(\.bundleIdentifier))
        let browsers = Browser.supported.filter { running.contains($0.id) }
        Task {
            var found: [OpenBrowserTab] = [], failures: [String] = []
            for browser in browsers {
                guard generation == current else { return }
                do {
                    let script = """
                    function run() {
                        const app = Application('\(browser.id)'), result = [];
                        if (!app.running()) return '[]';
                        app.windows().forEach(function(w) {
                            try { const windowID = w.id(); w.tabs().forEach(function(t, i) {
                                try {
                                    const url = t.url() || '';
                                    if (!/^https?:/i.test(url)) return;
                                    result.push({browserID:'\(browser.id)', browserName:'\(browser.name)', windowID:windowID, tabID:\(browser.safari ? "0" : "t.id()"), index:i + 1, title:t.\(browser.safari ? "name" : "title")() || url, url:url});
                                } catch (_) {}
                            }); } catch (_) {}
                        });
                        return JSON.stringify(result);
                    }
                    """
                    let data = try await BrowserScript.run(script)
                    found += try JSONDecoder().decode([OpenBrowserTab].self, from: data)
                } catch { failures.append(browser.name) }
                guard generation == current else { return }
                tabs = found
            }
            guard generation == current else { return }
            tabs = found; loading = false
            if !failures.isEmpty { message = "Couldn’t read \(failures.joined(separator: ", ")). Check Automation access in Settings, then refresh." }
            else if browsers.isEmpty { message = "Open Safari or a supported Chromium browser to search its tabs." }
        }
    }
    func move(_ offset: Int) { selectedIndex = max(0, min(results.count - 1, selectedIndex + offset)) }
    func activate(_ tab: OpenBrowserTab) {
        guard !switching, let browser = Browser.supported.first(where: { $0.id == tab.browserID }) else { return }
        switching = true
        // Encode page data as JSON literals; never interpolate a title or URL as executable code.
        let url = String(data: try! JSONEncoder().encode(tab.url), encoding: .utf8)!
        Task {
            defer { switching = false }
            do {
                let script = """
                function run() {
                    const app = Application('\(browser.id)');
                    if (!app.running()) return 'false';
                    const windows = app.windows(), expectedURL = \(url);
                    for (let i = 0; i < windows.length; i++) {
                        const w = windows[i];
                        if (w.id() !== \(tab.windowID)) continue;
                        const tabs = w.tabs();
                        let index = -1;
                        \(browser.safari ? "if (tabs[\(tab.index - 1)] && tabs[\(tab.index - 1)].url() === expectedURL) index = \(tab.index - 1); else index = tabs.findIndex(t => t.url() === expectedURL);" : "index = tabs.findIndex(t => t.id() === \(tab.tabID) && t.url() === expectedURL);")
                        if (index < 0) return 'false';
                        \(browser.safari ? "w.currentTab = tabs[index];" : "w.activeTabIndex = index + 1;")
                        try { w.minimized = false; } catch (_) {}
                        w.index = 1; app.activate(); return 'true';
                    }
                    return 'false';
                }
                """
                let data = try await BrowserScript.run(script)
                guard String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) == "true" else {
                    message = "That tab moved or closed. Refresh to see what’s open now."; return
                }
                close?()
            } catch { message = "Couldn’t switch tabs. Check browser Automation access and try again." }
        }
    }
}

struct TabSearchView: View {
    @ObservedObject var model: TabSearchModel
    @FocusState private var focused: Bool
    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Image(systemName: "magnifyingglass").font(.system(size: 18)).foregroundStyle(Color.sage)
                TextField("Find an open tab…", text: $model.query).textFieldStyle(.plain).font(.system(size: 19)).focused($focused)
                    .onSubmit { if model.results.indices.contains(model.selectedIndex) { model.activate(model.results[model.selectedIndex]) } }
                    .onKeyPress(.upArrow) { model.move(-1); return .handled }
                    .onKeyPress(.downArrow) { model.move(1); return .handled }
                if model.loading || model.switching { ProgressView().controlSize(.small) }
                Button { model.query = ""; model.close?() } label: { Text("esc").font(.system(size: 10, design: .monospaced)) }.buttonStyle(QuietButton()).keyboardShortcut(.cancelAction)
            }.padding(.horizontal, 18).padding(.vertical, 16)
            Divider()
            HStack {
                fieldLabel(model.query.isEmpty ? "OPEN TABS" : "BEST MATCHES")
                Spacer()
                Text("\(model.tabs.count) tabs in your browsers").font(.system(size: 10)).foregroundStyle(Color.muted)
                Button { model.refresh() } label: { Image(systemName: "arrow.clockwise") }.buttonStyle(.plain).disabled(model.loading).help("Refresh open tabs")
            }.padding(.horizontal, 18).padding(.vertical, 10)
            if let message = model.message {
                Text(message).font(.system(size: 11)).foregroundStyle(Color.muted).frame(maxWidth: .infinity, alignment: .leading).padding(.horizontal, 22).padding(.bottom, 12)
            }
            if model.results.isEmpty {
                VStack(spacing: 9) {
                    Image(systemName: "rectangle.on.rectangle").font(.system(size: 25)).foregroundStyle(Color.muted)
                    Text(model.loading ? "Reading your open tabs…" : "No matching tabs").font(.system(size: 15, weight: .medium))
                    Text("Search by title, website, or browser.").font(.system(size: 12)).foregroundStyle(Color.muted)
                }.frame(maxWidth: .infinity).padding(.vertical, 45)
            } else {
                ScrollView {
                    VStack(spacing: 3) {
                        ForEach(Array(model.results.enumerated()), id: \.element.id) { index, tab in
                            Button { model.activate(tab) } label: {
                                HStack(spacing: 12) {
                                    DomainIcon(domain: tab.domain, url: tab.url).scaleEffect(0.67).frame(width: 28, height: 28)
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(tab.title).font(.system(size: 13, weight: .medium)).lineLimit(1)
                                        Text("\(tab.domain) · \(tab.browserName)").font(.system(size: 11)).foregroundStyle(Color.muted).lineLimit(1)
                                    }
                                    Spacer()
                                    Text("⌘\(index + 1)").font(.system(size: 11, design: .monospaced)).foregroundStyle(Color.muted)
                                }.padding(.horizontal, 12).frame(height: 52).contentShape(Rectangle()).background(model.selectedIndex == index ? Color.sage.opacity(0.12) : Color.surface, in: RoundedRectangle(cornerRadius: 11))
                                    .overlay(RoundedRectangle(cornerRadius: 11).strokeBorder(model.selectedIndex == index ? Color.sage.opacity(0.3) : .clear))
                            }.buttonStyle(.plain).keyboardShortcut(KeyEquivalent(Character(String(index + 1))), modifiers: .command)
                        }
                    }.padding(.horizontal, 10)
                }.frame(height: CGFloat(model.results.count) * 55)
            }
            Divider().padding(.top, 10)
            HStack { Text("↑ ↓ to select   ↵ to switch"); Spacer(); Text("⌘1–9 to jump directly") }
                .font(.system(size: 10)).foregroundStyle(Color.muted).padding(.horizontal, 18).padding(.vertical, 11)
        }.frame(width: 610).background(Color.paper, in: RoundedRectangle(cornerRadius: 22, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 22, style: .continuous).strokeBorder(Color.line.opacity(0.8)))
            .foregroundStyle(Color.ink).preferredColorScheme(.dark)
            .onAppear { focused = true }
            .onChange(of: model.query) { _, _ in model.selectedIndex = 0 }
    }
}
