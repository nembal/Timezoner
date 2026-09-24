import Foundation

public enum CalendarAuthorizationStatus: Equatable, Sendable {
    case notDetermined
    case restricted
    case denied
    case fullAccess
    case writeOnly
}

/// The visible surface required by the transparent floating panel used for the packaged permission probe.
public struct CalendarPermissionProbeSurfaceStyle: Equatable, Sendable {
    public let cornerRadius: Double
    public let fillOpacity: Double

    public init(cornerRadius: Double, fillOpacity: Double) {
        self.cornerRadius = cornerRadius
        self.fillOpacity = fillOpacity
    }

    public static let standard = CalendarPermissionProbeSurfaceStyle(
        cornerRadius: 16,
        fillOpacity: 1
    )
}

public enum CalendarPermissionRecoveryAction: Equatable, Sendable {
    case hideProbe
    case openCalendarPrivacySettings
}

/// The recovery sequence keeps the always-on-top probe from obscuring System Settings.
public enum CalendarPermissionRecoveryPlan {
    public static let actions: [CalendarPermissionRecoveryAction] = [
        .hideProbe,
        .openCalendarPrivacySettings
    ]
}

public struct CalendarColor: Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double

    public init(red: Double, green: Double, blue: Double, alpha: Double) {
        self.red = Self.normalized(red)
        self.green = Self.normalized(green)
        self.blue = Self.normalized(blue)
        self.alpha = Self.normalized(alpha)
    }

    private static func normalized(_ component: Double) -> Double {
        min(max(component, 0), 1)
    }
}

public struct CalendarDescriptor: Identifiable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let sourceTitle: String
    public let color: CalendarColor

    public init(id: String, title: String, sourceTitle: String, color: CalendarColor) {
        self.id = id
        self.title = title
        self.sourceTitle = sourceTitle
        self.color = color
    }
}

public enum EventAvailability: Equatable, Sendable {
    case busy
    case free
    case tentative
    case unavailable
}

public enum EventParticipationStatus: Equatable, Sendable {
    case unknown
    case pending
    case accepted
    case declined
    case tentative
    case delegated
    case completed
    case inProcess
}

/// The participation facts copied from one calendar participant at the EventKit boundary.
/// This keeps the current-account selection rule testable without exposing EventKit types.
public struct CalendarEventParticipantParticipation: Equatable, Sendable {
    public let isCurrentAccount: Bool
    public let participationStatus: EventParticipationStatus

    public init(isCurrentAccount: Bool, participationStatus: EventParticipationStatus) {
        self.isCurrentAccount = isCurrentAccount
        self.participationStatus = participationStatus
    }
}

/// Selects the signed-in account's response from EventKit-derived values.
/// An attendee response is authoritative for an invitation; an organizer response is the fallback
/// for events owned by the current account which have no current-account attendee entry.
public enum CalendarCurrentAccountParticipationMapper {
    public static func status(
        organizer: CalendarEventParticipantParticipation?,
        attendees: [CalendarEventParticipantParticipation]
    ) -> EventParticipationStatus {
        if let attendee = attendees.first(where: \.isCurrentAccount) {
            return attendee.participationStatus
        }

        guard let organizer, organizer.isCurrentAccount else { return .unknown }
        return organizer.participationStatus
    }
}

public struct CalendarEventSnapshot: Identifiable, Equatable, Sendable {
    public let id: String
    public let calendarID: String
    public let calendarTitle: String
    public let title: String
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let attendeeNames: [String]
    public let availability: EventAvailability
    public let participationStatus: EventParticipationStatus

    public init(
        id: String,
        calendarID: String,
        calendarTitle: String,
        title: String,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        attendeeNames: [String],
        availability: EventAvailability,
        participationStatus: EventParticipationStatus
    ) {
        self.id = id
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.attendeeNames = attendeeNames
        self.availability = availability
        self.participationStatus = participationStatus
    }
}

/// A copied attendee value used while adapting EventKit data without retaining EKParticipant instances.
public struct CalendarEventAttendee: Equatable, Sendable {
    public let displayName: String?
    public let email: String?

    public init(displayName: String?, email: String?) {
        self.displayName = displayName
        self.email = email
    }
}

/// Value-only input to the event mapper. It deliberately contains no EventKit types.
public struct CalendarEventMappingInput: Equatable, Sendable {
    public let calendarItemIdentifier: String
    public let calendarID: String
    public let calendarTitle: String
    public let title: String?
    public let startDate: Date
    public let endDate: Date
    public let isAllDay: Bool
    public let attendees: [CalendarEventAttendee]
    public let availability: EventAvailability
    public let currentAccountParticipationStatus: EventParticipationStatus
    public let isCancelled: Bool

    public init(
        calendarItemIdentifier: String,
        calendarID: String,
        calendarTitle: String,
        title: String?,
        startDate: Date,
        endDate: Date,
        isAllDay: Bool,
        attendees: [CalendarEventAttendee],
        availability: EventAvailability,
        currentAccountParticipationStatus: EventParticipationStatus,
        isCancelled: Bool
    ) {
        self.calendarItemIdentifier = calendarItemIdentifier
        self.calendarID = calendarID
        self.calendarTitle = calendarTitle
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.isAllDay = isAllDay
        self.attendees = attendees
        self.availability = availability
        self.currentAccountParticipationStatus = currentAccountParticipationStatus
        self.isCancelled = isCancelled
    }
}

/// Normalizes copied event data into the immutable presentation snapshot used by the app.
public enum CalendarEventSnapshotMapper {
    public static func snapshot(from input: CalendarEventMappingInput) -> CalendarEventSnapshot? {
        guard !input.isCancelled else { return nil }
        guard input.currentAccountParticipationStatus != .declined else {
            return nil
        }

        let title = nonEmpty(input.title) ?? "Untitled event"
        let attendeeNames = input.attendees.compactMap { attendee in
            nonEmpty(attendee.displayName) ?? nonEmpty(attendee.email)
        }

        return CalendarEventSnapshot(
            id: "\(input.calendarItemIdentifier)|\(input.startDate.timeIntervalSince1970)",
            calendarID: input.calendarID,
            calendarTitle: input.calendarTitle,
            title: title,
            startDate: input.startDate,
            endDate: input.endDate,
            isAllDay: input.isAllDay,
            attendeeNames: attendeeNames,
            availability: input.availability,
            participationStatus: input.currentAccountParticipationStatus
        )
    }

    private static func nonEmpty(_ value: String?) -> String? {
        guard let value else { return nil }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
