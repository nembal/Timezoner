import Foundation

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
    var isFocused: Bool { get }
    func show()
    func dismiss()
    func focus()
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
    private var transitionInProgress = false

    public private(set) var placement: AgendaPlacement = .popover
    public private(set) var workspaceFrames: CalendarWorkspaceFrames?

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
        if workspaceFrames == nil {
            main.focus()
        } else {
            agenda.focus()
        }
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
        guard !transitionInProgress else { return }
        if workspaceFrames != nil {
            agendaPopover.dismiss()
            if main.isVisible {
                agenda.show()
            } else {
                agenda.hide()
            }
            return
        }

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

    /// Transfers keyboard focus only to an already-visible agenda presentation. Opening and
    /// hiding remain owned by the permission-aware app coordinator.
    @discardableResult
    public func focusAgenda() -> CalendarAgendaFocusTarget? {
        guard main.isVisible else { return nil }
        switch placement {
        case .right, .left:
            guard agenda.isVisible else { return nil }
            agenda.focus()
            return .detachedPanel
        case .popover:
            guard agendaPopover.isPresented else { return nil }
            agendaPopover.focus()
            return .popover
        }
    }

    public func resizeMain(to size: CGSize, showAgenda: Bool = true) {
        guard workspaceFrames == nil, !transitionInProgress else { return }
        let oldFrame = main.frame
        let visible = visibleFrame()
        let width = visible.width > 0 ? min(size.width, visible.width) : size.width
        let desiredX = oldFrame.midX - width / 2
        let x = visible.width > 0
            ? min(max(desiredX, visible.minX), visible.maxX - width)
            : desiredX
        let frame = CGRect(
            x: x,
            y: oldFrame.maxY - size.height,
            width: width,
            height: size.height
        )
        main.setFrame(frame)
        syncAgendaVisibility(showAgenda: showAgenda)
    }

    public func panelDidChangeFrame(showAgenda: Bool) {
        syncAgendaVisibility(showAgenda: showAgenda)
    }

    public func setTransitionInProgress(_ value: Bool) {
        transitionInProgress = value
    }

    public func beginWorkspace(
        _ frames: CalendarWorkspaceFrames,
        applyFrames: Bool = true,
        focusCalendar: Bool = true
    ) {
        workspaceFrames = frames
        placement = .right
        agendaPopover.dismiss()
        if applyFrames {
            main.setFrame(frames.main)
            agenda.setFrame(frames.calendar)
        }
        main.show()
        agenda.show()
        if focusCalendar {
            agenda.focus()
        }
    }

    public func endWorkspace(
        _ restored: CalendarWorkspaceRestoration,
        showAgenda: Bool,
        focusMain: Bool = true
    ) {
        workspaceFrames = nil
        main.setFrame(restored.main)
        agenda.setFrame(restored.agenda.frame ?? CGRect(
            x: restored.main.maxX + AgendaPlacementCalculator.gap,
            y: restored.main.maxY - CalendarPanelMetrics.preferredHeight,
            width: AgendaPlacementCalculator.wingWidth,
            height: CalendarPanelMetrics.preferredHeight
        ))
        placement = restored.agenda.location
        if !showAgenda {
            agendaPopover.dismiss()
            agenda.hide()
        } else if placement == .popover {
            agenda.hide()
            agendaPopover.show()
        } else {
            agendaPopover.dismiss()
            agenda.show()
        }
        if focusMain {
            main.focus()
        }
    }

    public func focusTimeZoner(postFocusChat: (() -> Void)? = nil) {
        if main.isVisible {
            main.focus()
        }
        postFocusChat?()
    }

    /// Reopen paired-panel interactions only after the caller restores its workspace content.
    public func finishWorkspaceTransition(resetPresentation: () -> Void) {
        resetPresentation()
        transitionInProgress = false
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
            guard !self.transitionInProgress,
                  !self.main.isKey,
                  !self.agenda.isKey,
                  !self.agendaPopover.isFocused,
                  !self.ownedPopoverPresented else { return }
            if self.agendaPopover.isPresented {
                self.agendaPopover.dismiss()
            }
            self.hide()
        }
    }

    /// The app can deactivate while an application-defined popover is key, which does not
    /// guarantee either floating panel will emit another resign-key callback.
    public func applicationDidResignActive() {
        panelDidResignKey()
    }

    public func handleEscape() {
        hide()
    }
}

@MainActor
public protocol CalendarPanelControlling: AnyObject {
    func show()
    func hide()
    func toggle()
    func syncAgendaVisibility()
    @discardableResult func focusAgenda() -> CalendarAgendaFocusTarget?
    func focusTimeZoner()
    func toggleSettings()
    func resizeMain(to size: CGSize)
    func enterCalendarMode()
    func returnToTimeZoner()
    func restoreTimeZonerImmediately()
    func settleWorkspaceTransition()
    func setOwnedPopoverPresented(_ isPresented: Bool)
    func handleEscape()
}
