import SwiftUI
import AppKit

/// A thin draggable bar at the top of the window.
/// Uses manual mouse tracking to avoid macOS tiling gestures.
public struct DragHandle: View {
    public var showPill: Bool
    public var isHugging: Bool

    public init(showPill: Bool = true, isHugging: Bool = false) {
        self.showPill = showPill
        self.isHugging = isHugging
    }

    public var body: some View {
        DragHandleRepresentable(showPill: showPill)
            .frame(height: isHugging ? 8 : 20)
            .frame(maxWidth: .infinity)
    }
}

private struct DragHandleRepresentable: NSViewRepresentable {
    var showPill: Bool

    func makeNSView(context: Context) -> DragHandleNSView {
        let view = DragHandleNSView()
        view.showPill = showPill
        return view
    }

    func updateNSView(_ nsView: DragHandleNSView, context: Context) {
        nsView.showPill = showPill
        nsView.needsDisplay = true
    }
}

class DragHandleNSView: NSView {
    var showPill: Bool = true
    private var initialMouseLocation: NSPoint = .zero
    private var initialWindowOrigin: NSPoint = .zero

    override func mouseDown(with event: NSEvent) {
        // Capture starting positions
        initialMouseLocation = NSEvent.mouseLocation
        initialWindowOrigin = window?.frame.origin ?? .zero
    }

    override func mouseDragged(with event: NSEvent) {
        guard let window = window else { return }
        let currentMouse = NSEvent.mouseLocation
        let dx = currentMouse.x - initialMouseLocation.x
        let dy = currentMouse.y - initialMouseLocation.y
        let newOrigin = NSPoint(x: initialWindowOrigin.x + dx, y: initialWindowOrigin.y + dy)
        window.setFrameOrigin(newOrigin)
    }

    override func draw(_ dirtyRect: NSRect) {
        guard showPill else { return }

        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let pillWidth: CGFloat = 36
        let pillHeight: CGFloat = 4
        let x = (bounds.width - pillWidth) / 2
        let y = (bounds.height - pillHeight) / 2
        let pillRect = CGRect(x: x, y: y, width: pillWidth, height: pillHeight)
        let path = CGPath(roundedRect: pillRect, cornerWidth: 2, cornerHeight: 2, transform: nil)

        ctx.setFillColor(NSColor.separatorColor.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
    }

    // Show open hand cursor
    override func resetCursorRects() {
        addCursorRect(bounds, cursor: .openHand)
    }
}
