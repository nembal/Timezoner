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
        // Menu bar icon — create first so we can position the panel below it
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "TimeZoner")
            button.action = #selector(togglePanel)
            button.target = self
        }

        let contentView = NSHostingView(rootView: ContentView())
        contentView.setFrameSize(NSSize(width: 750, height: 220))
        panel = FloatingPanel(contentView: contentView)

        // Position below the status item on first launch
        positionPanelBelowStatusItem()
        panel.orderFront(nil)
    }

    @objc func togglePanel() {
        if panel.isVisible {
            panel.orderOut(nil)
        } else {
            // If no saved position, show below status item
            if UserDefaults.standard.dictionary(forKey: "panelPosition") == nil {
                positionPanelBelowStatusItem()
            }
            panel.orderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    private func positionPanelBelowStatusItem() {
        guard let buttonWindow = statusItem.button?.window else {
            panel.positionAtMenuBar()
            return
        }

        // Get the status item's position on screen
        let buttonFrame = buttonWindow.frame
        let panelWidth = panel.frame.width

        // Center the panel horizontally under the status item
        let x = buttonFrame.midX - panelWidth / 2
        // Place right below the menu bar
        let y = buttonFrame.origin.y - panel.frame.height

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.isHuggingMenuBar = true
    }
}
