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
}
