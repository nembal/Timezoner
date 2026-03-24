import AppKit
import SwiftUI
import TimeZonerLib

class FloatingPanel: NSPanel {
    private let positionKey = "panelPosition"
    private let menuBarThreshold: CGFloat = 30

    var isHuggingMenuBar: Bool = true {
        didSet {
            guard oldValue != isHuggingMenuBar else { return }
            NotificationCenter.default.post(name: .panelHuggingChanged, object: isHuggingMenuBar)
        }
    }

    init(contentView: NSView) {
        // Borderless — no title bar, no traffic lights, no gap
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 200),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .fullScreenDisallowsTiling]
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        self.contentView = contentView
        becomesKeyOnlyIfNeeded = false

        // Restore saved position or dock to menu bar
        if let savedPosition = restorePosition() {
            setFrameOrigin(savedPosition)
            checkIfHuggingMenuBar()
        } else {
            positionAtMenuBar()
        }

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification, object: self
        )
    }

    // Borderless panels need these overrides to accept key events
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func resignKey() {
        super.resignKey()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            if !self.isKeyWindow && NSApp.keyWindow == nil {
                self.orderOut(nil)
            }
        }
    }

    // MARK: - Menu bar positioning

    func positionAtMenuBar() {
        guard let screen = NSScreen.main else { return }
        let visibleTop = screen.visibleFrame.maxY
        let x = screen.visibleFrame.midX - frame.width / 2
        let y = visibleTop - frame.height
        setFrameOrigin(NSPoint(x: x, y: y))
        isHuggingMenuBar = true
    }

    @objc private func windowDidMove(_ notification: Notification) {
        checkIfHuggingMenuBar()
        savePosition()
    }

    private func checkIfHuggingMenuBar() {
        guard let screen = NSScreen.main else { return }
        let screenTop = screen.visibleFrame.maxY
        let windowTop = frame.origin.y + frame.height
        isHuggingMenuBar = abs(screenTop - windowTop) < menuBarThreshold
    }

    // MARK: - Position persistence

    private func savePosition() {
        let origin = frame.origin
        UserDefaults.standard.set(["x": origin.x, "y": origin.y], forKey: positionKey)
    }

    private func restorePosition() -> NSPoint? {
        guard let dict = UserDefaults.standard.dictionary(forKey: positionKey),
              let x = dict["x"] as? CGFloat,
              let y = dict["y"] as? CGFloat else { return nil }
        return NSPoint(x: x, y: y)
    }
}
