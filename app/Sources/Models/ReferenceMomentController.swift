import Foundation

public struct SelectedEventContext: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let startDate: Date

    public init(id: String, title: String, startDate: Date) {
        self.id = id
        self.title = title
        self.startDate = startDate
    }
}

/// The presentation boundary for the map behavior that accompanies event selection.
/// CalendarPresentationState adopts this protocol when calendar presentation state is added.
public protocol EventSelectionPresenting: AnyObject {
    func collapseMapForEventSelection()
    func restoreMapAfterEventSelection()
    func cancelMapRestorationAfterManualToggle()
}

@Observable
public final class ReferenceMomentController {
    public let timeState: TimeState
    public private(set) var selectedEvent: SelectedEventContext?

    private let presentation: (any EventSelectionPresenting)?
    private var shouldRestoreMapAfterSelection = false

    public init(timeState: TimeState, presentation: (any EventSelectionPresenting)? = nil) {
        self.timeState = timeState
        self.presentation = presentation
    }

    public func selectEvent(_ event: CalendarEventSnapshot, sourceZone: TimeZone) {
        guard !event.isAllDay else { return }

        if selectedEvent == nil {
            shouldRestoreMapAfterSelection = true
            presentation?.collapseMapForEventSelection()
        }

        timeState.referenceDate = event.startDate
        timeState.sourceZoneId = sourceZone.identifier
        timeState.isLive = false
        selectedEvent = SelectedEventContext(id: event.id, title: event.title, startDate: event.startDate)
    }

    public func setTime(hour: Int, minute: Int, in zone: TimeZone) {
        clearSelectedEvent()
        let state = timeState
        state.setTime(hour: hour, minute: minute, in: zone)
    }

    public func setDate(_ date: Date, sourceZone: TimeZone) {
        clearSelectedEvent()
        timeState.referenceDate = date
        timeState.sourceZoneId = sourceZone.identifier
        timeState.isLive = false
    }

    public func goLive() {
        clearSelectedEvent()
        let state = timeState
        state.goLive()
    }

    public func clearSelectedEvent() {
        guard selectedEvent != nil else { return }

        selectedEvent = nil
        if shouldRestoreMapAfterSelection {
            presentation?.restoreMapAfterEventSelection()
        }
        shouldRestoreMapAfterSelection = false
    }

    public func didManuallyToggleMap() {
        guard selectedEvent != nil else { return }

        shouldRestoreMapAfterSelection = false
        presentation?.cancelMapRestorationAfterManualToggle()
    }
}
