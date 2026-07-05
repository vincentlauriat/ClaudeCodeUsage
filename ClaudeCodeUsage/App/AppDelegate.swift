import AppKit
import Sparkle

/// Wires up Sparkle's standard in-app updater and a "Check for Updates…" menu item.
///
/// Reuses the EdDSA signing key already provisioned under the Keychain account
/// "MarkdownViewer" (shared across Vincent's macOS apps) — see `Scripts/release.sh`.
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let updaterController = SPUStandardUpdaterController(
        startingUpdater: true,
        updaterDelegate: nil,
        userDriverDelegate: nil
    )

    func applicationDidFinishLaunching(_ notification: Notification) {
        addCheckForUpdatesMenuItem()
    }

    /// Inserts "Check for Updates…" into the app menu (after "About ClaudeCodeUsage").
    private func addCheckForUpdatesMenuItem() {
        guard let appMenu = NSApp.mainMenu?.item(at: 0)?.submenu else { return }
        let item = NSMenuItem(
            title: "Check for Updates…",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        item.target = self
        appMenu.insertItem(.separator(), at: 1)
        appMenu.insertItem(item, at: 2)
    }

    @objc private func checkForUpdates() {
        updaterController.checkForUpdates(nil)
    }
}
