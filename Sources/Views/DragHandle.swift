import SwiftUI
import AppKit

/// A thin draggable bar at the top of the window.
/// Dragging it moves the entire window.
public struct DragHandle: View {
    public var showPill: Bool

    public init(showPill: Bool = true) {
        self.showPill = showPill
    }

    public var body: some View {
        DragHandleRepresentable(showPill: showPill)
            .frame(height: showPill ? 20 : 12)
            .frame(maxWidth: .infinity)
    }
}

// NSView that handles window dragging
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

    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
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
}
