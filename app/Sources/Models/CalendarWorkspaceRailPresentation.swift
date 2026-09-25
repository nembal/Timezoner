import Foundation

public struct CalendarRailCardPresentation: Equatable, Sendable {
    public let title: String
    public let time: String
    public let date: String
    public let offset: String

    public var accessibilityLabel: String { "\(title), \(time), \(date), \(offset)" }

    public init(zone: ZoneInfo, date: Date) {
        title = zone.label
        time = TimeFormatter.formatTime(date, in: zone.timeZone)
        self.date = TimeFormatter.formatDate(date, in: zone.timeZone)
        offset = TimeFormatter.gmtOffset(for: zone.timeZone, at: date)
    }
}

public enum CalendarWorkspaceEventActivation {
    public static func select(_ event: CalendarEventSnapshot, referenceMoment: ReferenceMomentController) {
        referenceMoment.selectEvent(event, sourceZone: .current)
    }
}
