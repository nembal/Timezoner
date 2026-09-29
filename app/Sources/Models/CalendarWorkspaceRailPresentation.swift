import Foundation

public struct CalendarRailContextPresentation: Equatable, Sendable {
    public let title: String
    public let dateTime: String
    public let accessibilityLabel: String
    public let helpText: String

    public init?(selectedEvent: SelectedEventContext?, date: Date, timeZone: TimeZone = .current) {
        guard let selectedEvent else { return nil }

        title = selectedEvent.title
        dateTime = "\(TimeFormatter.formatDate(date, in: timeZone)) · \(TimeFormatter.formatTime(date, in: timeZone)) \(timeZone.abbreviation(for: date) ?? timeZone.identifier)"
        accessibilityLabel = "\(title), \(dateTime)"
        helpText = title
    }
}
