import AppKit
import SwiftUI
import TimeZonerLib

enum FloatingPanelRole {
    case main
    case agenda
}

protocol FloatingPanelInteractionDelegate: AnyObject {
    func floatingPanelDidBecomeKey(_ panel: FloatingPanel)
    func floatingPanelDidResignKey(_ panel: FloatingPanel)
    func floatingPanelDidPressEscape(_ panel: FloatingPanel)
    func floatingPanelDidChangeOrdering(_ panel: FloatingPanel)
    func floatingPanel(_ panel: FloatingPanel, didChangeHugging hugging: Bool)
}

class FloatingPanel: NSPanel {
    private let positionKey = "panelPosition"
    private let menuBarThreshold: CGFloat = 30
    private var lastHugging: Bool = true
    private let role: FloatingPanelRole
    weak var interactionDelegate: FloatingPanelInteractionDelegate?
    private(set) var isHuggingMenuBar = true
    var persistsNormalPosition = true

    init(contentView: NSView, role: FloatingPanelRole = .main) {
        self.role = role
        let initialSize = role == .main
            ? NSSize(width: 750, height: 580)
            : NSSize(width: AgendaPlacementCalculator.wingWidth, height: 580)
        super.init(
            contentRect: NSRect(origin: .zero, size: initialSize),
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

        // Only the main panel owns a persisted origin. The agenda panel is always attached
        // by CalendarPanelCoordinator and must never overwrite the main position key.
        if role == .main {
            if let savedPosition = restorePosition() {
                setFrameOrigin(savedPosition)
            } else {
                positionAtMenuBar()
            }
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
        interactionDelegate?.floatingPanelDidResignKey(self)
    }

    override func becomeKey() {
        super.becomeKey()
        interactionDelegate?.floatingPanelDidBecomeKey(self)
    }

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if event.keyCode == 53 {
            interactionDelegate?.floatingPanelDidPressEscape(self)
            return true
        }
        return super.performKeyEquivalent(with: event)
    }

    override func orderFront(_ sender: Any?) {
        super.orderFront(sender)
        interactionDelegate?.floatingPanelDidChangeOrdering(self)
    }

    override func orderOut(_ sender: Any?) {
        super.orderOut(sender)
        interactionDelegate?.floatingPanelDidChangeOrdering(self)
    }

    // MARK: - Positioning

    func positionAtMenuBar() {
        guard let screen = screen ?? NSScreen.main else { return }
        let visibleTop = screen.visibleFrame.maxY
        let x = screen.visibleFrame.midX - frame.width / 2
        let y = visibleTop - frame.height
        setFrameOrigin(NSPoint(x: x, y: y))
        notifyHugging(true)
    }

    @objc private func windowDidMove(_ notification: Notification) {
        checkIfHuggingMenuBar()
        if role == .main && persistsNormalPosition {
            savePosition()
        }
    }

    private func checkIfHuggingMenuBar() {
        guard let screen = screen ?? NSScreen.screens.first(where: { $0.frame.intersects(frame) }) ?? NSScreen.main else { return }
        let screenTop = screen.visibleFrame.maxY
        let windowTop = frame.origin.y + frame.height
        let hugging = abs(screenTop - windowTop) < menuBarThreshold
        notifyHugging(hugging)
    }

    private func notifyHugging(_ hugging: Bool) {
        isHuggingMenuBar = hugging
        guard hugging != lastHugging else { return }
        lastHugging = hugging
        interactionDelegate?.floatingPanel(self, didChangeHugging: hugging)
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
