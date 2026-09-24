import Foundation
import TimeZonerLib

private func expectCalendarRangeEqual<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ label: String,
    line: Int = #line
) {
    if actual == expected {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \(expected), got \(actual)")
    }
}

private func calendarRangeDate(
    _ calendar: Calendar,
    year: Int,
    month: Int,
    day: Int,
    hour: Int = 0,
    minute: Int = 0
) -> Date {
    calendar.date(from: DateComponents(
        calendar: calendar,
        timeZone: calendar.timeZone,
        year: year,
        month: month,
        day: day,
        hour: hour,
        minute: minute
    ))!
}

func runCalendarRangeTests() {
    print("Running CalendarRangeTests...")

    var newYorkCalendar = Calendar(identifier: .gregorian)
    newYorkCalendar.locale = Locale(identifier: "en_US_POSIX")
    newYorkCalendar.timeZone = TimeZone(identifier: "America/New_York")!

    let springForwardAnchor = calendarRangeDate(
        newYorkCalendar,
        year: 2024,
        month: 3,
        day: 10,
        hour: 12
    )
    let springForwardToday = CalendarDateIntervalCalculator.interval(
        for: .today,
        anchor: springForwardAnchor,
        calendar: newYorkCalendar
    )
    expectCalendarRangeEqual(
        springForwardToday.start,
        calendarRangeDate(newYorkCalendar, year: 2024, month: 3, day: 10),
        "today begins at local midnight on the DST spring-forward date"
    )
    expectCalendarRangeEqual(
        springForwardToday.end,
        calendarRangeDate(newYorkCalendar, year: 2024, month: 3, day: 11),
        "today ends at the next local midnight across DST"
    )
    expectCalendarRangeEqual(
        springForwardToday.duration,
        23 * 60 * 60,
        "DST spring-forward today is 23 elapsed hours"
    )

    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.locale = Locale(identifier: "en_US_POSIX")
    utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let threeDayAnchor = calendarRangeDate(utcCalendar, year: 2024, month: 5, day: 15, hour: 16)
    let threeDayInterval = CalendarDateIntervalCalculator.interval(
        for: .threeDays,
        anchor: threeDayAnchor,
        calendar: utcCalendar
    )
    expectCalendarRangeEqual(
        threeDayInterval.start,
        calendarRangeDate(utcCalendar, year: 2024, month: 5, day: 15),
        "three-day range anchors at the current local day"
    )
    expectCalendarRangeEqual(
        threeDayInterval.end,
        calendarRangeDate(utcCalendar, year: 2024, month: 5, day: 18),
        "three-day range includes today and the next two local days"
    )

    var mondayFirstCalendar = utcCalendar
    mondayFirstCalendar.firstWeekday = 2
    let weekAnchor = calendarRangeDate(mondayFirstCalendar, year: 2024, month: 5, day: 15, hour: 16)
    let weekInterval = CalendarDateIntervalCalculator.interval(
        for: .week,
        anchor: weekAnchor,
        calendar: mondayFirstCalendar
    )
    expectCalendarRangeEqual(
        weekInterval.start,
        calendarRangeDate(mondayFirstCalendar, year: 2024, month: 5, day: 13),
        "week honors a Monday first weekday"
    )
    expectCalendarRangeEqual(
        weekInterval.end,
        calendarRangeDate(mondayFirstCalendar, year: 2024, month: 5, day: 20),
        "week ends at the next locale week boundary"
    )

    expectCalendarRangeEqual(
        CalendarDateIntervalCalculator.movedAnchor(
            threeDayAnchor,
            direction: .previous,
            range: .today,
            calendar: utcCalendar
        ),
        calendarRangeDate(utcCalendar, year: 2024, month: 5, day: 14, hour: 16),
        "previous today navigation moves one calendar day"
    )
    expectCalendarRangeEqual(
        CalendarDateIntervalCalculator.movedAnchor(
            threeDayAnchor,
            direction: .next,
            range: .threeDays,
            calendar: utcCalendar
        ),
        calendarRangeDate(utcCalendar, year: 2024, month: 5, day: 18, hour: 16),
        "next three-day navigation moves three calendar days"
    )
    expectCalendarRangeEqual(
        CalendarDateIntervalCalculator.movedAnchor(
            weekAnchor,
            direction: .next,
            range: .week,
            calendar: mondayFirstCalendar
        ),
        calendarRangeDate(mondayFirstCalendar, year: 2024, month: 5, day: 22, hour: 16),
        "next week navigation moves one locale week"
    )
}
