import AppKit
import SwiftUI
import TimeZonerLib

@Observable
@MainActor
private final class RevealFixture {
    var zones = [
        ZoneInfo(label: "BKK", timeZoneId: "Asia/Bangkok"),
        ZoneInfo(label: "SF", timeZoneId: "America/Los_Angeles"),
        ZoneInfo(label: "NY", timeZoneId: "America/New_York"),
        ZoneInfo(label: "LDN", timeZoneId: "Europe/London"),
        ZoneInfo(label: "Tokyo", timeZoneId: "Asia/Tokyo")
    ]
    let highlights = ZoneHighlightCoordinator()
    let referenceMoment = ReferenceMomentController(timeState: TimeState())
}

private struct RevealFixtureView: View {
    let fixture: RevealFixture
    var body: some View {
        ZoneCardRow(zones: fixture.zones, referenceMoment: fixture.referenceMoment,
                    editingZoneId: .constant(nil), highlightedZoneIds: fixture.highlights.ids,
                    highlightRequestID: fixture.highlights.requestID,
                    onRemove: { _ in })
    }
}

@MainActor
func runZoneCardRevealTests() async {
    print("Running ZoneCardRevealTests (actual NSHostingView row)...")
    _ = NSApplication.shared
    let fixture = RevealFixture()
    fixture.referenceMoment.timeState.sourceZoneId = "Asia/Bangkok"
    let host = NSHostingView(rootView: RevealFixtureView(fixture: fixture))
    let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 440, height: 180),
                          styleMask: [.borderless], backing: .buffered, defer: false)
    window.contentView = host
    window.orderFront(nil)
    defer { window.orderOut(nil) }
    func settle() async {
        try? await Task.sleep(for: .milliseconds(500))
        host.layoutSubtreeIfNeeded()
    }
    func findScroll(_ view: NSView) -> NSScrollView? {
        if let scroll = view as? NSScrollView { return scroll }
        return view.subviews.lazy.compactMap { findScroll($0) }.first
    }
    await settle()
    guard let scroll = findScroll(host), let document = scroll.documentView else {
        workspaceExpect(false, "the hosted horizontal row exposes its real scroll view")
        return
    }
    func isVisible(index: Int) -> Bool {
        // Card slots are 200 points wide with a 36-point inter-card offset label.
        let card = NSRect(x: index * 236, y: 0, width: 200, height: 1)
        let visible = scroll.documentVisibleRect
        return visible.minX <= card.minX + 1 && visible.maxX >= card.maxX - 1
    }
    func moveToStart() { scroll.contentView.scroll(to: .zero); scroll.reflectScrolledClipView(scroll.contentView) }
    func moveToEnd() {
        scroll.contentView.scroll(to: NSPoint(x: document.bounds.width - scroll.contentSize.width, y: 0))
        scroll.reflectScrolledClipView(scroll.contentView)
    }
    workspaceExpect(!isVisible(index: 4), "the trailing card begins outside the hosted viewport")
    fixture.highlights.show([fixture.zones[0].id, fixture.zones[4].id], clearAfter: .seconds(30))
    await settle()
    workspaceExpect(isVisible(index: 4), "a conversion reveals its existing trailing non-source target")

    moveToStart()
    fixture.highlights.show([fixture.zones[0].id, fixture.zones[4].id], clearAfter: .seconds(30))
    await settle()
    workspaceExpect(isVisible(index: 4), "repeating the same conversion reveals a target hidden by manual scrolling")

    moveToEnd()
    fixture.highlights.show([fixture.zones[0].id], clearAfter: .seconds(30))
    await settle()
    workspaceExpect(isVisible(index: 0), "a source-only request reveals the first card from the end")

    let appended = ZoneInfo(label: "Paris", timeZoneId: "Europe/Paris")
    fixture.zones.append(appended)
    fixture.highlights.show([appended.id], clearAfter: .seconds(30))
    window.setContentSize(NSSize(width: 500, height: 180))
    await settle()
    workspaceExpect(isVisible(index: 5), "an appended highlighted card is revealed after layout and resize")

    // A highlight can arrive before the zone is available to the row.
    let later = ZoneInfo(label: "Sydney", timeZoneId: "Australia/Sydney")
    fixture.highlights.show([later.id], clearAfter: .seconds(30))
    await settle()
    fixture.zones.append(later)
    await settle()
    workspaceExpect(isVisible(index: 6), "a city identity change reveals a previously requested target")
}
