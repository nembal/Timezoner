import Foundation
import TimeZonerLib

private func expectEqualCalendar<T: Equatable>(_ actual: T, _ expected: T, _ label: String, line: Int = #line) {
    if actual == expected {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \(expected), got \(actual)")
    }
}

private func expectNilCalendar<T>(_ value: T?, _ label: String, line: Int = #line) {
    if value == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected nil")
    }
}

func runCalendarProviderTests() {
    print("Running CalendarProviderTests...")

    let start = Date(timeIntervalSince1970: 1_726_000_123.25)
    let end = Date(timeIntervalSince1970: 1_726_003_723.25)

    // Normalization prevents unusual source color-space components from leaking to views.
    let color = CalendarColor(red: -0.1, green: 0.25, blue: 1.2, alpha: 1.5)
    expectEqualCalendar(color, CalendarColor(red: 0, green: 0.25, blue: 1, alpha: 1), "calendar color components are normalized")

    // Missing titles remain useful and occurrence IDs distinguish recurring instances.
    let untitled = CalendarEventSnapshotMapper.snapshot(from: CalendarEventMappingInput(
        calendarItemIdentifier: "recurring-item",
        calendarID: "work",
        calendarTitle: "Work",
        title: "   ",
        startDate: start,
        endDate: end,
        isAllDay: false,
        attendees: [],
        availability: .busy,
        organizerIsCurrentUser: false,
        organizerParticipationStatus: .accepted,
        isCancelled: false
    ))
    expectEqualCalendar(untitled?.title, "Untitled event", "blank event title falls back to Untitled event")
    expectEqualCalendar(untitled?.id, "recurring-item|1726000123.25", "occurrence ID includes the exact start timestamp")

    // Only the current account owner's declined status hides an event.
    let ownerDeclined = CalendarEventSnapshotMapper.snapshot(from: CalendarEventMappingInput(
        calendarItemIdentifier: "owner-declined",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Owner declined",
        startDate: start,
        endDate: end,
        isAllDay: false,
        attendees: [],
        availability: .busy,
        organizerIsCurrentUser: true,
        organizerParticipationStatus: .declined,
        isCancelled: false
    ))
    expectNilCalendar(ownerDeclined, "owner-declined event is omitted")

    let otherAttendeeDeclined = CalendarEventSnapshotMapper.snapshot(from: CalendarEventMappingInput(
        calendarItemIdentifier: "guest-declined",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Guest declined",
        startDate: start,
        endDate: end,
        isAllDay: false,
        attendees: [],
        availability: .busy,
        organizerIsCurrentUser: false,
        organizerParticipationStatus: .declined,
        isCancelled: false
    ))
    expectEqualCalendar(otherAttendeeDeclined?.title, "Guest declined", "another attendee declining does not hide the event")

    let cancelled = CalendarEventSnapshotMapper.snapshot(from: CalendarEventMappingInput(
        calendarItemIdentifier: "cancelled",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Cancelled",
        startDate: start,
        endDate: end,
        isAllDay: false,
        attendees: [],
        availability: .busy,
        organizerIsCurrentUser: false,
        organizerParticipationStatus: .accepted,
        isCancelled: true
    ))
    expectNilCalendar(cancelled, "cancelled event is omitted")

    // EventKit's name may be absent; mapper input supplies a safe email fallback.
    let attendees = CalendarEventSnapshotMapper.snapshot(from: CalendarEventMappingInput(
        calendarItemIdentifier: "attendees",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Attendee names",
        startDate: start,
        endDate: end,
        isAllDay: false,
        attendees: [
            CalendarEventAttendee(displayName: "  Ada Lovelace ", email: "ada@example.com"),
            CalendarEventAttendee(displayName: nil, email: "grace@example.com"),
            CalendarEventAttendee(displayName: "   ", email: nil)
        ],
        availability: .tentative,
        organizerIsCurrentUser: false,
        organizerParticipationStatus: .pending,
        isCancelled: false
    ))
    expectEqualCalendar(attendees?.attendeeNames, ["Ada Lovelace", "grace@example.com"], "attendee names prefer display name then email fallback")
    expectEqualCalendar(attendees?.availability, .tentative, "tentative availability remains tentative")
    expectEqualCalendar(attendees?.participationStatus, .pending, "organizer participation status is preserved")
}
