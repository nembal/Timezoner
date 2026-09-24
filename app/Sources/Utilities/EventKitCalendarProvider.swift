import AppKit
import EventKit
import Foundation

public final class EventKitCalendarProvider: CalendarEventReading {
    private let executor: EventKitCalendarExecutor
    public let changes: AsyncStream<Void>

    public init() {
        let stream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        changes = stream.stream
        executor = EventKitCalendarExecutor(changeContinuation: stream.continuation)
    }

    public var authorizationStatus: CalendarAuthorizationStatus {
        EventKitCalendarMappings.authorizationStatus(EKEventStore.authorizationStatus(for: .event))
    }

    public func requestAccess() async throws -> Bool {
        try await executor.requestAccess()
    }

    public func calendars() async throws -> [CalendarDescriptor] {
        await executor.calendars()
    }

    public func events(
        from start: Date,
        to end: Date,
        calendarIDs: Set<String>
    ) async throws -> [CalendarEventSnapshot] {
        await executor.events(from: start, to: end, calendarIDs: calendarIDs)
    }
}

private actor EventKitCalendarExecutor {
    private let eventStore: EKEventStore
    private let changeContinuation: AsyncStream<Void>.Continuation
    private var changeObserver: NSObjectProtocol?

    init(changeContinuation: AsyncStream<Void>.Continuation) {
        let eventStore = EKEventStore()
        self.eventStore = eventStore
        self.changeContinuation = changeContinuation
        let continuation = changeContinuation
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: nil
        ) { _ in
            continuation.yield(())
        }
    }

    deinit {
        if let changeObserver {
            NotificationCenter.default.removeObserver(changeObserver)
        }
        changeContinuation.finish()
    }

    func requestAccess() async throws -> Bool {
        try await eventStore.requestFullAccessToEvents()
    }

    func calendars() -> [CalendarDescriptor] {
        eventStore.calendars(for: .event).map(EventKitCalendarMappings.calendar)
    }

    func events(from start: Date, to end: Date, calendarIDs: Set<String>) -> [CalendarEventSnapshot] {
        let calendars = eventStore.calendars(for: .event).filter {
            calendarIDs.contains($0.calendarIdentifier)
        }
        guard !calendars.isEmpty else { return [] }

        let predicate = eventStore.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return eventStore.events(matching: predicate).compactMap(EventKitCalendarMappings.event)
    }
}

private enum EventKitCalendarMappings {
    static func authorizationStatus(_ status: EKAuthorizationStatus) -> CalendarAuthorizationStatus {
        switch status {
        case .notDetermined:
            .notDetermined
        case .restricted:
            .restricted
        case .denied:
            .denied
        case .fullAccess, .authorized:
            .fullAccess
        case .writeOnly:
            .writeOnly
        @unknown default:
            .restricted
        }
    }

    static func calendar(_ calendar: EKCalendar) -> CalendarDescriptor {
        CalendarDescriptor(
            id: calendar.calendarIdentifier,
            title: calendar.title,
            sourceTitle: calendar.source.title,
            color: calendarColor(from: calendar.cgColor)
        )
    }

    static func event(_ event: EKEvent) -> CalendarEventSnapshot? {
        let organizer = event.organizer
        let eventAttendees: [EKParticipant] = event.attendees ?? []
        let attendees = eventAttendees.map { attendee in
            CalendarEventAttendee(
                displayName: attendee.name,
                email: attendeeEmail(from: attendee.url),
                isCurrentAccount: attendee.isCurrentUser
            )
        }
        let currentAccountParticipationStatus = CalendarCurrentAccountParticipationMapper.status(
            organizer: organizer.map {
                CalendarEventParticipantParticipation(
                    isCurrentAccount: $0.isCurrentUser,
                    participationStatus: participationStatus($0.participantStatus)
                )
            },
            attendees: eventAttendees.map {
                CalendarEventParticipantParticipation(
                    isCurrentAccount: $0.isCurrentUser,
                    participationStatus: participationStatus($0.participantStatus)
                )
            }
        )

        return CalendarEventSnapshotMapper.snapshot(from: CalendarEventMappingInput(
            calendarItemIdentifier: event.calendarItemIdentifier,
            calendarID: event.calendar.calendarIdentifier,
            calendarTitle: event.calendar.title,
            title: event.title,
            startDate: event.startDate,
            endDate: event.endDate,
            isAllDay: event.isAllDay,
            attendees: attendees,
            availability: availability(event.availability),
            currentAccountParticipationStatus: currentAccountParticipationStatus,
            isCancelled: event.status == .canceled
        ))
    }

    private static func calendarColor(from color: CGColor) -> CalendarColor {
        guard let converted = NSColor(cgColor: color)?.usingColorSpace(.sRGB) else {
            return CalendarColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 1)
        }

        return CalendarColor(
            red: Double(converted.redComponent),
            green: Double(converted.greenComponent),
            blue: Double(converted.blueComponent),
            alpha: Double(converted.alphaComponent)
        )
    }

    private static func attendeeEmail(from url: URL) -> String {
        url.scheme?.lowercased() == "mailto" ? url.path : url.absoluteString
    }

    private static func availability(_ availability: EKEventAvailability) -> EventAvailability {
        switch availability {
        case .busy:
            .busy
        case .free:
            .free
        case .tentative:
            .tentative
        case .notSupported, .unavailable:
            .unavailable
        @unknown default:
            .unavailable
        }
    }

    private static func participationStatus(_ status: EKParticipantStatus) -> EventParticipationStatus {
        switch status {
        case .unknown:
            .unknown
        case .pending:
            .pending
        case .accepted:
            .accepted
        case .declined:
            .declined
        case .tentative:
            .tentative
        case .delegated:
            .delegated
        case .completed:
            .completed
        case .inProcess:
            .inProcess
        @unknown default:
            .unknown
        }
    }
}
