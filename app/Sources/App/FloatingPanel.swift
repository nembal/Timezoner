import AppKit
import SwiftUI
import TimeZonerLib

class FloatingPanel: NSPanel {
    private let positionKey = "panelPosition"
    private let menuBarThreshold: CGFloat = 30
    private var lastHugging: Bool = true

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 580),
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
        } else {
            positionAtMenuBar()
        }

        // Check initial hugging state
        checkIfHuggingMenuBar()

        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification, object: self
        )
    }

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

    // MARK: - Positioning

    func positionAtMenuBar() {
        guard let screen = NSScreen.main else { return }
        let visibleTop = screen.visibleFrame.maxY
        let x = screen.visibleFrame.midX - frame.width / 2
        let y = visibleTop - frame.height
        setFrameOrigin(NSPoint(x: x, y: y))
        notifyHugging(true)
    }

    @objc private func windowDidMove(_ notification: Notification) {
        checkIfHuggingMenuBar()
        savePosition()
    }

    private func checkIfHuggingMenuBar() {
        guard let screen = NSScreen.main else { return }
        let screenTop = screen.visibleFrame.maxY
        let windowTop = frame.origin.y + frame.height
        let hugging = abs(screenTop - windowTop) < menuBarThreshold
        notifyHugging(hugging)
    }

    private func notifyHugging(_ hugging: Bool) {
        guard hugging != lastHugging else { return }
        lastHugging = hugging
        NotificationCenter.default.post(name: .panelHuggingChanged, object: hugging)
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

        // Validate position is on a connected screen
        let point = NSPoint(x: x, y: y)
        let testRect = NSRect(origin: point, size: frame.size)
        let onScreen = NSScreen.screens.contains { screen in
            screen.frame.intersects(testRect)
        }
        return onScreen ? point : nil
    }
}
