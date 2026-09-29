import Foundation

/// Owns the normal-panel layout for one calendar workspace visit.
public struct CalendarWorkspaceSession {
    public private(set) var normalLayoutSnapshot: CalendarNormalLayoutSnapshot?
    private var hasPendingTimeZonerRestoration = false

    public init() {}

    public mutating func calendarTarget(
        main: CGRect,
        agenda: CGRect?,
        placement: AgendaPlacement,
        visibleFrame: CGRect,
        screenID: String?,
        cityCount: Int
    ) -> CalendarWorkspaceFrames {
        if normalLayoutSnapshot == nil {
            normalLayoutSnapshot = CalendarNormalLayoutSnapshot(
                main: main,
                agenda: agenda,
                placement: placement,
                screenID: screenID,
                visibleFrame: visibleFrame,
                cityCount: cityCount
            )
        }
        hasPendingTimeZonerRestoration = false

        return CalendarWorkspaceLayout.calculate(
            main: main,
            agenda: agenda,
            placement: placement,
            visibleFrame: visibleFrame
        )
    }

    public mutating func timeZonerRestoration(
        visibleFrame: CGRect,
        screenID: String?,
        cityCount: Int
    ) -> CalendarWorkspaceRestoration? {
        guard let normalLayoutSnapshot else { return nil }
        hasPendingTimeZonerRestoration = true
        return CalendarWorkspaceLayout.restore(
            normalLayoutSnapshot,
            visibleFrame: visibleFrame,
            screenID: screenID,
            cityCount: cityCount
        )
    }

    public mutating func finishTimeZonerRestoration() {
        guard hasPendingTimeZonerRestoration else { return }
        normalLayoutSnapshot = nil
        hasPendingTimeZonerRestoration = false
    }
}
