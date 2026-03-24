import SwiftUI
import AppKit

/// A thin draggable bar at the top of the window.
/// Dragging it moves the entire window.
public struct DragHandle: View {
    public init() {}

    public var body: some View {
        DragHandleRepresentable()
            .frame(height: 20)
            .frame(maxWidth: .infinity)
    }
}

// Small pill indicator in the center
private struct DragPill: View {
    var body: some View {
        RoundedRectangle(cornerRadius: 2)
            .fill(Theme.border)
            .frame(width: 36, height: 4)
    }
}

// NSView that handles window dragging
private struct DragHandleRepresentable: NSViewRepresentable {
    func makeNSView(context: Context) -> DragHandleNSView {
        DragHandleNSView()
    }

    func updateNSView(_ nsView: DragHandleNSView, context: Context) {}
}

private class DragHandleNSView: NSView {
    override func mouseDown(with event: NSEvent) {
        window?.performDrag(with: event)
    }

    override func draw(_ dirtyRect: NSRect) {
        // Draw a small pill in the center
        guard let ctx = NSGraphicsContext.current?.cgContext else { return }
        let pillWidth: CGFloat = 36
        let pillHeight: CGFloat = 4
        let x = (bounds.width - pillWidth) / 2
        let y = (bounds.height - pillHeight) / 2
        let pillRect = CGRect(x: x, y: y, width: pillWidth, height: pillHeight)
        let path = CGPath(roundedRect: pillRect, cornerWidth: 2, cornerHeight: 2, transform: nil)

        // Use a neutral gray that works in both light and dark
        ctx.setFillColor(NSColor.separatorColor.cgColor)
        ctx.addPath(path)
        ctx.fillPath()
    }
}
