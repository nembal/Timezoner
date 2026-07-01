import AppKit
import SwiftUI
import TimeZonerLib

@main
struct TimeZonerApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var panel: FloatingPanel?
    private var statusItem: NSStatusItem!
    private let settings = SettingsStore.shared

    func applicationWillFinishLaunching(_ notification: Notification) {
        settings.applyAppearance()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar icon first
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "TimeZoner")
            button.action = #selector(togglePanel)
            button.target = self
        }

        let contentView = NSHostingView(rootView: ContentView())
        contentView.setFrameSize(NSSize(width: 750, height: 580))
        panel = FloatingPanel(contentView: contentView)

        // Reconcile login item (handles external changes in System Settings)
        _ = LaunchAtLogin.reconcile(desired: settings.launchAtLogin)

        // Global hotkey
        HotkeyManager.shared.onTrigger = { [weak self] in self?.togglePanel() }
        HotkeyManager.shared.rebind(settings.hotkey)
        settings.onHotkeyChange = { shortcut in
            HotkeyManager.shared.rebind(shortcut)
        }

        // Show and position
        showPanel()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let deepLink = TimeZonerDeepLink.parse(url) else { continue }
            DeepLinkRouter.shared.pendingCommand = deepLink
            showPanel()
        }
    }

    @objc func togglePanel() {
        guard let panel else {
            showPanel()
            return
        }

        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        guard let panel else {
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        panel.orderFront(nil)
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
}
