import Foundation

public enum CalendarPanelIdentity: Equatable, Sendable { case timezoner, calendar }

public enum CalendarWorkspacePolicy {
    public static func calendarVisible(destination: CalendarDestination, showAgenda: Bool) -> Bool {
        destination == .calendar || showAgenda
    }
    public static func mayReadEvents(status: CalendarAuthorizationStatus) -> Bool {
        status == .fullAccess
    }
    public static func settingsOwner(destination: CalendarDestination) -> CalendarPanelIdentity {
        destination == .calendar ? .calendar : .timezoner
    }
}

public enum CalendarPanelMetrics {
    public static let horizontalInset: CGFloat = 20
    public static let normalCardWidth: CGFloat = 200
    public static let normalCardGap: CGFloat = 36
    public static let dragHeight: CGFloat = 20
    public static let topInset: CGFloat = 6
    public static let navHeight: CGFloat = 40
    public static let contentGap: CGFloat = 12
    public static let bottomInset: CGFloat = 16
    public static let iconTarget: CGFloat = 28
    public static let cornerRadius: CGFloat = 12
    public static let gap: CGFloat = 10
    public static let railWidth: CGFloat = 240
    public static let calendarWidth: CGFloat = 760
    public static let preferredHeight: CGFloat = 580
    public static let compactTimeZonerHeight: CGFloat = 260
    public static let compactTimeZonerHeightWithEventContext: CGFloat = 310
    public static let narrowThreshold: CGFloat = 570
    public static let compactToolbarThreshold: CGFloat = 600
    public static func normalWidth(cityCount: Int) -> CGFloat {
        let count = CGFloat(max(cityCount, 2))
        return count * normalCardWidth + (count - 1) * normalCardGap + 2 * horizontalInset
    }

    public static func timeZonerHeight(mapExpanded: Bool, hasSelectedEvent: Bool) -> CGFloat {
        guard !mapExpanded else { return preferredHeight }
        return hasSelectedEvent ? compactTimeZonerHeightWithEventContext : compactTimeZonerHeight
    }

    public static func timeZonerSize(
        cityCount: Int,
        mapExpanded: Bool,
        hasSelectedEvent: Bool
    ) -> CGSize {
        CGSize(
            width: normalWidth(cityCount: cityCount),
            height: timeZonerHeight(mapExpanded: mapExpanded, hasSelectedEvent: hasSelectedEvent)
        )
    }
}
