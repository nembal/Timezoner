import Foundation

public enum CalendarRangeSelection: String, CaseIterable, Equatable, Sendable {
    case today
    case threeDays
    case week
}

public enum CalendarRangeNavigationDirection: Equatable, Sendable {
    case previous
    case next
}

public enum CalendarDateIntervalCalculator {
    public static func interval(
        for range: CalendarRangeSelection,
        anchor: Date,
        calendar: Calendar
    ) -> DateInterval {
        let startOfAnchorDay = calendar.startOfDay(for: anchor)

        switch range {
        case .today:
            let end = calendar.date(byAdding: .day, value: 1, to: startOfAnchorDay)!
            return DateInterval(start: startOfAnchorDay, end: end)
        case .threeDays:
            let end = calendar.date(byAdding: .day, value: 3, to: startOfAnchorDay)!
            return DateInterval(start: startOfAnchorDay, end: end)
        case .week:
            return calendar.dateInterval(of: .weekOfYear, for: anchor)!
        }
    }

    public static func movedAnchor(
        _ anchor: Date,
        direction: CalendarRangeNavigationDirection,
        range: CalendarRangeSelection,
        calendar: Calendar
    ) -> Date {
        let multiplier = direction == .next ? 1 : -1
        let component: Calendar.Component
        let amount: Int

        switch range {
        case .today:
            component = .day
            amount = 1
        case .threeDays:
            component = .day
            amount = 3
        case .week:
            component = .weekOfYear
            amount = 1
        }

        return calendar.date(byAdding: component, value: multiplier * amount, to: anchor) ?? anchor
    }
}
