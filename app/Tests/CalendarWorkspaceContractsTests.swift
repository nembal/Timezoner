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
}
