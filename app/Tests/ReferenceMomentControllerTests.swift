import Foundation
import TimeZonerLib

private final class EventSelectionPresentationFake: EventSelectionPresenting {
    private var mapExpansionSnapshot: Bool?
    var isMapExpanded: Bool

    init(isMapExpanded: Bool) {
        self.isMapExpanded = isMapExpanded
    }

    func collapseMapForEventSelection() {
        mapExpansionSnapshot = isMapExpanded
        isMapExpanded = false
    }

    func restoreMapAfterEventSelection() {
        if let mapExpansionSnapshot {
            isMapExpanded = mapExpansionSnapshot
        }
        mapExpansionSnapshot = nil
    }

    func cancelMapRestorationAfterManualToggle() {
        mapExpansionSnapshot = nil
    }
}

private func expectReferenceMoment(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label)")
    }
}

private func makeReferenceMomentEvent(
    id: String,
    title: String,
    startDate: Date,
    isAllDay: Bool = false
) -> CalendarEventSnapshot {
    CalendarEventSnapshot(
        id: id,
        calendarID: "work",
        calendarTitle: "Work",
        title: title,
        startDate: startDate,
        endDate: startDate.addingTimeInterval(60 * 60),
        isAllDay: isAllDay,
        attendeeNames: [],
        availability: .busy,
        participationStatus: .accepted
    )
}

func runReferenceMomentControllerTests() {
    print("Running ReferenceMomentControllerTests...")

    let bangkok = TimeZone(identifier: "Asia/Bangkok")!
    let sanFrancisco = TimeZone(identifier: "America/Los_Angeles")!
    let firstStart = Date(timeIntervalSince1970: 1_750_000_000)
    let secondStart = firstStart.addingTimeInterval(60 * 60)

    do {
        let timeState = TimeState()
        let presentation = EventSelectionPresentationFake(isMapExpanded: true)
        let controller = ReferenceMomentController(timeState: timeState, presentation: presentation)
        let event = makeReferenceMomentEvent(id: "first", title: "Team sync", startDate: firstStart)

        controller.selectEvent(event, sourceZone: bangkok)

        expectReferenceMoment(timeState.referenceDate == firstStart, "timed selection uses the event's absolute start date")
        expectReferenceMoment(timeState.sourceZoneId == bangkok.identifier, "timed selection records the supplied source zone")
        expectReferenceMoment(!timeState.isLive, "timed selection leaves live mode")
        expectReferenceMoment(
            controller.selectedEvent == SelectedEventContext(id: "first", title: "Team sync", startDate: firstStart),
            "timed selection records compact event context"
        )
        expectReferenceMoment(!presentation.isMapExpanded, "timed selection collapses the map")
    }

    do {
        let timeState = TimeState()
        timeState.referenceDate = firstStart
        timeState.sourceZoneId = sanFrancisco.identifier
        timeState.isLive = false
        let presentation = EventSelectionPresentationFake(isMapExpanded: true)
        let controller = ReferenceMomentController(timeState: timeState, presentation: presentation)
        let allDayEvent = makeReferenceMomentEvent(id: "all-day", title: "Offsite", startDate: secondStart, isAllDay: true)

        controller.selectEvent(allDayEvent, sourceZone: bangkok)

        expectReferenceMoment(timeState.referenceDate == firstStart, "all-day selection leaves the reference date unchanged")
        expectReferenceMoment(timeState.sourceZoneId == sanFrancisco.identifier, "all-day selection leaves the source zone unchanged")
        expectReferenceMoment(!timeState.isLive, "all-day selection leaves live state unchanged")
        expectReferenceMoment(controller.selectedEvent == nil, "all-day selection does not create event context")
        expectReferenceMoment(presentation.isMapExpanded, "all-day selection leaves the map unchanged")
    }

    do {
        let presentation = EventSelectionPresentationFake(isMapExpanded: true)
        let controller = ReferenceMomentController(timeState: TimeState(), presentation: presentation)

        controller.selectEvent(makeReferenceMomentEvent(id: "first", title: "First", startDate: firstStart), sourceZone: bangkok)
        controller.selectEvent(makeReferenceMomentEvent(id: "second", title: "Second", startDate: secondStart), sourceZone: sanFrancisco)
        controller.setDate(secondStart.addingTimeInterval(60 * 60), sourceZone: sanFrancisco)

        expectReferenceMoment(presentation.isMapExpanded, "repeated event selection preserves the first map snapshot")
    }

    do {
        let presentation = EventSelectionPresentationFake(isMapExpanded: true)
        let controller = ReferenceMomentController(timeState: TimeState(), presentation: presentation)

        controller.selectEvent(makeReferenceMomentEvent(id: "selected", title: "Selected", startDate: firstStart), sourceZone: bangkok)
        controller.setTime(hour: 9, minute: 15, in: sanFrancisco)

        expectReferenceMoment(controller.selectedEvent == nil, "chat, card, and deep-link time changes clear event context")

        controller.selectEvent(makeReferenceMomentEvent(id: "selected-again", title: "Selected again", startDate: firstStart), sourceZone: bangkok)
        controller.setDate(secondStart, sourceZone: sanFrancisco)

        expectReferenceMoment(controller.selectedEvent == nil, "date changes clear event context")
        expectReferenceMoment(timeStateMatches(controller.timeState, date: secondStart, sourceZone: sanFrancisco, isLive: false), "date changes update the reference moment")

        controller.selectEvent(makeReferenceMomentEvent(id: "selected-live", title: "Selected live", startDate: firstStart), sourceZone: bangkok)
        controller.goLive()

        expectReferenceMoment(controller.selectedEvent == nil, "Now clears event context")
        expectReferenceMoment(controller.timeState.isLive, "Now restores live time")
    }

    do {
        let presentation = EventSelectionPresentationFake(isMapExpanded: false)
        let controller = ReferenceMomentController(timeState: TimeState(), presentation: presentation)

        controller.selectEvent(makeReferenceMomentEvent(id: "manual", title: "Manual", startDate: firstStart), sourceZone: bangkok)
        presentation.isMapExpanded = true
        controller.didManuallyToggleMap()
        controller.goLive()

        expectReferenceMoment(presentation.isMapExpanded, "manual map toggling cancels automatic restoration")
    }

    do {
        let presentation = EventSelectionPresentationFake(isMapExpanded: true)
        let controller = ReferenceMomentController(timeState: TimeState(), presentation: presentation)

        controller.selectEvent(makeReferenceMomentEvent(id: "restore", title: "Restore", startDate: firstStart), sourceZone: bangkok)
        controller.goLive()

        expectReferenceMoment(presentation.isMapExpanded, "ordinary context clearing restores the pre-selection map state")
    }
}

private func timeStateMatches(_ timeState: TimeState, date: Date, sourceZone: TimeZone, isLive: Bool) -> Bool {
    timeState.referenceDate == date
        && timeState.sourceZoneId == sourceZone.identifier
        && timeState.isLive == isLive
}
