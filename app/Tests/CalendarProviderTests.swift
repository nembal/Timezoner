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

private func expectTrueCalendar(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected true, got false")
    }
}

/// Exercises the value-only handoff that EventKit performs before snapshot construction.
private func snapshotFromParticipantValues(
    id: String,
    title: String,
    organizer: CalendarEventParticipantParticipation?,
    attendees: [CalendarEventParticipantParticipation]
) -> CalendarEventSnapshot? {
    let start = Date(timeIntervalSince1970: 1_726_000_123.25)
    return CalendarEventSnapshotMapper.snapshot(from: CalendarEventMappingInput(
        calendarItemIdentifier: id,
        calendarID: "work",
        calendarTitle: "Work",
        title: title,
        startDate: start,
        endDate: start.addingTimeInterval(60 * 60),
        isAllDay: false,
        attendees: [],
        availability: .busy,
        currentAccountParticipationStatus: CalendarCurrentAccountParticipationMapper.status(
            organizer: organizer,
            attendees: attendees
        ),
        isCancelled: false
    ))
}

func runCalendarProviderTests() {
    print("Running CalendarProviderTests...")

    let start = Date(timeIntervalSince1970: 1_726_000_123.25)
    let end = Date(timeIntervalSince1970: 1_726_003_723.25)

    // The transparent floating panel requires every probe view to provide its own readable surface.
    let probeSurface = CalendarPermissionProbeSurfaceStyle.standard
    expectEqualCalendar(probeSurface.fillOpacity, 1, "calendar permission probe surface is opaque")
    expectTrueCalendar(probeSurface.cornerRadius > 0, "calendar permission probe surface is rounded")
    expectEqualCalendar(
        CalendarPermissionRecoveryPlan.actions,
        [.hideProbe, .openCalendarPrivacySettings],
        "calendar recovery hides the floating probe before opening privacy settings"
    )

    // Normalization prevents unusual source color-space components from leaking to views.
    let color = CalendarColor(red: -0.1, green: 0.25, blue: 1.2, alpha: 1.5)
    expectEqualCalendar(color, CalendarColor(red: 0, green: 0.25, blue: 1, alpha: 1), "calendar color components are normalized")

    // A calendar owner can be an invitee rather than the organizer. The current account's
    // attendee response must win; a decline from somebody else must never hide the event.
    let currentAccountDeclined = CalendarCurrentAccountParticipationMapper.status(
        organizer: CalendarEventParticipantParticipation(
            isCurrentAccount: false,
            participationStatus: .accepted
        ),
        attendees: [
            CalendarEventParticipantParticipation(
                isCurrentAccount: false,
                participationStatus: .declined
            ),
            CalendarEventParticipantParticipation(
                isCurrentAccount: true,
                participationStatus: .declined
            )
        ]
    )
    expectEqualCalendar(
        currentAccountDeclined,
        .declined,
        "current account attendee decline is selected over another attendee's status"
    )

    let otherAttendeeDeclineStatus = CalendarCurrentAccountParticipationMapper.status(
        organizer: CalendarEventParticipantParticipation(
            isCurrentAccount: true,
            participationStatus: .accepted
        ),
        attendees: [
            CalendarEventParticipantParticipation(
                isCurrentAccount: false,
                participationStatus: .declined
            )
        ]
    )
    expectEqualCalendar(
        otherAttendeeDeclineStatus,
        .accepted,
        "other attendee decline retains the current account owner's participation"
    )

    let currentAccountTentative = CalendarCurrentAccountParticipationMapper.status(
        organizer: CalendarEventParticipantParticipation(
            isCurrentAccount: false,
            participationStatus: .accepted
        ),
        attendees: [
            CalendarEventParticipantParticipation(
                isCurrentAccount: true,
                participationStatus: .tentative
            )
        ]
    )
    expectEqualCalendar(
        currentAccountTentative,
        .tentative,
        "current account attendee tentative is preserved for reduced-opacity rendering"
    )

    let nonOrganizerCurrentAccountDeclined = snapshotFromParticipantValues(
        id: "current-account-declined",
        title: "Current account declined",
        organizer: CalendarEventParticipantParticipation(
            isCurrentAccount: false,
            participationStatus: .accepted
        ),
        attendees: [
            CalendarEventParticipantParticipation(
                isCurrentAccount: false,
                participationStatus: .accepted
            ),
            CalendarEventParticipantParticipation(
                isCurrentAccount: true,
                participationStatus: .declined
            )
        ]
    )
    expectNilCalendar(
        nonOrganizerCurrentAccountDeclined,
        "a declined current-account attendee is omitted from snapshots"
    )

    let differentAttendeeDeclined = snapshotFromParticipantValues(
        id: "other-attendee-declined",
        title: "Other attendee declined",
        organizer: CalendarEventParticipantParticipation(
            isCurrentAccount: false,
            participationStatus: .accepted
        ),
        attendees: [
            CalendarEventParticipantParticipation(
                isCurrentAccount: false,
                participationStatus: .declined
            ),
            CalendarEventParticipantParticipation(
                isCurrentAccount: true,
                participationStatus: .accepted
            )
        ]
    )
    expectEqualCalendar(
        differentAttendeeDeclined?.participationStatus,
        .accepted,
        "another attendee decline retains the accepted current-account snapshot"
    )

    let currentAccountTentativeSnapshot = snapshotFromParticipantValues(
        id: "current-account-tentative",
        title: "Current account tentative",
        organizer: CalendarEventParticipantParticipation(
            isCurrentAccount: false,
            participationStatus: .accepted
        ),
        attendees: [
            CalendarEventParticipantParticipation(
                isCurrentAccount: true,
                participationStatus: .tentative
            )
        ]
    )
    expectEqualCalendar(
        currentAccountTentativeSnapshot?.participationStatus,
        .tentative,
        "a tentative current-account attendee remains in the snapshot"
    )

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
        currentAccountParticipationStatus: .accepted,
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
        currentAccountParticipationStatus: .declined,
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
        currentAccountParticipationStatus: .accepted,
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
        currentAccountParticipationStatus: .accepted,
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
        currentAccountParticipationStatus: .pending,
        isCancelled: false
    ))
    expectEqualCalendar(attendees?.attendeeNames, ["Ada Lovelace", "grace@example.com"], "attendee names prefer display name then email fallback")
    expectEqualCalendar(attendees?.availability, .tentative, "tentative availability remains tentative")
    expectEqualCalendar(attendees?.participationStatus, .pending, "current-account participation status is preserved")
}
