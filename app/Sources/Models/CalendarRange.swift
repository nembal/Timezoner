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

/// Value-only labels for Calendar mode. The visible interval is the source of truth so an
/// anchor anywhere inside a locale-defined week cannot give the header a different week number.
public enum CalendarRangeHeaderPresentation {
    public static func title(
        for range: CalendarRangeSelection,
        interval: DateInterval,
        calendar: Calendar
    ) -> String {
        switch range {
        case .today:
            return "Today"
        case .threeDays:
            return "3 Days"
        case .week:
            return "Week \(calendar.component(.weekOfYear, from: interval.start))"
        }
    }

    /// Formats the final *included* local day rather than DateInterval's exclusive end.
    public static func visibleDateRange(
        for interval: DateInterval,
        calendar: Calendar,
        locale: Locale = .current
    ) -> String {
        guard let inclusiveEnd = calendar.date(byAdding: .day, value: -1, to: interval.end) else {
            return ""
        }

        let startComponents = calendar.dateComponents([.year, .month], from: interval.start)
        let endComponents = calendar.dateComponents([.year, .month], from: inclusiveEnd)

        if startComponents.year == endComponents.year, startComponents.month == endComponents.month {
            return "\(formatted(interval.start, format: "MMM d", calendar: calendar, locale: locale))–\(formatted(inclusiveEnd, format: "d", calendar: calendar, locale: locale))"
        }
        if startComponents.year == endComponents.year {
            return "\(formatted(interval.start, format: "MMM d", calendar: calendar, locale: locale))–\(formatted(inclusiveEnd, format: "MMM d", calendar: calendar, locale: locale))"
        }
        return "\(formatted(interval.start, format: "MMM d, y", calendar: calendar, locale: locale))–\(formatted(inclusiveEnd, format: "MMM d, y", calendar: calendar, locale: locale))"
    }

    private static func formatted(_ date: Date, format: String, calendar: Calendar, locale: Locale) -> String {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = format
        return formatter.string(from: date)
    }
}
