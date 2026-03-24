import AppKit
import SwiftUI
import TimeZonerLib

class FloatingPanel: NSPanel {
    private let positionKey = "panelPosition"
    private let menuBarThreshold: CGFloat = 30

    var isHuggingMenuBar: Bool = true {
        didSet {
            guard oldValue != isHuggingMenuBar else { return }
            updateTrafficLights()
            NotificationCenter.default.post(name: .panelHuggingChanged, object: isHuggingMenuBar)
        }
    }

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 200),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
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

        // Observe window moves
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification, object: self
        )
    }

    // Called after orderFront — buttons exist now
    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        // Delay to ensure window buttons are created
        DispatchQueue.main.async { [weak self] in
            self?.updateTrafficLights()
        }
    }

    override var canBecomeKey: Bool { true }

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
        let titleBarHeight = frame.height - contentRect(forFrameRect: frame).height
        let visibleTop = screen.visibleFrame.maxY
        let x = screen.visibleFrame.midX - frame.width / 2
        let y = visibleTop - frame.height + titleBarHeight
        setFrameOrigin(NSPoint(x: x, y: y))
        isHuggingMenuBar = true
    }

    @objc private func windowDidMove(_ notification: Notification) {
        checkIfHuggingMenuBar()
        savePosition()
    }

    private func checkIfHuggingMenuBar() {
        guard let screen = NSScreen.main else { return }
        let titleBarHeight = frame.height - contentRect(forFrameRect: frame).height
        let screenTop = screen.visibleFrame.maxY
        let windowContentTop = frame.origin.y + frame.height - titleBarHeight
        let gap = screenTop - windowContentTop
        isHuggingMenuBar = abs(gap) < menuBarThreshold
    }

    // MARK: - Traffic lights

    private func updateTrafficLights() {
        let hidden = isHuggingMenuBar
        standardWindowButton(.closeButton)?.isHidden = hidden
        standardWindowButton(.miniaturizeButton)?.isHidden = hidden
        standardWindowButton(.zoomButton)?.isHidden = hidden
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
