import AppKit
import SwiftUI

class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 280),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        isMovableByWindowBackground = true
        isOpaque = false
        backgroundColor = .clear
        self.contentView = contentView

        // Allow the panel to resign key status (clicking outside hides it)
        becomesKeyOnlyIfNeeded = false
    }

    // Hide the panel when it loses focus (click outside)
    override func resignKey() {
        super.resignKey()
        orderOut(nil)
    }

    // Allow the panel to become the key window so it can receive keyboard events
    override var canBecomeKey: Bool { true }
}
