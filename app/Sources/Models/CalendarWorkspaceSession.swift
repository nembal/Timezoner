import Foundation

/// Owns the normal-panel layout for one calendar workspace visit.
public struct CalendarWorkspaceSession {
    public private(set) var normalLayoutSnapshot: CalendarNormalLayoutSnapshot?

    public init() {}

    public mutating func calendarTarget(
        main: CGRect,
        agenda: CGRect?,
        placement: AgendaPlacement,
        visibleFrame: CGRect,
        screenID: String?,
        cityCount: Int
    ) -> CalendarWorkspaceFrames {
        if normalLayoutSnapshot == nil {
            normalLayoutSnapshot = CalendarNormalLayoutSnapshot(
                main: main,
                agenda: agenda,
                placement: placement,
                screenID: screenID,
                visibleFrame: visibleFrame,
                cityCount: cityCount
            )
        }

        return CalendarWorkspaceLayout.calculate(
            main: main,
            agenda: agenda,
            placement: placement,
            visibleFrame: visibleFrame
        )
    }

    public func timeZonerRestoration(
        visibleFrame: CGRect,
        screenID: String?,
        cityCount: Int
    ) -> CalendarWorkspaceRestoration? {
        guard let normalLayoutSnapshot else { return nil }
        return CalendarWorkspaceLayout.restore(
            normalLayoutSnapshot,
            visibleFrame: visibleFrame,
            screenID: screenID,
            cityCount: cityCount
        )
    }

    public mutating func finishTimeZonerRestoration() {
        normalLayoutSnapshot = nil
    }
}

/// Keeps the observable main-window focus and SwiftUI chat-focus request in one ordering seam.
public enum CalendarWorkspaceFocusOrder {
    public static func restoreTimeZonerChat(
        mainPanelIsVisible: Bool,
        makeMainPanelKey: () -> Void,
        postFocusChat: () -> Void
    ) {
        if mainPanelIsVisible {
            makeMainPanelKey()
        }
        postFocusChat()
    }
}

/// Records a transition cancellation before the native coordinator settles its final frames.
public struct CalendarWorkspaceTransitionCancellation: Equatable, Sendable {
    public let targetDestination: CalendarDestination?
    public let persistenceDestination: CalendarDestination

    public init(
        cancelling gate: inout CalendarWorkspaceTransitionGate,
        currentPresentationDestination: CalendarDestination
    ) {
        targetDestination = gate.cancel()
        persistenceDestination = targetDestination ?? currentPresentationDestination
    }

    public func releaseInteractionGates(
        resetSwiftUI: () -> Void,
        resetPair: () -> Void
    ) {
        resetSwiftUI()
        resetPair()
    }
}
