import Foundation
import TimeZonerLib

private func expectAgendaPresentation(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label)")
    }
}

private func agendaPresentationDate(
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

private func agendaPresentationEvent(
    id: String,
    start: Date,
    end: Date,
    isAllDay: Bool = false,
    attendeeNames: [String] = []
) -> CalendarEventSnapshot {
    CalendarEventSnapshot(
        id: id,
        calendarID: "work",
        calendarTitle: "Work",
        title: id,
        startDate: start,
        endDate: end,
        isAllDay: isAllDay,
        attendeeNames: attendeeNames,
        availability: .busy,
        participationStatus: .accepted
    )
}

func runAgendaPresentationTests() {
    print("Running AgendaPresentationTests...")

    expectAgendaPresentation(
        AgendaContentState.resolve(events: [], isLoading: false, errorMessage: "Calendar fetch failed")
            == .errorWithoutEvents("Calendar fetch failed"),
        "an empty failed fetch has an error state rather than a clear-day state"
    )
    expectAgendaPresentation(
        AgendaContentState.resolve(events: [], isLoading: true, errorMessage: nil) == .loading,
        "an empty in-flight fetch remains loading"
    )
    expectAgendaPresentation(
        AgendaContentState.resolve(events: [], isLoading: false, errorMessage: nil) == .agenda,
        "an empty successful fetch can show the clear-day state"
    )

    var newYork = Calendar(identifier: .gregorian)
    newYork.locale = Locale(identifier: "en_US_POSIX")
    newYork.timeZone = TimeZone(identifier: "America/New_York")!
    let start = newYork.date(from: DateComponents(
        calendar: newYork,
        timeZone: newYork.timeZone,
        year: 2024,
        month: 5,
        day: 15,
        hour: 9
    ))!
    let event = CalendarEventSnapshot(
        id: "agenda-row",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Review",
        startDate: start,
        endDate: start.addingTimeInterval(90 * 60),
        isAllDay: false,
        attendeeNames: [],
        availability: .busy,
        participationStatus: .accepted
    )
    let timedDetails = AgendaTimedEventPresentation(event: event, timeZone: newYork.timeZone, locale: newYork.locale!)
    expectAgendaPresentation(
        timedDetails.timeRange == "9:00 AM – 10:30 AM EDT",
        "timed agenda rows expose local start, end, and timezone abbreviation"
    )
    expectAgendaPresentation(
        timedDetails.calendarTitle == "Work",
        "timed agenda rows retain the event calendar title"
    )
    expectAgendaPresentation(
        timedDetails.metadata == "9:00 AM – 10:30 AM EDT · Work",
        "timed agenda rows combine the time range and calendar into compact metadata"
    )

    let now = agendaPresentationDate(newYork, year: 2024, month: 5, day: 15, hour: 12)
    let agendaSnapshot = CalendarDateIntervalCalculator.interval(
        for: .threeDays,
        anchor: now,
        calendar: newYork
    )
    let allDayToday = agendaPresentationEvent(
        id: "all-day-today",
        start: agendaPresentationDate(newYork, year: 2024, month: 5, day: 15),
        end: agendaPresentationDate(newYork, year: 2024, month: 5, day: 16),
        isAllDay: true
    )
    let earlierToday = agendaPresentationEvent(
        id: "earlier-today",
        start: agendaPresentationDate(newYork, year: 2024, month: 5, day: 15, hour: 9),
        end: agendaPresentationDate(newYork, year: 2024, month: 5, day: 15, hour: 10)
    )
    let laterToday = agendaPresentationEvent(
        id: "later-today",
        start: agendaPresentationDate(newYork, year: 2024, month: 5, day: 15, hour: 15),
        end: agendaPresentationDate(newYork, year: 2024, month: 5, day: 15, hour: 16)
    )
    let tomorrowMorning = agendaPresentationEvent(
        id: "tomorrow-morning",
        start: agendaPresentationDate(newYork, year: 2024, month: 5, day: 16, hour: 9),
        end: agendaPresentationDate(newYork, year: 2024, month: 5, day: 16, hour: 10)
    )
    let sections = AgendaDayPresentation.sections(
        events: [tomorrowMorning, laterToday, allDayToday, earlierToday],
        now: now,
        calendar: newYork,
        snapshotInterval: agendaSnapshot,
        isLoading: false
    )
    let todaySection = sections.first { $0.day == .today }
    let tomorrowSection = sections.first { $0.day == .tomorrow }
    expectAgendaPresentation(
        todaySection?.allDayEvents.map(\.id) == ["all-day-today"]
            && todaySection?.earlierTimedEvents.map(\.id) == ["earlier-today"]
            && todaySection?.timedEvents.map(\.id) == ["later-today"],
        "Today keeps all-day rows first and isolates earlier timed rows for the existing disclosure"
    )
    expectAgendaPresentation(
        tomorrowSection?.allDayEvents.isEmpty == true
            && tomorrowSection?.earlierTimedEvents.isEmpty == true
            && tomorrowSection?.timedEvents.map(\.id) == ["tomorrow-morning"],
        "Tomorrow is a complete independent section and is never split into earlier and remaining events"
    )

    let tomorrowOnlySections = AgendaDayPresentation.sections(
        events: [tomorrowMorning],
        now: now,
        calendar: newYork,
        snapshotInterval: agendaSnapshot,
        isLoading: false
    )
    expectAgendaPresentation(
        tomorrowOnlySections.first { $0.day == .today }?.isEmpty == true
            && tomorrowOnlySections.first { $0.day == .today }?.emptyMessage == "Nothing scheduled today",
        "an empty Today section remains intentional when Tomorrow has events"
    )
    expectAgendaPresentation(
        tomorrowOnlySections.first { $0.day == .tomorrow }?.isEmpty == false,
        "a populated Tomorrow section remains visible when Today is empty"
    )
    let bothEmptySections = AgendaDayPresentation.sections(
        events: [],
        now: now,
        calendar: newYork,
        snapshotInterval: agendaSnapshot,
        isLoading: false
    )
    expectAgendaPresentation(
        bothEmptySections.map(\.emptyMessage) == ["Nothing scheduled today", "Nothing scheduled tomorrow"],
        "each agenda day owns an explicit empty state"
    )
    expectAgendaPresentation(
        bothEmptySections.allSatisfy { $0.coverage == .covered && $0.isEmpty },
        "covered empty agenda days retain their intentional clear-day state"
    )

    let todayOnlySnapshot = CalendarDateIntervalCalculator.interval(
        for: .today,
        anchor: now,
        calendar: newYork
    )
    let transitioningSections = AgendaDayPresentation.sections(
        events: [laterToday],
        now: now,
        calendar: newYork,
        snapshotInterval: todayOnlySnapshot,
        isLoading: true
    )
    expectAgendaPresentation(
        transitioningSections.first { $0.day == .today }?.coverage == .covered
            && transitioningSections.first { $0.day == .tomorrow }?.coverage == .loading
            && transitioningSections.first { $0.day == .tomorrow }?.isEmpty == false,
        "a retained Today-only snapshot keeps Tomorrow loading instead of claiming it is empty"
    )
    let failedWiderRefreshSections = AgendaDayPresentation.sections(
        events: [laterToday],
        now: now,
        calendar: newYork,
        snapshotInterval: todayOnlySnapshot,
        isLoading: false
    )
    expectAgendaPresentation(
        failedWiderRefreshSections.first { $0.day == .tomorrow }?.coverage == .unavailable
            && failedWiderRefreshSections.first { $0.day == .tomorrow }?.isEmpty == false,
        "a failed wider refresh keeps an uncovered Tomorrow unavailable instead of empty"
    )

    expectAgendaPresentation(
        AgendaParticipantPresentation.summary(for: ["Ada", "Grace", "Lin"]) == "Ada, Grace + 1",
        "participant summaries retain the first names and indicate remaining participants"
    )
    expectAgendaPresentation(
        AgendaParticipantPresentation.summary(for: []) == nil,
        "events without participants do not render an empty participant line"
    )
    expectAgendaPresentation(
        AgendaParticipantPresentation.accessibilityLabel(for: ["Ada", "Grace", "Lin"])
            == "Participants: Ada, Grace, Lin",
        "the timed participant detail control exposes every attendee to VoiceOver"
    )
    expectAgendaPresentation(
        AgendaParticipantPresentation.accessibilityLabel(for: []) == nil,
        "events without participants do not expose an empty participant detail control"
    )

    let multiDayAllDay = agendaPresentationEvent(
        id: "multi-day-all-day",
        start: agendaPresentationDate(newYork, year: 2024, month: 5, day: 15),
        end: agendaPresentationDate(newYork, year: 2024, month: 5, day: 17),
        isAllDay: true
    )
    let multiDaySections = AgendaDayPresentation.sections(
        events: [multiDayAllDay],
        now: now,
        calendar: newYork,
        snapshotInterval: agendaSnapshot,
        isLoading: false
    )
    let todayMultiDayTarget = multiDaySections.first { $0.day == .today }
        .map { $0.detailPopoverTarget(for: multiDayAllDay) }
    let tomorrowMultiDayTarget = multiDaySections.first { $0.day == .tomorrow }
        .map { $0.detailPopoverTarget(for: multiDayAllDay) }
    expectAgendaPresentation(
        todayMultiDayTarget?.eventID == multiDayAllDay.id
            && tomorrowMultiDayTarget?.eventID == multiDayAllDay.id
            && todayMultiDayTarget != tomorrowMultiDayTarget,
        "each day copy of a multi-day event has a distinct popover presenter identity"
    )

    let allDayDetails = CalendarEventDetailsPresentation(
        event: allDayToday,
        timeZone: newYork.timeZone,
        locale: newYork.locale!
    )
    expectAgendaPresentation(
        allDayDetails.title == "all-day-today"
            && allDayDetails.metadata == "All-day · Work"
            && allDayDetails.participantSummary == "No other participants",
        "all-day event details remain useful even when there are no other participants"
    )
    expectAgendaPresentation(
        CalendarEventActivationPolicy.action(for: event) == .selectReferenceMoment
            && CalendarEventActivationPolicy.action(for: allDayToday) == .showDetails,
        "timed activation retains reference selection while all-day activation is details-only"
    )
}
