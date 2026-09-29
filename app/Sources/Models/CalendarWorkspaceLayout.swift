import Foundation

public struct CalendarWorkspaceFrames: Equatable, Sendable {
    public enum Arrangement: Equatable, Sendable { case sideBySide, stacked }

    public let main: CGRect
    public let calendar: CGRect
    public let arrangement: Arrangement

    public init(main: CGRect, calendar: CGRect, arrangement: Arrangement) {
        self.main = main
        self.calendar = calendar
        self.arrangement = arrangement
    }
}

public struct CalendarNormalLayoutSnapshot: Equatable, Sendable {
    public let main: CGRect
    public let agenda: CGRect?
    public let placement: AgendaPlacement
    public let screenID: String?
    public let visibleFrame: CGRect
    public let cityCount: Int

    public init(
        main: CGRect,
        agenda: CGRect?,
        placement: AgendaPlacement,
        screenID: String?,
        visibleFrame: CGRect,
        cityCount: Int
    ) {
        self.main = main
        self.agenda = agenda
        self.placement = placement
        self.screenID = screenID
        self.visibleFrame = visibleFrame
        self.cityCount = cityCount
    }
}

public struct CalendarWorkspaceRestoration: Equatable, Sendable {
    public let main: CGRect
    public let agenda: AgendaPlacementResult

    public init(main: CGRect, agenda: AgendaPlacementResult) {
        self.main = main
        self.agenda = agenda
    }
}

public enum CalendarWorkspaceLayout {
    public static func calculate(
        main: CGRect,
        agenda: CGRect?,
        placement: AgendaPlacement,
        visibleFrame: CGRect
    ) -> CalendarWorkspaceFrames {
        let visible = visibleFrame.width > 0 && visibleFrame.height > 0
            ? visibleFrame
            : CGRect(
                origin: main.origin,
                size: CGSize(width: max(main.width, CalendarPanelMetrics.narrowThreshold), height: max(main.height, 300))
            )
        let height = min(CalendarPanelMetrics.preferredHeight, visible.height)
        let top = min(max(main.maxY, visible.minY + height), visible.maxY)

        if visible.width >= CalendarPanelMetrics.narrowThreshold {
            let rail = min(CalendarPanelMetrics.railWidth, max(200, visible.width - 370))
            let calendar = min(CalendarPanelMetrics.calendarWidth, visible.width - rail - CalendarPanelMetrics.gap)
            let width = rail + CalendarPanelMetrics.gap + calendar
            let desiredRight = placement == .right ? (agenda?.maxX ?? main.maxX) : main.maxX
            let right = min(max(desiredRight, visible.minX + width), visible.maxX)
            let left = right - width

            return CalendarWorkspaceFrames(
                main: CGRect(x: left, y: top - height, width: rail, height: height),
                calendar: CGRect(
                    x: left + rail + CalendarPanelMetrics.gap,
                    y: top - height,
                    width: calendar,
                    height: height
                ),
                arrangement: .sideBySide
            )
        }

        let gap = min(CalendarPanelMetrics.gap, visible.height / 10)
        let railHeight = min(180, (visible.height - gap) * 0.35)
        let calendarHeight = visible.height - railHeight - gap

        return CalendarWorkspaceFrames(
            main: CGRect(
                x: visible.minX,
                y: visible.maxY - railHeight,
                width: visible.width,
                height: railHeight
            ),
            calendar: CGRect(
                x: visible.minX,
                y: visible.minY,
                width: visible.width,
                height: calendarHeight
            ),
            arrangement: .stacked
        )
    }

    public static func restore(
        _ snapshot: CalendarNormalLayoutSnapshot,
        visibleFrame: CGRect,
        screenID: String?,
        cityCount: Int
    ) -> CalendarWorkspaceRestoration {
        let screenChanged = snapshot.screenID != screenID || snapshot.visibleFrame != visibleFrame
        let citiesChanged = snapshot.cityCount != cityCount
        var main = snapshot.main

        if citiesChanged {
            let width = CalendarPanelMetrics.normalWidth(cityCount: cityCount)
            main = CGRect(
                x: main.midX - width / 2,
                y: main.minY,
                width: width,
                height: main.height
            )
        }

        main = CalendarPanelFrameCalculator.restoredNormalFrame(
            main,
            visibleFrame: visibleFrame,
            screenDidChange: screenChanged || citiesChanged
        )

        if !screenChanged && !citiesChanged,
           let agenda = snapshot.agenda,
           visibleFrame.contains(agenda),
           snapshot.placement != .popover {
            return CalendarWorkspaceRestoration(
                main: main,
                agenda: AgendaPlacementResult(location: snapshot.placement, frame: agenda)
            )
        }

        return CalendarWorkspaceRestoration(
            main: main,
            agenda: AgendaPlacementCalculator.calculate(
                mainFrame: main,
                visibleFrame: visibleFrame,
                wingSize: CGSize(
                    width: AgendaPlacementCalculator.wingWidth,
                    height: CalendarPanelMetrics.preferredHeight
                )
            )
        )
    }

    public static func translated(
        _ frames: CalendarWorkspaceFrames,
        by delta: CGSize,
        visibleFrame: CGRect
    ) -> CalendarWorkspaceFrames {
        let union = frames.main.union(frames.calendar)
        let dx = min(
            max(delta.width, visibleFrame.minX - union.minX),
            visibleFrame.maxX - union.maxX
        )
        let dy = min(
            max(delta.height, visibleFrame.minY - union.minY),
            visibleFrame.maxY - union.maxY
        )

        return CalendarWorkspaceFrames(
            main: frames.main.offsetBy(dx: dx, dy: dy),
            calendar: frames.calendar.offsetBy(dx: dx, dy: dy),
            arrangement: frames.arrangement
        )
    }
}
