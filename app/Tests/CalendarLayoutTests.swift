import Foundation
import TimeZonerLib

private func expectCalendarLayoutEqual<T: Equatable>(
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

private func calendarLayoutDate(
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

private func calendarLayoutEvent(
    id: String,
    startDate: Date,
    endDate: Date,
    isAllDay: Bool = false
) -> CalendarEventSnapshot {
    CalendarEventSnapshot(
        id: id,
        calendarID: "work",
        calendarTitle: "Work",
        title: id,
        startDate: startDate,
        endDate: endDate,
        isAllDay: isAllDay,
        attendeeNames: [],
        availability: .busy,
        participationStatus: .accepted
    )
}

func runCalendarLayoutTests() {
    print("Running CalendarLayoutTests...")

    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!

    let firstDay = calendarLayoutDate(calendar, year: 2024, month: 5, day: 15)
    let secondDay = calendarLayoutDate(calendar, year: 2024, month: 5, day: 16)
    let thirdDay = calendarLayoutDate(calendar, year: 2024, month: 5, day: 17)
    let twoDayInterval = DateInterval(start: firstDay, end: thirdDay)

    let overlappingSegments = CalendarLayoutEngine.timedSegments(
        events: [
            calendarLayoutEvent(
                id: "event-b",
                startDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 15, hour: 10),
                endDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 15, hour: 12)
            ),
            calendarLayoutEvent(
                id: "event-a",
                startDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 15, hour: 9),
                endDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 15, hour: 11)
            )
        ],
        interval: twoDayInterval,
        calendar: calendar
    )
    expectCalendarLayoutEqual(
        overlappingSegments.map(\.occurrenceID),
        ["event-a", "event-b"],
        "timed segments sort by start date before occurrence ID"
    )
    expectCalendarLayoutEqual(
        overlappingSegments.map(\.laneIndex),
        [0, 1],
        "overlapping timed events receive separate lanes"
    )
    expectCalendarLayoutEqual(
        overlappingSegments.map(\.laneCount),
        [2, 2],
        "every event in an overlap group reports the group lane count"
    )

    let touchingSegments = CalendarLayoutEngine.timedSegments(
        events: [
            calendarLayoutEvent(
                id: "first",
                startDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 15, hour: 9),
                endDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 15, hour: 10)
            ),
            calendarLayoutEvent(
                id: "second",
                startDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 15, hour: 10),
                endDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 15, hour: 11)
            )
        ],
        interval: twoDayInterval,
        calendar: calendar
    )
    expectCalendarLayoutEqual(
        touchingSegments.map(\.laneIndex),
        [0, 0],
        "events touching at a half-open boundary reuse the first lane"
    )
    expectCalendarLayoutEqual(
        touchingSegments.map(\.laneCount),
        [1, 1],
        "events touching at a half-open boundary do not overlap"
    )

    let crossMidnightSegments = CalendarLayoutEngine.timedSegments(
        events: [
            calendarLayoutEvent(
                id: "overnight-occurrence",
                startDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 15, hour: 23),
                endDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 16, hour: 2)
            )
        ],
        interval: twoDayInterval,
        calendar: calendar
    )
    expectCalendarLayoutEqual(crossMidnightSegments.count, 2, "cross-midnight event splits into one segment per local day")
    expectCalendarLayoutEqual(
        crossMidnightSegments.map(\.occurrenceID),
        ["overnight-occurrence", "overnight-occurrence"],
        "cross-midnight segments retain the original occurrence ID"
    )
    expectCalendarLayoutEqual(
        crossMidnightSegments.map(\.startDate),
        [
            calendarLayoutDate(calendar, year: 2024, month: 5, day: 15, hour: 23),
            secondDay
        ],
        "cross-midnight segments begin at the event then the next local midnight"
    )
    expectCalendarLayoutEqual(
        crossMidnightSegments.map(\.endDate),
        [
            secondDay,
            calendarLayoutDate(calendar, year: 2024, month: 5, day: 16, hour: 2)
        ],
        "cross-midnight segments end at the local boundary then the event end"
    )

    let allDaySpans = CalendarLayoutEngine.allDaySpans(
        events: [
            calendarLayoutEvent(
                id: "multi-day-all-day",
                startDate: firstDay,
                endDate: calendarLayoutDate(calendar, year: 2024, month: 5, day: 18),
                isAllDay: true
            )
        ],
        interval: DateInterval(start: secondDay, end: calendarLayoutDate(calendar, year: 2024, month: 5, day: 19)),
        calendar: calendar
    )
    expectCalendarLayoutEqual(allDaySpans.count, 1, "intersecting multi-day all-day event produces one span")
    expectCalendarLayoutEqual(allDaySpans.first?.occurrenceID, "multi-day-all-day", "all-day span carries the occurrence ID")
    expectCalendarLayoutEqual(allDaySpans.first?.startDay, secondDay, "all-day span clips to the visible first day")
    expectCalendarLayoutEqual(
        allDaySpans.first?.endDay,
        calendarLayoutDate(calendar, year: 2024, month: 5, day: 18),
        "all-day span retains its exclusive end day"
    )
    expectCalendarLayoutEqual(allDaySpans.first?.dayCount, 2, "all-day span covers each visible affected day")
}
