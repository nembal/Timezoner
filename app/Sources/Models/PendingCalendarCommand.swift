import Foundation

/// Value-only data retained in memory between a TimeZoner alert response and the ready panels.
/// It intentionally contains neither EventKit values nor persisted notification content.
public struct PendingCalendarCommand: Equatable, Sendable {
    public static let notificationRequestPrefix = "timezoner.event."

    public let occurrenceID: String
    public let title: String
    public let startDate: Date

    public init(occurrenceID: String, title: String, startDate: Date) {
        self.occurrenceID = occurrenceID
        self.title = title
        self.startDate = startDate
    }

    /// Parses only the compact TimeZoner-owned notification payload contract.
    public static func notificationCommand(
        requestIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) -> PendingCalendarCommand? {
        guard requestIdentifier.hasPrefix(notificationRequestPrefix),
              let occurrenceID = userInfo["occurrenceID"] as? String,
              !occurrenceID.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let title = userInfo["title"] as? String,
              !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              let timestamp = timestamp(from: userInfo["startTimestamp"]),
              timestamp.isFinite else {
            return nil
        }

        return PendingCalendarCommand(
            occurrenceID: occurrenceID,
            title: title,
            startDate: Date(timeIntervalSince1970: timestamp)
        )
    }

    private static func timestamp(from value: Any?) -> TimeInterval? {
        switch value {
        case is Bool:
            nil
        case let value as TimeInterval:
            value
        case let value as NSNumber:
            value.doubleValue
        default:
            nil
        }
    }
}

/// A main-actor serial queue which keeps alert responses private and ordered until both panels exist.
@MainActor
public final class PendingCalendarCommandQueue {
    public typealias Route = @MainActor (PendingCalendarCommand) async -> Void

    private let route: Route
    private var queued: [PendingCalendarCommand] = []
    private var isReady = false
    private var isDraining = false

    public init(route: @escaping Route) {
        self.route = route
    }

    public func enqueue(_ command: PendingCalendarCommand) {
        queued.append(command)
        beginDrainIfReady()
    }

    /// Becomes ready once; subsequent calls preserve the already-consumed queue state.
    public func markReady() {
        guard !isReady else { return }
        isReady = true
        beginDrainIfReady()
    }

    private func beginDrainIfReady() {
        guard isReady, !isDraining, !queued.isEmpty else { return }
        isDraining = true
        Task { [weak self] in
            await self?.drain()
        }
    }

    private func drain() async {
        while !queued.isEmpty {
            let command = queued.removeFirst()
            await route(command)
        }

        isDraining = false
        // A command can arrive between the final removal and clearing the drain flag.
        beginDrainIfReady()
    }
}

/// Library-owned foreground policy keeps UserNotifications framework values at the app edge.
public enum CalendarNotificationForegroundPresentation: Equatable, Sendable {
    case none
    case bannerAndSound
}

public enum CalendarNotificationForegroundPolicy {
    public static func presentation(
        requestIdentifier: String,
        userInfo: [AnyHashable: Any]
    ) -> CalendarNotificationForegroundPresentation {
        PendingCalendarCommand.notificationCommand(
            requestIdentifier: requestIdentifier,
            userInfo: userInfo
        ) == nil ? .none : .bannerAndSound
    }
}

/// Resolves one command at a time after the paired panels and shared stores have been created.
@MainActor
public final class CalendarNotificationCommandRouter {
    public typealias EventResolver = @MainActor (String, Date) async throws -> CalendarEventSnapshot?
    public typealias TimeZonerSurfacePreparer = @MainActor () -> Void
    public typealias PairedPanelPresenter = @MainActor () -> Void
    public typealias EventSelector = @MainActor (CalendarEventSnapshot, TimeZone) -> Void
    public typealias FallbackSelector = @MainActor (String, String, Date, TimeZone) -> Void
    public typealias SelectedContextFocusHandoff = @MainActor () -> Void

    private let resolveEvent: EventResolver
    private let prepareTimeZonerSurface: TimeZonerSurfacePreparer
    private let showPairedPanels: PairedPanelPresenter
    private let selectEvent: EventSelector
    private let selectFallback: FallbackSelector
    private let focusSelectedEventContext: SelectedContextFocusHandoff
    private let sourceZone: () -> TimeZone

    public init(
        resolveEvent: @escaping EventResolver,
        prepareTimeZonerSurface: @escaping TimeZonerSurfacePreparer = {},
        showPairedPanels: @escaping PairedPanelPresenter,
        selectEvent: @escaping EventSelector,
        selectFallback: @escaping FallbackSelector,
        focusSelectedEventContext: @escaping SelectedContextFocusHandoff = {},
        sourceZone: @escaping () -> TimeZone = { .current }
    ) {
        self.resolveEvent = resolveEvent
        self.prepareTimeZonerSurface = prepareTimeZonerSurface
        self.showPairedPanels = showPairedPanels
        self.selectEvent = selectEvent
        self.selectFallback = selectFallback
        self.focusSelectedEventContext = focusSelectedEventContext
        self.sourceZone = sourceZone
    }

    public func route(_ command: PendingCalendarCommand) async {
        prepareTimeZonerSurface()
        showPairedPanels()
        let zone = sourceZone()

        do {
            if let event = try await resolveEvent(command.occurrenceID, command.startDate) {
                selectEvent(event, zone)
                focusSelectedEventContext()
                return
            }
        } catch {
            // Calendar access can have been revoked between delivery and response routing.
        }

        selectFallback(command.occurrenceID, command.title, command.startDate, zone)
        focusSelectedEventContext()
    }
}
