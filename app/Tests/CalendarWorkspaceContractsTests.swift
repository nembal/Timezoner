import Foundation
import TimeZonerLib

func workspaceExpect(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition { testsPassed += 1 }
    else { testsFailed += 1; print("  FAIL [line \(line)] \(label)") }
}

func runCalendarWorkspaceContractsTests() {
    workspaceExpect(CalendarWorkspacePolicy.calendarVisible(
        destination: .timezoner, showAgenda: true), "normal visible preference shows calendar")
    workspaceExpect(!CalendarWorkspacePolicy.calendarVisible(
        destination: .timezoner, showAgenda: false), "normal explicit hide works")
    workspaceExpect(CalendarWorkspacePolicy.calendarVisible(
        destination: .calendar, showAgenda: false), "workspace always retains calendar")
    workspaceExpect(CalendarPanelMetrics.horizontalInset == 20, "shared outer inset")
    workspaceExpect(CalendarPanelMetrics.navHeight == 40, "shared nav height")
    workspaceExpect(CalendarPanelMetrics.normalWidth(cityCount: 4) == 768,
                    "normal width retains existing card formula")
    workspaceExpect(
        CalendarPanelMetrics.timeZonerHeight(mapExpanded: true, hasSelectedEvent: false)
            == CalendarPanelMetrics.preferredHeight,
        "an expanded map retains the full TimeZoner panel height"
    )
    workspaceExpect(
        CalendarPanelMetrics.timeZonerHeight(mapExpanded: false, hasSelectedEvent: false) == 260,
        "a collapsed map returns the normal TimeZoner panel to its compact height"
    )
    workspaceExpect(
        CalendarPanelMetrics.timeZonerHeight(mapExpanded: false, hasSelectedEvent: true) == 310,
        "a collapsed map still reserves room for a selected event context"
    )
    workspaceExpect(
        CalendarPanelMetrics.timeZonerSize(cityCount: 4, mapExpanded: true, hasSelectedEvent: false)
            == CGSize(width: 768, height: 580),
        "map expansion can resize the TimeZoner panel to its final size before content is inserted"
    )
}
