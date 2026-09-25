import Foundation

/// The app-facing cleanup invoked from CalendarStore's full-to-unavailable callback.
/// Keeping it in TimeZonerLib lets the real composition contract remain deterministic.
@MainActor
public enum CalendarPermissionLossCoordinator {
    public static func handle(
        referenceMoment: ReferenceMomentController,
        presentation: CalendarPresentationState
    ) {
        referenceMoment.clearSelectedEvent()
        presentation.attendeePopoverEventID = nil
        presentation.presentRecovery()
    }
}

/// Permission-aware outcome for an explicit request to show or hide the agenda wing.
/// The app coordinator applies this plan to panels and durable preferences.
public enum CalendarAgendaWingRequest {
    public enum Outcome: Equatable, Sendable {
        case hide
        case show
        case explainAccess
        case recoverAccess
    }

    public static func outcome(
        requested: Bool,
        authorizationStatus: CalendarAuthorizationStatus
    ) -> Outcome {
        guard requested else { return .hide }
        switch authorizationStatus {
        case .fullAccess:
            return .show
        case .notDetermined:
            return .explainAccess
        case .denied, .restricted, .writeOnly:
            return .recoverAccess
        }
    }
}

public enum CalendarDestination: Equatable, Sendable {
    case timezoner
    case calendar
}

/// Identifies one concrete event-details presenter rather than only the EventKit event. The same
/// multi-day event may have a distinct visible row for each agenda day, so its popover anchor must
/// remain specific to the row that opened it.
public struct CalendarEventDetailPopoverTarget: Equatable, Sendable {
    public let eventID: String
    public let presenterID: String

    public init(eventID: String, presenterID: String) {
        self.eventID = eventID
        self.presenterID = presenterID
    }
}

/// User-facing calendar presentation that outlives SwiftUI view reconstruction.
/// It also owns the map-selection snapshot so selecting a calendar event never loses
/// the user's prior map expansion choice.
@Observable
public final class CalendarPresentationState: EventSelectionPresenting {
    public enum AccessDestination: Equatable {
        case none
        case explanation
        case recovery
    }

    public private(set) var isMapExpanded: Bool
    public var isSettingsPresented = false
    /// The active presenter remains distinct when one event appears in multiple visible rows.
    public var eventDetailPopoverTarget: CalendarEventDetailPopoverTarget?
    /// Compatibility lookup for callers that only need the event identity. New presentation code
    /// must use `eventDetailPopoverTarget` to avoid activating multiple anchors for one event.
    public var eventDetailPopoverEventID: String? {
        get { eventDetailPopoverTarget?.eventID }
        set {
            eventDetailPopoverTarget = newValue.map {
                CalendarEventDetailPopoverTarget(eventID: $0, presenterID: "legacy-event:\($0)")
            }
        }
    }
    public var attendeePopoverEventID: String? {
        get { eventDetailPopoverEventID }
        set { eventDetailPopoverEventID = newValue }
    }
    public var accessDestination: AccessDestination = .none
    public var mainPanelHugsMenuBar = true
    public var agendaPanelHugsMenuBar = true
    public private(set) var destination: CalendarDestination = .timezoner
    public private(set) var range: CalendarRangeSelection = .week
    public private(set) var anchor: Date
    /// Session-scoped selection only. It deliberately is not persisted with preferences.
    public private(set) var lastRange: CalendarRangeSelection?

    private let defaults: UserDefaults
    private let mapExpandedKey: String
    private let settings: SettingsStore
    private var mapExpansionSnapshot: Bool?

    public init(
        settings: SettingsStore = .shared,
        defaults: UserDefaults = .standard,
        mapExpandedKey: String = "mapExpanded"
    ) {
        self.settings = settings
        self.defaults = defaults
        self.mapExpandedKey = mapExpandedKey
        anchor = Date()
        if defaults.object(forKey: mapExpandedKey) == nil {
            isMapExpanded = true
        } else {
            isMapExpanded = defaults.bool(forKey: mapExpandedKey)
        }
    }

    /// SettingsStore owns the durable preference. Presentation state exposes it so all
    /// surfaces participate in one process-lifetime state graph.
    public var showAgendaWing: Bool {
        get { settings.showAgendaWing }
        set { settings.showAgendaWing = newValue }
    }

    public var hasOwnedPopover: Bool {
        isSettingsPresented || eventDetailPopoverTarget != nil
    }

    public func toggleMapManually() {
        isMapExpanded.toggle()
        defaults.set(isMapExpanded, forKey: mapExpandedKey)
    }

    public func collapseMapForEventSelection() {
        guard mapExpansionSnapshot == nil else { return }
        mapExpansionSnapshot = isMapExpanded
        isMapExpanded = false
    }

