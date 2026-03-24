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

    func applicationDidFinishLaunching(_ notification: Notification) {
        let contentView = NSHostingView(rootView: ContentView())
        panel = FloatingPanel(contentView: contentView)
        panel.center()
        panel.orderFront(nil)
    }
}
