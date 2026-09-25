import AppKit
import SwiftUI
import TimeZonerLib

@MainActor
func runCalendarPanelHostTests() {
    print("Running CalendarPanelHostTests...")

    let target = CGSize(
        width: CalendarPanelMetrics.calendarWidth,
        height: CalendarPanelMetrics.preferredHeight
    )
    let host = CalendarPanelHosting.fixed(
        root: AnyView(Color.clear.frame(width: target.width, height: 1_904)),
        size: target
    )
    host.layoutSubtreeIfNeeded()

    workspaceExpect(host.frame.size == target,
                    "calendar host retains the coordinator's 760 by 580 target despite tall content")
    workspaceExpect(host.sizingOptions.isEmpty,
                    "calendar host does not adopt the full calendar view's intrinsic size")
}
