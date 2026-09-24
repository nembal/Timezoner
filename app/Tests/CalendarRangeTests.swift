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

    var isoLikeCalendar = utcCalendar
    isoLikeCalendar.firstWeekday = 2
    isoLikeCalendar.minimumDaysInFirstWeek = 4
    let yearBoundaryAnchor = calendarRangeDate(isoLikeCalendar, year: 2021, month: 1, day: 3, hour: 12)
    let yearBoundaryWeek = CalendarDateIntervalCalculator.interval(
        for: .week,
        anchor: yearBoundaryAnchor,
        calendar: isoLikeCalendar
    )
    expectCalendarRangeEqual(
        CalendarRangeHeaderPresentation.title(
            for: .week,
            interval: yearBoundaryWeek,
            currentDate: yearBoundaryAnchor,
            calendar: isoLikeCalendar
        ),
        "Week 53",
        "week headers use the injected calendar week number at a calendar-year boundary"
    )

    var sundayFirstCalendar = utcCalendar
    sundayFirstCalendar.firstWeekday = 1
    sundayFirstCalendar.minimumDaysInFirstWeek = 1
    let sundayFirstWeek = CalendarDateIntervalCalculator.interval(
        for: .week,
        anchor: yearBoundaryAnchor,
        calendar: sundayFirstCalendar
    )
    expectCalendarRangeEqual(
        CalendarRangeHeaderPresentation.title(
            for: .week,
            interval: sundayFirstWeek,
            currentDate: yearBoundaryAnchor,
            calendar: sundayFirstCalendar
        ),
        "Week 2",
        "week headers honor a Sunday-first injected calendar instead of hard-coded ISO weeks"
    )

    expectCalendarRangeEqual(
        CalendarRangeHeaderPresentation.visibleDateRange(
            for: weekInterval,
            calendar: mondayFirstCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        ),
        "May 13–19",
        "visible date ranges use the inclusive final day rather than the interval's exclusive endpoint"
    )
    expectCalendarRangeEqual(
        CalendarRangeHeaderPresentation.visibleDateRange(
            for: CalendarDateIntervalCalculator.interval(
                for: .today,
                anchor: threeDayAnchor,
                calendar: utcCalendar
            ),
            calendar: utcCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        ),
        "May 15",
        "a single visible day formats once rather than repeating its endpoint"
    )
    expectCalendarRangeEqual(
        CalendarRangeHeaderPresentation.title(
            for: .today,
            interval: CalendarDateIntervalCalculator.interval(
                for: .today,
                anchor: threeDayAnchor,
                calendar: utcCalendar
            ),
            currentDate: threeDayAnchor,
            calendar: utcCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        ),
        "Today",
        "the current single-day interval identifies itself as Today"
    )
    expectCalendarRangeEqual(
        CalendarRangeHeaderPresentation.title(
            for: .today,
            interval: CalendarDateIntervalCalculator.interval(
                for: .today,
                anchor: calendarRangeDate(utcCalendar, year: 2024, month: 5, day: 14, hour: 16),
                calendar: utcCalendar
            ),
            currentDate: threeDayAnchor,
            calendar: utcCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        ),
        "May 14",
        "the previous single-day interval identifies its displayed local date instead of Today"
    )
    expectCalendarRangeEqual(
        CalendarRangeHeaderPresentation.title(
            for: .today,
            interval: CalendarDateIntervalCalculator.interval(
                for: .today,
                anchor: calendarRangeDate(utcCalendar, year: 2024, month: 5, day: 16, hour: 16),
                calendar: utcCalendar
            ),
            currentDate: threeDayAnchor,
            calendar: utcCalendar,
            locale: Locale(identifier: "en_US_POSIX")
        ),
        "May 16",
        "the next single-day interval identifies its displayed local date instead of Today"
    )
    expectCalendarRangeEqual(
        CalendarRangeHeaderPresentation.title(
            for: .threeDays,
            interval: threeDayInterval,
            currentDate: threeDayAnchor,
            calendar: utcCalendar
        ),
        "3 Days",
        "three-day navigation does not present itself as a week"
    )
    expectCalendarRangeEqual(
        [
            CalendarNavigationIconControl.openWeek.systemImageName,
            CalendarNavigationIconControl.openWeek.accessibilityLabel,
            CalendarNavigationIconControl.openWeek.helpText,
            CalendarNavigationIconControl.openWeek.accessibilityHint
        ],
        ["calendar", "Open week", "Open week", "Shows your calendar week."],
        "the compact Open week control keeps its calendar icon and accessible presentation"
    )
    expectCalendarRangeEqual(
        [
            CalendarNavigationIconControl.backToTimeZoner.systemImageName,
            CalendarNavigationIconControl.backToTimeZoner.accessibilityLabel,
            CalendarNavigationIconControl.backToTimeZoner.helpText,
            CalendarNavigationIconControl.backToTimeZoner.accessibilityHint
        ],
        ["chevron.left", "Back to TimeZoner", "Back to TimeZoner", "Returns to the TimeZoner view."],
        "the compact return control keeps its chevron icon and accessible presentation"
    )

    let springForwardWeek = CalendarDateIntervalCalculator.interval(
        for: .week,
        anchor: springForwardAnchor,
        calendar: newYorkCalendar
    )
    expectCalendarRangeEqual(
        springForwardWeek.duration,
        167 * 60 * 60,
        "a spring-forward week remains local-midnight based rather than assuming seven 24-hour days"
    )
    let movedSpringForwardWeek = CalendarDateIntervalCalculator.movedAnchor(
        CalendarDateIntervalCalculator.movedAnchor(
            springForwardAnchor,
            direction: .next,
            range: .week,
            calendar: newYorkCalendar
        ),
        direction: .previous,
        range: .week,
        calendar: newYorkCalendar
    )
    expectCalendarRangeEqual(
        movedSpringForwardWeek,
        springForwardAnchor,
        "week navigation restores the original local date and time across a DST transition"
    )
}
