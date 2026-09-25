import Foundation
import TimeZonerLib

func runCalendarWorkspaceSessionTests() {
    print("Running CalendarWorkspaceSessionTests...")

    let normalMain = CGRect(x: 180, y: 140, width: 620, height: 500)
    let normalAgenda = CGRect(x: 810, y: 60, width: 220, height: 580)
    let originalVisibleFrame = CGRect(x: 0, y: 40, width: 1_200, height: 800)

    do {
        var session = CalendarWorkspaceSession()
        _ = session.calendarTarget(
            main: normalMain,
            agenda: normalAgenda,
            placement: .right,
            visibleFrame: originalVisibleFrame,
            screenID: "external",
            cityCount: 4
        )

        let expected = CalendarNormalLayoutSnapshot(
            main: normalMain,
            agenda: normalAgenda,
            placement: .right,
            screenID: "external",
            visibleFrame: originalVisibleFrame,
            cityCount: 4
        )
        workspaceExpect(
            session.normalLayoutSnapshot == expected,
            "calendar entry captures the normal layout before workspace frames replace it"
        )
    }

    do {
        var session = CalendarWorkspaceSession()
        let workspace = session.calendarTarget(
            main: normalMain,
            agenda: normalAgenda,
            placement: .right,
            visibleFrame: originalVisibleFrame,
            screenID: "external",
            cityCount: 4
        )
        _ = session.calendarTarget(
            main: workspace.main,
            agenda: workspace.calendar,
            placement: .right,
            visibleFrame: originalVisibleFrame,
            screenID: "external",
            cityCount: 4
        )

        workspaceExpect(
            session.normalLayoutSnapshot?.main == normalMain
                && session.normalLayoutSnapshot?.agenda == normalAgenda,
            "later workspace entries cannot overwrite the saved normal frames"
        )
    }

    do {
        var session = CalendarWorkspaceSession()
        _ = session.calendarTarget(
            main: CGRect(x: -940, y: 260, width: 700, height: 580),
            agenda: CGRect(x: -230, y: 260, width: 220, height: 580),
            placement: .right,
            visibleFrame: CGRect(x: -1_200, y: 40, width: 1_920, height: 900),
            screenID: "disconnected",
            cityCount: 4
        )
        let currentDisplay = CGRect(x: 0, y: 0, width: 1_200, height: 800)
        let restoration = session.timeZonerRestoration(
            visibleFrame: currentDisplay,
            screenID: "built-in",
            cityCount: 8
        )

        workspaceExpect(
            restoration?.main == CGRect(x: 0, y: 220, width: 1_200, height: 580),
            "restoration recalculates from the current display and current city count"
        )
    }

    do {
        var session = CalendarWorkspaceSession()
        _ = session.calendarTarget(
            main: normalMain,
            agenda: normalAgenda,
            placement: .right,
            visibleFrame: originalVisibleFrame,
            screenID: "external",
            cityCount: 4
        )

        _ = session.timeZonerRestoration(
            visibleFrame: originalVisibleFrame,
            screenID: "external",
            cityCount: 4
        )
        workspaceExpect(
            session.normalLayoutSnapshot != nil,
            "computing a restoration leaves the snapshot available until its frames are applied"
        )

        session.finishTimeZonerRestoration()
        workspaceExpect(
            session.normalLayoutSnapshot == nil,
            "finishing an applied restoration clears the normal snapshot"
        )
    }

    do {
        var session = CalendarWorkspaceSession()
        workspaceExpect(
            session.timeZonerRestoration(
                visibleFrame: originalVisibleFrame,
                screenID: "external",
                cityCount: 4
            ) == nil,
            "a targetless normal return has no restoration to apply"
        )
        session.finishTimeZonerRestoration()
        workspaceExpect(
            session.normalLayoutSnapshot == nil,
            "targetless cancellation cannot manufacture or corrupt normal layout state"
        )
    }

    do {
        var events: [String] = []
        CalendarWorkspaceFocusOrder.restoreTimeZonerChat(
            mainPanelIsVisible: true,
            makeMainPanelKey: { events.append("makeKey") },
            postFocusChat: { events.append("focusChat") }
        )
        workspaceExpect(
            events == ["makeKey", "focusChat"],
            "immediate TimeZoner restoration makes the visible main panel key before focusing chat"
        )
    }
}
