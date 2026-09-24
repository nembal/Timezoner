import Foundation

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
    public var attendeePopoverEventID: String?
    public var accessDestination: AccessDestination = .none
    public var mainPanelHugsMenuBar = true
    public var agendaPanelHugsMenuBar = true

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
        isSettingsPresented || attendeePopoverEventID != nil
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
}

public enum AgendaPlacement: Equatable, Sendable {
    case right
    case left
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

/// AppKit-free panel surface used by the pair controller and its deterministic tests.
public protocol CalendarPanelSurface: AnyObject {
    var frame: CGRect { get }
    var isVisible: Bool { get }
    var isKey: Bool { get }

    func show()
    func hide()
    func focus()
    func setFrame(_ frame: CGRect)
}

public protocol CalendarPanelPopoverSurface: AnyObject {
    var isPresented: Bool { get }
    func show()
    func dismiss()
}

/// Pure paired-panel policy. The executable target supplies AppKit adapters and notification
/// observation; this type contains the behavior that must stay deterministic across displays.
public final class CalendarPanelPairController {
    public typealias DeferredDismissalScheduler = (@escaping () -> Void) -> Void

    private let main: any CalendarPanelSurface
    private let agenda: any CalendarPanelSurface
    private let agendaPopover: any CalendarPanelPopoverSurface
    private let visibleFrame: () -> CGRect
    private let scheduleDeferredDismissal: DeferredDismissalScheduler
    private var ownedPopoverPresented = false
    private var dismissalCheckPending = false

    public private(set) var placement: AgendaPlacement = .popover

    public init(
        main: any CalendarPanelSurface,
        agenda: any CalendarPanelSurface,
        agendaPopover: any CalendarPanelPopoverSurface,
        visibleFrame: @escaping () -> CGRect,
        scheduleDeferredDismissal: @escaping DeferredDismissalScheduler = { work in
            DispatchQueue.main.async(execute: work)
        }
    ) {
        self.main = main
        self.agenda = agenda
        self.agendaPopover = agendaPopover
        self.visibleFrame = visibleFrame
        self.scheduleDeferredDismissal = scheduleDeferredDismissal
    }

    public func show(showAgenda: Bool) {
        main.show()
        syncAgendaVisibility(showAgenda: showAgenda)
        main.focus()
    }

    public func hide() {
        ownedPopoverPresented = false
        agendaPopover.dismiss()
        agenda.hide()
        main.hide()
    }

    public func toggle(showAgenda: Bool) {
        if main.isVisible {
            hide()
        } else {
            show(showAgenda: showAgenda)
        }
    }

    public func syncAgendaVisibility(showAgenda: Bool) {
        guard main.isVisible else {
            agendaPopover.dismiss()
            agenda.hide()
            return
        }

        guard showAgenda else {
            agendaPopover.dismiss()
            agenda.hide()
            return
        }

        let result = AgendaPlacementCalculator.calculate(
            mainFrame: main.frame,
            visibleFrame: visibleFrame(),
            wingSize: agenda.frame.size
        )
        placement = result.location

        switch result.location {
        case .right, .left:
            agendaPopover.dismiss()
            if let frame = result.frame {
                agenda.setFrame(frame)
            }
            agenda.show()
        case .popover:
            agenda.hide()
            agendaPopover.show()
        }
    }

    public func resizeMain(to size: CGSize, showAgenda: Bool = true) {
        let oldFrame = main.frame
        let frame = CGRect(
            x: oldFrame.midX - size.width / 2,
            y: oldFrame.midY - size.height / 2,
            width: size.width,
            height: size.height
        )
        main.setFrame(frame)
        syncAgendaVisibility(showAgenda: showAgenda)
    }

    public func panelDidChangeFrame(showAgenda: Bool) {
        syncAgendaVisibility(showAgenda: showAgenda)
    }

    public func setOwnedPopoverPresented(_ isPresented: Bool) {
        ownedPopoverPresented = isPresented
        if !isPresented {
            panelDidResignKey()
        }
    }

    public func panelDidResignKey() {
        guard !dismissalCheckPending else { return }
        dismissalCheckPending = true
        scheduleDeferredDismissal { [weak self] in
            guard let self else { return }
            self.dismissalCheckPending = false
            guard self.main.isVisible else { return }
            guard !self.main.isKey,
                  !self.agenda.isKey,
                  !self.agendaPopover.isPresented,
                  !self.ownedPopoverPresented else { return }
            self.hide()
        }
    }

    public func handleEscape() {
        hide()
    }
}

public protocol CalendarPanelControlling: AnyObject {
    func show()
    func hide()
    func toggle()
    func syncAgendaVisibility()
    func resizeMain(to size: CGSize)
    func setOwnedPopoverPresented(_ isPresented: Bool)
    func handleEscape()
}
