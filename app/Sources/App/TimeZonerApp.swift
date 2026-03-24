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
    private var panel: FloatingPanel!
    private var statusItem: NSStatusItem!

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar icon first
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "TimeZoner")
            button.action = #selector(togglePanel)
            button.target = self
        }

        let contentView = NSHostingView(rootView: ContentView())
        contentView.setFrameSize(NSSize(width: 750, height: 220))
        panel = FloatingPanel(contentView: contentView)

        // Show and position
        showPanel()
    }

    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            showPanel()
        }
    }

    private func showPanel() {
        panel.orderFront(nil)
        panel.makeKey()
        NSApp.activate(ignoringOtherApps: true)
    }
}
