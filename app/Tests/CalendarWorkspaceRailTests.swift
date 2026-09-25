import Foundation
import TimeZonerLib

func runCalendarWorkspaceRailTests() {
    print("Running CalendarWorkspaceRailTests...")

    let start = Date(timeIntervalSince1970: 1_750_000_000)
    let presentation = CalendarPresentationState(defaults: UserDefaults(suiteName: "CalendarWorkspaceRailTests.\(UUID().uuidString)")!)
    presentation.enterCalendar(now: start, calendar: .current)
    let reference = ReferenceMomentController(timeState: TimeState(), presentation: presentation)
    let event = CalendarEventSnapshot(
        id: "meeting",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Planning across cities",
        startDate: start,
        endDate: start.addingTimeInterval(3600),
        isAllDay: false,
        attendeeNames: [],
        availability: .busy,
        participationStatus: .accepted
    )
    CalendarWorkspaceEventActivation.select(event, referenceMoment: reference)
    workspaceExpect(presentation.destination == .calendar, "timed selection stays in workspace")
    workspaceExpect(reference.timeState.referenceDate == start, "rail receives event instant")

    let zones = (0..<8).map { ZoneInfo(label: "City \($0)", timeZoneId: "America/New_York") }
    let cards = zones.map { CalendarRailCardPresentation(zone: $0, date: reference.timeState.referenceDate) }
    workspaceExpect(cards.count == 8 && cards.allSatisfy { !$0.time.isEmpty }, "every active city is represented")
    workspaceExpect([ZoneInfo]().map { CalendarRailCardPresentation(zone: $0, date: start) }.isEmpty,
                    "no saved cities produces an empty list rather than a dummy city")

    let allDay = CalendarEventSnapshot(
        id: "holiday",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Holiday",
        startDate: start.addingTimeInterval(86400),
        endDate: start.addingTimeInterval(172800),
        isAllDay: true,
        attendeeNames: [],
        availability: .free,
        participationStatus: .accepted
    )
    CalendarWorkspaceEventActivation.select(allDay, referenceMoment: reference)
    workspaceExpect(reference.timeState.referenceDate == start, "all-day activation cannot change rail instant")

    reference.goLive()
    workspaceExpect(presentation.destination == .calendar && reference.selectedEvent == nil,
                    "Now clears context without exiting workspace")
}
