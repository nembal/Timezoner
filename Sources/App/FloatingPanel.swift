import AppKit
import SwiftUI

class FloatingPanel: NSPanel {
    init(contentView: NSView) {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 700, height: 340),
            styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        level = .floating
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        titlebarAppearsTransparent = true
        titleVisibility = .hidden
        // Don't move by background — it eats drag gestures from SwiftUI views
        isMovableByWindowBackground = false
        isOpaque = false
        backgroundColor = .clear
        self.contentView = contentView

        becomesKeyOnlyIfNeeded = false
    }

    override var canBecomeKey: Bool { true }
}