    public func restoreMapAfterEventSelection() {
        guard let mapExpansionSnapshot else { return }
        isMapExpanded = mapExpansionSnapshot
        self.mapExpansionSnapshot = nil
    }

    public func cancelMapRestorationAfterManualToggle() {
        mapExpansionSnapshot = nil
    }

    public func presentAccessExplanation() {
        accessDestination = .explanation
    }

    public func presentRecovery() {
        accessDestination = .recovery
    }

    public func dismissAccessDestination() {
        accessDestination = .none
    }

    /// Opens the full calendar without ever changing TimeZoner's selected reference moment.
    public func enterCalendar(now: Date, calendar: Calendar) {
        range = lastRange ?? .week
        anchor = calendar.startOfDay(for: now)
        destination = .calendar
    }

    public func setRange(_ range: CalendarRangeSelection) {
        self.range = range
        lastRange = range
    }

    public func move(_ direction: CalendarRangeNavigationDirection, calendar: Calendar) {
        anchor = CalendarDateIntervalCalculator.movedAnchor(
            anchor,
            direction: direction,
            range: range,
            calendar: calendar
        )
    }

    /// Resets only the calendar's local-day anchor. The shared TimeState remains untouched.
    public func goToday(now: Date, calendar: Calendar) {
        anchor = calendar.startOfDay(for: now)
    }

    public func activeInterval(calendar: Calendar) -> DateInterval {
        CalendarDateIntervalCalculator.interval(for: range, anchor: anchor, calendar: calendar)
    }

    public func returnToTimeZoner() {
        lastRange = range
        destination = .timezoner
    }

    /// Leaves Calendar mode once, preserving its range and making the timezone surface visible.
    /// Presentation callers supply their own panel-frame restoration after this value-only action.
    @discardableResult
    public func restoreTimeZonerSurface() -> Bool {
        guard destination == .calendar else { return false }
        returnToTimeZoner()
        return true
    }
}

/// Couples the shared event-detail identity to the floating-panel ownership callback. Both
/// Calendar surfaces use this path so focus transfer to a SwiftUI detail popover cannot dismiss
/// the panel hosting it.
@MainActor
public enum CalendarEventDetailPopoverOwnership {
    public static func update(
        target: CalendarEventDetailPopoverTarget?,
        presentation: CalendarPresentationState,
        onOwnedPopoverChanged: (Bool) -> Void
    ) {
        presentation.eventDetailPopoverTarget = target
        onOwnedPopoverChanged(presentation.hasOwnedPopover)
    }

    /// Compatibility overload for the earlier single-presenter caller. New surfaces should supply
    /// a target that includes the row or grid anchor.
    public static func update(
        eventID: String?,
        presentation: CalendarPresentationState,
        onOwnedPopoverChanged: (Bool) -> Void
    ) {
        update(
            target: eventID.map {
                CalendarEventDetailPopoverTarget(eventID: $0, presenterID: "legacy-event:\($0)")
            },
            presentation: presentation,
            onOwnedPopoverChanged: onOwnedPopoverChanged
        )
    }
}

/// The explicit-access contract shared by the normal floating panel and the Calendar surfaces.
/// Merely rendering an explanation never calls EventKit; only the visible user action does.
public enum CalendarAccessFlow {
    public enum UserAction: Equatable, Sendable {
        case requestFullAccess
        case openPrivacySettings
    }

    public enum Resolution: Equatable, Sendable {
        case none
        case waitForUserAction
        case showAgenda
        case showRecovery
    }

    public static func userAction(for authorizationStatus: CalendarAuthorizationStatus) -> UserAction {
        switch authorizationStatus {
        case .notDetermined:
            return .requestFullAccess
        case .denied, .restricted, .writeOnly, .fullAccess:
            return .openPrivacySettings
        }
    }

    /// Resolves a status transition after the access surface was intentionally presented.
    /// Full access restores the requested agenda; unavailable access remains in recovery.
    public static func resolution(
        authorizationStatus: CalendarAuthorizationStatus,
        accessDestination: CalendarPresentationState.AccessDestination
    ) -> Resolution {
        guard accessDestination != .none else { return .none }
        switch authorizationStatus {
        case .fullAccess:
            return .showAgenda
        case .notDetermined:
            return .waitForUserAction
        case .denied, .restricted, .writeOnly:
            return .showRecovery
        }
    }
}

/// Geometry-only main-panel sizing for calendar mode. Keeping this out of AppKit makes the
/// saved-frame contract deterministic in the executable test target.
public enum CalendarPanelFrameCalculator {
    public static let calendarTargetSize = CGSize(width: 760, height: 560)

    public static func calendarFrame(normalFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        return clampedFrame(
            centeredAt: normalFrame.center,
            requestedSize: calendarTargetSize,
            visibleFrame: visibleFrame
        )
    }

