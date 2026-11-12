import Foundation
import TimeZonerLib

func runCalendarWorkspaceLayoutTests() {
    let screen = CGRect(x: -1440, y: 40, width: 1440, height: 860)
    let main = CGRect(x: -1120, y: 240, width: 700, height: 580)
    let agenda = CGRect(x: -410, y: 240, width: 220, height: 580)
    let frames = CalendarWorkspaceLayout.calculate(
        main: main, agenda: agenda, placement: .right, visibleFrame: screen)
    workspaceExpect(frames.main.width == 240 && frames.calendar.width == 760,
                    "preferred rail and calendar widths")
    workspaceExpect(frames.main == CGRect(x: -1200, y: 240, width: 240, height: 580)
                    && frames.calendar == CGRect(x: -950, y: 240, width: 760, height: 580),
                    "normal workspace keeps the exact anchored panel frames")
    workspaceExpect(frames.calendar.maxX == agenda.maxX, "calendar retains right anchor")
    workspaceExpect(frames.main.maxY == main.maxY && frames.calendar.maxY == main.maxY,
                    "both panels retain the top anchor")
    workspaceExpect(frames.calendar.minX - frames.main.maxX == 10, "fixed gap")
    workspaceExpect(screen.contains(frames.main) && screen.contains(frames.calendar),
                    "negative display coordinates stay contained")

    for size in [CGSize(width: 800, height: 600), CGSize(width: 570, height: 400),
                 CGSize(width: 500, height: 700), CGSize(width: 500, height: 300)] {
        let visible = CGRect(origin: CGPoint(x: 90, y: -800), size: size)
        let result = CalendarWorkspaceLayout.calculate(
            main: main, agenda: nil, placement: .popover, visibleFrame: visible)
        workspaceExpect(visible.contains(result.main) && visible.contains(result.calendar),
                        "small-screen frames remain visible")
        workspaceExpect(!result.main.intersects(result.calendar), "panels do not overlap")
        workspaceExpect(result.arrangement == (size.width >= 570 ? .sideBySide : .stacked),
                        "narrow fallback is explicit")
    }
    let constrained = CalendarWorkspaceLayout.calculate(
        main: main, agenda: nil, placement: .popover,
        visibleFrame: CGRect(x: 90, y: -800, width: 570, height: 400))
    workspaceExpect(constrained.main == CGRect(x: 90, y: -800, width: 200, height: 400)
                    && constrained.calendar == CGRect(x: 300, y: -800, width: 360, height: 400),
                    "threshold-width workspace keeps its constrained side-by-side frames")

    let stacked = CalendarWorkspaceLayout.calculate(
        main: main, agenda: nil, placement: .popover,
        visibleFrame: CGRect(x: 90, y: -800, width: 500, height: 300))
    workspaceExpect(stacked.main == CGRect(x: 90, y: -601.5, width: 500, height: 101.5)
                    && stacked.calendar == CGRect(x: 90, y: -800, width: 500, height: 188.5),
                    "narrow workspace keeps its stacked panel frames")

    let fallback = CalendarWorkspaceLayout.calculate(
        main: CGRect(x: 40, y: 50, width: 400, height: 200),
        agenda: nil, placement: .popover, visibleFrame: .zero)
    workspaceExpect(fallback.main == CGRect(x: 40, y: 50, width: 200, height: 300)
                    && fallback.calendar == CGRect(x: 250, y: 50, width: 360, height: 300),
                    "unavailable visible frame uses the exact minimum workspace canvas")

    let snapshot = CalendarNormalLayoutSnapshot(main: main, agenda: agenda,
        placement: .right, screenID: "left", visibleFrame: screen, cityCount: 4)
    let restored = CalendarWorkspaceLayout.restore(snapshot, visibleFrame: screen,
        screenID: "left", cityCount: 4)
    workspaceExpect(restored.main == main && restored.agenda.frame == agenda,
                    "unchanged screen and cities restore exactly")
    let added = CalendarWorkspaceLayout.restore(snapshot, visibleFrame: screen,
        screenID: "left", cityCount: 8)
    workspaceExpect(added.main.width == min(CalendarPanelMetrics.normalWidth(cityCount: 8), screen.width),
                    "city additions cannot restore obsolete width")
    let removedDisplay = CGRect(x: 0, y: 0, width: 900, height: 600)
    let moved = CalendarWorkspaceLayout.restore(snapshot, visibleFrame: removedDisplay,
        screenID: "built-in", cityCount: 4)
    workspaceExpect(removedDisplay.contains(moved.main), "missing display reclamps main")

    let dragged = CalendarWorkspaceLayout.translated(frames,
        by: CGSize(width: 10_000, height: -10_000), visibleFrame: screen)
    workspaceExpect(screen.contains(dragged.main) && screen.contains(dragged.calendar),
                    "pair drag clamps as one object")
    workspaceExpect(dragged.calendar.minX - dragged.main.maxX == 10,
                    "drag cannot detach the panels")
    workspaceExpect(dragged.calendar.maxY == dragged.main.maxY, "drag preserves top alignment")
}
