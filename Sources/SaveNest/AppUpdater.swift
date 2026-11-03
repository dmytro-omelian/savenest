import AppKit
import Combine
import Sparkle
import SwiftUI

/// One updater shared by the menus and Settings. Sparkle owns its preferences.
@MainActor
final class AppUpdater: NSObject, ObservableObject, NSMenuItemValidation {
    @Published private(set) var canCheckForUpdates = false
    @Published private(set) var automaticallyChecksForUpdates = false
    @Published private(set) var unavailableReason: String?
    private var controller: SPUStandardUpdaterController?

    override init() {
        super.init()
        guard !AppLaunch.isPreview else {
            unavailableReason = "Updates are disabled in SaveNest Preview."
            return
        }
        // The embedded Swift helper must never apply a native Sparkle release
        // over the Electron application, even if its plist is misconfigured.
        guard !ProcessInfo.processInfo.arguments.contains("--electron-bridge") else {
            unavailableReason = "Use SaveNest → Check & Download Updates in the application menu."
            return
        }
        guard Bundle.main.bundleIdentifier == "app.savenest.mac",
              Bundle.main.object(forInfoDictionaryKey: "SaveNestUpdatesEnabled") as? Bool == true else {
            unavailableReason = "Updates are available in the installed release of SaveNest."
            return
        }
        controller = SPUStandardUpdaterController(startingUpdater: false, updaterDelegate: nil, userDriverDelegate: nil)
        if let updater = controller?.updater {
            updater.publisher(for: \.canCheckForUpdates).assign(to: &$canCheckForUpdates)
            updater.publisher(for: \.automaticallyChecksForUpdates).assign(to: &$automaticallyChecksForUpdates)
        }
    }

    func start() {
        guard let controller else { return }
        do {
            try controller.updater.start()
        } catch {
            unavailableReason = "Updates couldn’t start. Reopen SaveNest to try again."
            NSLog("SaveNest updater failed to start: %@", error.localizedDescription)
        }
    }

    func setAutomaticChecks(_ enabled: Bool) {
        guard unavailableReason == nil else { return }
        controller?.updater.automaticallyChecksForUpdates = enabled
    }

    @objc func checkForUpdates(_ sender: Any? = nil) {
        guard canCheckForUpdates, unavailableReason == nil else { return }
        NSApp.activate(ignoringOtherApps: true)
        controller?.checkForUpdates(sender)
    }

    func menuItem() -> NSMenuItem {
        let item = NSMenuItem(title: "Check for Updates…", action: #selector(checkForUpdates(_:)), keyEquivalent: "")
        item.target = self
        return item
    }

    func validateMenuItem(_ menuItem: NSMenuItem) -> Bool {
        canCheckForUpdates && unavailableReason == nil
    }
}

struct AppUpdateSettingsView: View {
    @ObservedObject var updater: AppUpdater

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            fieldLabel("APP UPDATES")
            HStack {
                Text("SaveNest \(version)").font(.system(size: 12, weight: .medium))
                Spacer()
                Button("Check for Updates…") { updater.checkForUpdates() }
                    .buttonStyle(QuietButton())
                    .disabled(!updater.canCheckForUpdates || updater.unavailableReason != nil)
            }
            Toggle("Automatically check for updates", isOn: Binding(
                get: { updater.automaticallyChecksForUpdates },
                set: { updater.setAutomaticChecks($0) }
            ))
            .disabled(updater.unavailableReason != nil)
            Text(updater.unavailableReason ?? "SaveNest checks for new versions in the background. You choose when to download and install them.")
                .font(.system(size: 11)).foregroundStyle(Color.muted)
                .fixedSize(horizontal: false, vertical: true)
        }.padding(20).nestSurface()
    }

    private var version: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "development"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }
}