    public static func restoredNormalFrame(_ normalFrame: CGRect, visibleFrame: CGRect) -> CGRect {
        return restoredNormalFrame(normalFrame, visibleFrame: visibleFrame, screenDidChange: false)
    }

    /// A same-screen return must preserve the user-captured normal frame exactly. Only a real
    /// display transition justifies reclamping that saved frame to a new visible area.
    public static func restoredNormalFrame(
        _ normalFrame: CGRect,
        visibleFrame: CGRect,
        screenDidChange: Bool
    ) -> CGRect {
        guard screenDidChange else { return normalFrame }
        return clampedFrame(
            centeredAt: normalFrame.center,
            requestedSize: normalFrame.size,
            visibleFrame: visibleFrame
        )
    }

    private static func clampedFrame(
        centeredAt center: CGPoint,
        requestedSize: CGSize,
        visibleFrame: CGRect
    ) -> CGRect {
        guard visibleFrame.width > 0, visibleFrame.height > 0 else {
            return CGRect(
                x: center.x - requestedSize.width / 2,
                y: center.y - requestedSize.height / 2,
                width: requestedSize.width,
                height: requestedSize.height
            )
        }

        let size = CGSize(
            width: min(requestedSize.width, visibleFrame.width),
            height: min(requestedSize.height, visibleFrame.height)
        )
        let desiredOrigin = CGPoint(
            x: center.x - size.width / 2,
            y: center.y - size.height / 2
        )
        let origin = CGPoint(
            x: min(max(desiredOrigin.x, visibleFrame.minX), visibleFrame.maxX - size.width),
            y: min(max(desiredOrigin.y, visibleFrame.minY), visibleFrame.maxY - size.height)
        )
        return CGRect(origin: origin, size: size)
    }
}

private extension CGRect {
    var center: CGPoint {
        CGPoint(x: midX, y: midY)
    }
}

/// Distinguishes a confirmed empty agenda from an empty snapshot caused by a failed fetch.
/// The view uses this before presenting any "clear" language.
public enum AgendaContentState: Equatable {
    case loading
    case errorWithoutEvents(String)
    case agenda

    public static func resolve(
        events: [CalendarEventSnapshot],
        isLoading: Bool,
        errorMessage: String?
    ) -> AgendaContentState {
        if events.isEmpty, let errorMessage {
            return .errorWithoutEvents(errorMessage)
        }
        if events.isEmpty, isLoading {
            return .loading
        }
        return .agenda
    }
}

public enum AgendaPlacement: Equatable, Sendable {
    case right
    case left
    case popover
}

/// The concrete surface entered by TimeZoner's agenda-focus keyboard command.
public enum CalendarAgendaFocusTarget: Equatable, Sendable {
    case detachedPanel
    case popover
}

public struct AgendaPlacementResult: Equatable, Sendable {
    public let location: AgendaPlacement
    public let frame: CGRect?

    public init(location: AgendaPlacement, frame: CGRect?) {
        self.location = location
        self.frame = frame
    }
}

/// Geometry-only attachment policy. It does not inspect displays or AppKit state.
public enum AgendaPlacementCalculator {
    public static let wingWidth: CGFloat = 220
    public static let gap: CGFloat = 10
    public static let requiredFreeWidth: CGFloat = wingWidth + gap

    public static func calculate(
        mainFrame: CGRect,
        visibleFrame: CGRect,
        wingSize: CGSize = CGSize(width: wingWidth, height: 580)
    ) -> AgendaPlacementResult {
        let rightFree = max(visibleFrame.maxX - mainFrame.maxX, 0)
        if rightFree >= requiredFreeWidth {
            return AgendaPlacementResult(
                location: .right,
                frame: clampedFrame(
                    origin: CGPoint(x: mainFrame.maxX + gap, y: mainFrame.maxY - wingSize.height),
                    size: wingSize,
                    visibleFrame: visibleFrame
                )
            )
        }

        let leftFree = max(mainFrame.minX - visibleFrame.minX, 0)
        if leftFree >= requiredFreeWidth {
            return AgendaPlacementResult(
                location: .left,
                frame: clampedFrame(
                    origin: CGPoint(x: mainFrame.minX - gap - wingSize.width, y: mainFrame.maxY - wingSize.height),
                    size: wingSize,
                    visibleFrame: visibleFrame
                )
            )
        }

        return AgendaPlacementResult(location: .popover, frame: nil)
    }

    private static func clampedFrame(origin: CGPoint, size: CGSize, visibleFrame: CGRect) -> CGRect {
        let width = min(size.width, visibleFrame.width)
        let height = min(size.height, visibleFrame.height)
        let maxX = visibleFrame.maxX - width
        let maxY = visibleFrame.maxY - height
        return CGRect(
            x: min(max(origin.x, visibleFrame.minX), maxX),
            y: min(max(origin.y, visibleFrame.minY), maxY),
            width: width,
            height: height
        )
    }
}
