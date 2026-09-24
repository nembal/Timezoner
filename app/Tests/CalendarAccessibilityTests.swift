import Foundation
import TimeZonerLib

private func expectCalendarAccessibility<T: Equatable>(
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

private func expectCalendarAccessibilityTrue(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected true, got false")
    }
}

func runCalendarAccessibilityTests() {
    print("Running CalendarAccessibilityTests...")

    let workCalendar = CalendarDescriptor(
        id: "work",
        title: "Work",
        sourceTitle: "Google",
        color: CalendarColor(red: 0.1, green: 0.2, blue: 0.3, alpha: 1)
    )
    expectCalendarAccessibility(
        CalendarAccessibilityLabels.showCalendar(for: workCalendar),
        "Show Work, Google calendar",
        "the show checkbox names both the calendar and account source"
    )
    expectCalendarAccessibility(
        CalendarAccessibilityLabels.alertsCalendar(for: workCalendar),
        "Calendar alerts for Work, Google",
        "the alerts checkbox names both the calendar and account source"
    )

    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let day = calendar.date(from: DateComponents(year: 2024, month: 5, day: 15))!
    let dayStarts = (0 ..< 7).map { calendar.date(byAdding: .day, value: $0, to: day)! }
    let event = CalendarEventSnapshot(
        id: "four-way-overlap",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Design review",
        startDate: calendar.date(byAdding: .hour, value: 9, to: day)!,
        endDate: calendar.date(byAdding: .hour, value: 10, to: day)!,
        isAllDay: false,
        attendeeNames: [],
        availability: .busy,
        participationStatus: .accepted
    )
    let tentativeResponseEvent = CalendarEventSnapshot(
        id: "tentative-response",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Tentative design review",
        startDate: event.startDate,
        endDate: event.endDate,
        isAllDay: false,
        attendeeNames: [],
        availability: .busy,
        participationStatus: .tentative
    )
    let tentativeAvailabilityEvent = CalendarEventSnapshot(
        id: "tentative-availability",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Tentative availability",
        startDate: event.startDate,
        endDate: event.endDate,
        isAllDay: false,
        attendeeNames: [],
        availability: .tentative,
        participationStatus: .accepted
    )
    expectCalendarAccessibility(
        CalendarEventPresentationStyle.opacity(for: tentativeResponseEvent),
        0.6,
        "a tentative current-account response uses reduced event opacity"
    )
    expectCalendarAccessibility(
        CalendarEventPresentationStyle.opacity(for: tentativeAvailabilityEvent),
        0.6,
        "tentative availability uses the same reduced opacity in agenda and grid"
    )
    expectCalendarAccessibility(
        CalendarEventPresentationStyle.opacity(for: event),
        1,
        "a non-tentative response keeps full event opacity"
    )
    let segments = (0 ..< 4).map { laneIndex in
        CalendarTimedSegment(
            id: "four-way-overlap|\(laneIndex)",
            occurrenceID: "\(event.id)|\(laneIndex)",
            event: event,
            dayStart: day,
            startDate: event.startDate,
            endDate: event.endDate,
            laneIndex: laneIndex,
            laneCount: 4,
            overlapGroupID: "four-way-overlap|group"
        )
    }
    let groups = CalendarGridMetrics.overlapGroups(from: segments)
    expectCalendarAccessibility(groups.count, 1, "four simultaneous events stay in one presentation group")
    expectCalendarAccessibilityTrue(
        groups.first?.usesOverflowMenu == true,
        "four simultaneous events use the accessible overflow menu rather than narrow lanes"
    )
    let frame = CalendarGridMetrics.overlapSummaryFrame(
        for: groups[0],
        dayStarts: dayStarts,
        totalWidth: 760,
        calendar: calendar
    )
    expectCalendarAccessibilityTrue(
        (frame?.width ?? 0) >= CalendarGridMetrics.minimumInteractiveEventWidth
            && (frame?.height ?? 0) >= CalendarGridMetrics.minimumInteractiveEventHeight,
        "the overlap menu retains the minimum interactive geometry"
    )
}
