import AppKit
import SwiftUI
import TimeZonerLib

class FloatingPanel: NSPanel {
    private let positionKey = "panelPosition"
    private let menuBarThreshold: CGFloat = 10 // pixels from top to count as "hugging"

    var isHuggingMenuBar: Bool = true {
        didSet {
            updateTrafficLights()
            updateCornerRadius()
        }
    }

    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 750, height: 200),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView, .nonactivatingPanel],
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

        // Start hugging menu bar or restore saved position
        if let savedPosition = restorePosition() {
            setFrameOrigin(savedPosition)
            checkIfHuggingMenuBar()
        } else {
            positionAtMenuBar()
        }

        updateTrafficLights()
        updateCornerRadius()

        // Observe window moves to detect hugging state
        NotificationCenter.default.addObserver(
            self, selector: #selector(windowDidMove),
            name: NSWindow.didMoveNotification, object: self
        )
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
        let screenFrame = screen.visibleFrame
        let x = screenFrame.midX - frame.width / 2
        let y = screenFrame.maxY - frame.height
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
        let windowTop = frame.maxY
        let newHugging = abs(windowTop - screenTop) < menuBarThreshold
        if newHugging != isHuggingMenuBar {
            isHuggingMenuBar = newHugging
        }
    }

    // MARK: - Traffic lights

    private func updateTrafficLights() {
        let hidden = isHuggingMenuBar
        standardWindowButton(.closeButton)?.isHidden = hidden
        standardWindowButton(.miniaturizeButton)?.isHidden = hidden
        standardWindowButton(.zoomButton)?.isHidden = hidden
    }

    // MARK: - Corner radius

    private func updateCornerRadius() {
        // When hugging, square off the top corners
        // This is handled via SwiftUI clip shape, so we post a notification
        NotificationCenter.default.post(name: .panelHuggingChanged, object: isHuggingMenuBar)
    }

    // MARK: - Position persistence

    private func savePosition() {
        let origin = frame.origin
        UserDefaults.standard.set(
            ["x": origin.x, "y": origin.y],
            forKey: positionKey
        )
    }

    private func restorePosition() -> NSPoint? {
        guard let dict = UserDefaults.standard.dictionary(forKey: positionKey),
              let x = dict["x"] as? CGFloat,
              let y = dict["y"] as? CGFloat else { return nil }
        return NSPoint(x: x, y: y)
    }
}

// panelHuggingChanged notification defined in TimeZonerLib/ContentView.swift
