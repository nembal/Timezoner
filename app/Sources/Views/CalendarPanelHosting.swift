import AppKit
import SwiftUI

/// Hosts the persistent calendar root at the frame supplied by the native panel coordinator.
/// The calendar switches between a compact access view and a full grid, neither of which may
/// replace the coordinator's workspace geometry with its intrinsic content size.
public enum CalendarPanelHosting {
    public static func fixed<Content: View>(
        root: Content,
        size: CGSize
    ) -> NSHostingView<Content> {
        let host = NSHostingView(rootView: root)
        host.setFrameSize(size)
        host.sizingOptions = []
        return host
    }
}
