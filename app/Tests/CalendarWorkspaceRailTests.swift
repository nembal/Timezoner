import Foundation
import TimeZonerLib

func runCalendarWorkspaceRailTests() {
    print("Running CalendarWorkspaceRailTests...")

    let start = Date(timeIntervalSince1970: 1_750_000_000)
    let suiteName = "CalendarWorkspaceRailTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let presentation = CalendarPresentationState(defaults: defaults)
    presentation.enterCalendar(now: start, calendar: .current)
    let reference = ReferenceMomentController(timeState: TimeState(), presentation: presentation)
    let utc = TimeZone(identifier: "UTC")!
    let liveContext: CalendarRailContextPresentation? = CalendarRailContextPresentation(
        selectedEvent: reference.selectedEvent,
        date: start,
        timeZone: utc
    )
    workspaceExpect(liveContext == nil,
                    "live Calendar rail has no context heading, timestamp, accessibility label, or help text")
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
    let selectedContext = CalendarRailContextPresentation(
        selectedEvent: reference.selectedEvent,
        date: reference.timeState.referenceDate,
        timeZone: utc
    )
    workspaceExpect(selectedContext?.title == "Planning across cities",
                    "selected event rail context retains the event title")
    workspaceExpect(selectedContext?.dateTime == "Sun, Jun 15 · 3:06 pm GMT",
                    "selected event rail context retains the event local date and time")
    workspaceExpect(selectedContext?.accessibilityLabel == "Planning across cities, Sun, Jun 15 · 3:06 pm GMT",
                    "selected event rail context retains its accessibility label")
    workspaceExpect(selectedContext?.helpText == "Planning across cities",
                    "selected event rail context retains its help text")

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
    workspaceExpect(reference.selectedEvent?.id == event.id, "timed activation sets selected event context")

    let requestedZone = TimeZone(identifier: "Asia/Tokyo")!
    reference.setTime(hour: 16, minute: 45, in: requestedZone)
    var requestedCalendar = Calendar(identifier: .gregorian)
    requestedCalendar.timeZone = requestedZone
    let requestedComponents = requestedCalendar.dateComponents([.hour, .minute], from: reference.timeState.referenceDate)
    workspaceExpect(presentation.destination == .calendar, "editing a rail card keeps the calendar workspace active")
    workspaceExpect(reference.selectedEvent == nil, "editing a rail card clears the selected event context")
    workspaceExpect(requestedComponents.hour == 16 && requestedComponents.minute == 45,
                    "editing a rail card represents the requested local instant")
    workspaceExpect(!reference.timeState.isLive, "editing a rail card leaves the reference moment adjusted")

    reference.goLive()
    workspaceExpect(presentation.destination == .calendar && reference.selectedEvent == nil,
                    "Now clears context without exiting workspace")
}
