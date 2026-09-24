import Foundation
import TimeZonerLib

private func expectCalendarPresentation<T: Equatable>(
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

private func expectCalendarPresentationTrue(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected true, got false")
    }
}

private func calendarPresentationDate(
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

private func calendarPresentationEvent(
    id: String,
    start: Date,
    end: Date,
    isAllDay: Bool = false
) -> CalendarEventSnapshot {
    CalendarEventSnapshot(
        id: id,
        calendarID: "work",
        calendarTitle: "Work",
        title: id,
        startDate: start,
        endDate: end,
        isAllDay: isAllDay,
        attendeeNames: [],
        availability: .busy,
        participationStatus: .accepted
    )
}

func runCalendarPresentationStateTests() {
    print("Running CalendarPresentationStateTests...")

    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    calendar.firstWeekday = 2

    let now = calendarPresentationDate(calendar, year: 2024, month: 5, day: 15, hour: 10)
    let nextDay = calendarPresentationDate(calendar, year: 2024, month: 5, day: 16, hour: 10)
    let suiteName = "CalendarPresentationStateTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    expectCalendarPresentation(
        CalendarAgendaWingRequest.outcome(requested: false, authorizationStatus: .fullAccess),
        .hide,
        "turning the agenda off always hides it immediately"
    )
    expectCalendarPresentation(
        CalendarAgendaWingRequest.outcome(requested: true, authorizationStatus: .fullAccess),
        .show,
        "full calendar access may show the agenda"
    )
    expectCalendarPresentation(
        CalendarAgendaWingRequest.outcome(requested: true, authorizationStatus: .notDetermined),
        .explainAccess,
        "an undetermined calendar permission explains access without persisting the agenda"
    )
    for status in [CalendarAuthorizationStatus.denied, .restricted, .writeOnly] {
        expectCalendarPresentation(
            CalendarAgendaWingRequest.outcome(requested: true, authorizationStatus: status),
            .recoverAccess,
            "unavailable calendar access keeps the agenda hidden and routes recovery"
        )
    }

    let presentation = CalendarPresentationState(defaults: defaults)
    let timeState = TimeState()
    timeState.referenceDate = now
    timeState.sourceZoneId = TimeZone(secondsFromGMT: 0)!.identifier
    timeState.isLive = false
    let referenceMoment = ReferenceMomentController(timeState: timeState, presentation: presentation)

    presentation.enterCalendar(now: now, calendar: calendar)
    expectCalendarPresentation(presentation.destination, .calendar, "expand switches the root surface to calendar mode")
    expectCalendarPresentation(presentation.range, .week, "first calendar entry uses the week range")
    expectCalendarPresentation(
        presentation.activeInterval(calendar: calendar).start,
        calendarPresentationDate(calendar, year: 2024, month: 5, day: 13),
        "week entry derives the locale week interval"
    )

    presentation.setRange(.threeDays)
    presentation.move(.next, calendar: calendar)
    expectCalendarPresentation(
        presentation.anchor,
        calendarPresentationDate(calendar, year: 2024, month: 5, day: 18),
        "next three-day navigation moves the anchor by exactly three local days"
    )
    presentation.move(.previous, calendar: calendar)
    expectCalendarPresentation(
        presentation.anchor,
        calendarPresentationDate(calendar, year: 2024, month: 5, day: 15),
        "previous three-day navigation restores the prior anchor"
    )

    presentation.setRange(.today)
    presentation.move(.previous, calendar: calendar)
    expectCalendarPresentation(
        presentation.anchor,
        calendarPresentationDate(calendar, year: 2024, month: 5, day: 14),
        "previous today navigation moves exactly one local day"
    )

    presentation.setRange(.week)
    presentation.move(.next, calendar: calendar)
    expectCalendarPresentation(
        presentation.anchor,
        calendarPresentationDate(calendar, year: 2024, month: 5, day: 21),
        "next week navigation moves by one locale week"
    )

    let referenceBeforeToday = timeState.referenceDate
    presentation.goToday(now: nextDay, calendar: calendar)
    expectCalendarPresentation(
        presentation.anchor,
        calendarPresentationDate(calendar, year: 2024, month: 5, day: 16),
        "Today replaces the calendar anchor with the current local day"
    )
    expectCalendarPresentation(
        timeState.referenceDate,
        referenceBeforeToday,
        "Today does not change TimeZoner's reference moment"
    )

    presentation.setRange(.threeDays)
    presentation.returnToTimeZoner()
    presentation.enterCalendar(now: nextDay, calendar: calendar)
    expectCalendarPresentation(presentation.range, .threeDays, "later calendar entry remembers the session range")

    let selected = calendarPresentationEvent(
        id: "event",
        start: calendarPresentationDate(calendar, year: 2024, month: 5, day: 16, hour: 14),
        end: calendarPresentationDate(calendar, year: 2024, month: 5, day: 16, hour: 15)
    )
    referenceMoment.selectEvent(selected, sourceZone: .current)
    presentation.returnToTimeZoner()
    expectCalendarPresentation(presentation.destination, .timezoner, "timed-event selection returns to TimeZoner")
    expectCalendarPresentation(timeState.referenceDate, selected.startDate, "timed-event selection sets the shared reference moment")

    let normalFrame = CGRect(x: 120, y: 230, width: 520, height: 410)
    let visibleFrame = CGRect(x: 0, y: 0, width: 1_000, height: 800)
    let calendarFrame = CalendarPanelFrameCalculator.calendarFrame(
        normalFrame: normalFrame,
        visibleFrame: visibleFrame
    )
    expectCalendarPresentation(calendarFrame.size, CGSize(width: 760, height: 560), "calendar mode targets 760 by 560 points")
    expectCalendarPresentation(
        CalendarPanelFrameCalculator.restoredNormalFrame(normalFrame, visibleFrame: visibleFrame),
        normalFrame,
        "returning to TimeZoner restores an in-bounds normal frame exactly"
    )

    let offscreenNormalFrame = CGRect(x: -160, y: 760, width: 520, height: 410)
    expectCalendarPresentation(
        CalendarPanelFrameCalculator.restoredNormalFrame(
            offscreenNormalFrame,
            visibleFrame: visibleFrame,
            screenDidChange: false
        ),
        offscreenNormalFrame,
        "same-screen return restores the saved normal frame exactly without recentering"
    )
    let changedVisibleFrame = CGRect(x: 100, y: 100, width: 600, height: 400)
    let changedScreenFrame = CalendarPanelFrameCalculator.restoredNormalFrame(
        offscreenNormalFrame,
        visibleFrame: changedVisibleFrame,
        screenDidChange: true
    )
    expectCalendarPresentationTrue(
        changedVisibleFrame.contains(changedScreenFrame),
        "changed-screen return reclamps an out-of-bounds saved normal frame"
    )

    let crampedVisibleFrame = CGRect(x: 100, y: 100, width: 600, height: 400)
    let clampedCalendarFrame = CalendarPanelFrameCalculator.calendarFrame(
        normalFrame: normalFrame,
        visibleFrame: crampedVisibleFrame
    )
    expectCalendarPresentation(clampedCalendarFrame.size, crampedVisibleFrame.size, "calendar frame clamps to the visible screen size")
    expectCalendarPresentationTrue(
        crampedVisibleFrame.contains(clampedCalendarFrame),
        "calendar frame remains inside the visible screen after clamping"
    )

    var newYorkCalendar = Calendar(identifier: .gregorian)
    newYorkCalendar.locale = Locale(identifier: "en_US_POSIX")
    newYorkCalendar.timeZone = TimeZone(identifier: "America/New_York")!
    let springForwardDay = calendarPresentationDate(newYorkCalendar, year: 2024, month: 3, day: 10)
    let springForwardInterval = DateInterval(
        start: springForwardDay,
        end: newYorkCalendar.date(byAdding: .day, value: 1, to: springForwardDay)!
    )
    let dayStarts = CalendarGridMetrics.dayStarts(in: springForwardInterval, calendar: newYorkCalendar)
    expectCalendarPresentation(dayStarts, [springForwardDay], "grid derives local day starts from Calendar rather than elapsed seconds")

    let springForwardThreeThirty = calendarPresentationDate(
        newYorkCalendar,
        year: 2024,
        month: 3,
        day: 10,
        hour: 3,
        minute: 30
    )
    expectCalendarPresentation(
        CalendarGridMetrics.wallMinute(
            for: springForwardThreeThirty,
            on: springForwardDay,
            calendar: newYorkCalendar
        ),
        210,
        "grid uses local wall-clock components after the missing DST hour"
    )
    expectCalendarPresentation(
        CalendarGridMetrics.wallMinute(
            for: springForwardInterval.end,
            on: springForwardDay,
            calendar: newYorkCalendar,
            isEnd: true
        ),
        1_440,
        "a segment ending at the next local midnight reaches the bottom of the ruler"
    )
    let posixLocale = Locale(identifier: "en_US_POSIX")
    expectCalendarPresentation(
        [1, 2, 3].map { CalendarGridMetrics.rulerHourLabel(for: $0, locale: posixLocale) },
        ["1 AM", "2 AM", "3 AM"],
        "spring-forward ruler keeps the logical missing 2 AM label between its neighbors"
    )
    expectCalendarPresentation(
        [0, 1, 2, 3].map { CalendarGridMetrics.rulerHourLabel(for: $0, locale: posixLocale) },
        ["12 AM", "1 AM", "2 AM", "3 AM"],
        "fall-back ruler labels each logical hour once without formatting repeated dates"
    )

    let firstGridDay = calendarPresentationDate(calendar, year: 2024, month: 5, day: 15)
    let secondGridDay = calendarPresentationDate(calendar, year: 2024, month: 5, day: 16)
    let thirdGridDay = calendarPresentationDate(calendar, year: 2024, month: 5, day: 17)
    let gridEvent = calendarPresentationEvent(
        id: "overlap",
        start: calendarPresentationDate(calendar, year: 2024, month: 5, day: 15, hour: 9),
        end: calendarPresentationDate(calendar, year: 2024, month: 5, day: 15, hour: 11)
    )
    let segment = CalendarTimedSegment(
        id: "overlap|day",
        occurrenceID: gridEvent.id,
        event: gridEvent,
        dayStart: firstGridDay,
        startDate: gridEvent.startDate,
        endDate: gridEvent.endDate,
        laneIndex: 1,
        laneCount: 2
    )
    let timedFrame = CalendarGridMetrics.timedFrame(
        for: segment,
        dayStarts: [firstGridDay, secondGridDay],
        totalWidth: 248,
        calendar: calendar
    )
    expectCalendarPresentation(timedFrame?.x, 98, "overlap lanes split the usable day column width")
    expectCalendarPresentation(timedFrame?.y, 468, "timed event y placement follows local wall-clock minutes")
    expectCalendarPresentation(timedFrame?.width, 44, "overlap lane width reserves the lane gap")
    expectCalendarPresentation(timedFrame?.height, 104, "timed event height uses the wall-clock duration")

    let multiDay = CalendarAllDaySpan(
        id: "multi",
        occurrenceID: "multi",
        event: calendarPresentationEvent(id: "multi", start: firstGridDay, end: thirdGridDay, isAllDay: true),
        startDay: firstGridDay,
        endDay: thirdGridDay,
        dayCount: 2
    )
    let overlappingAllDay = CalendarAllDaySpan(
        id: "overlap-all-day",
        occurrenceID: "overlap-all-day",
        event: calendarPresentationEvent(id: "overlap-all-day", start: secondGridDay, end: thirdGridDay, isAllDay: true),
        startDay: secondGridDay,
        endDay: thirdGridDay,
        dayCount: 1
    )
    let allDayPlacements = CalendarGridMetrics.allDayPlacements(for: [multiDay, overlappingAllDay])
    expectCalendarPresentation(allDayPlacements.map(\.row), [0, 1], "overlapping all-day spans stack in deterministic separate rows")

    let currentTime = CalendarGridMetrics.currentTimePosition(
        now: calendarPresentationDate(calendar, year: 2024, month: 5, day: 16, hour: 13, minute: 30),
        dayStarts: [firstGridDay, secondGridDay],
        calendar: calendar
    )
    expectCalendarPresentation(currentTime?.dayIndex, 1, "current-time marker appears in the matching visible day column")
    expectCalendarPresentation(currentTime?.y, 702, "current-time marker uses local wall-clock geometry")

    let muted = CalendarGridColor.displayColor(
        from: CalendarColor(red: 1, green: 0, blue: 0, alpha: 1)
    )
    expectCalendarPresentationTrue(
        abs(muted.green - 0.45) < 0.000_001,
        "calendar colors clamp saturation before rendering"
    )
    expectCalendarPresentation(CalendarGridColor.fillOpacity, 0.10, "calendar fill uses the quiet ten-percent opacity")
    expectCalendarPresentation(CalendarGridColor.leadingIndicatorWidth, 2, "calendar marker keeps a two-point leading indicator")
}
