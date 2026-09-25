import AppKit
import QuartzCore
import SwiftUI
import TimeZonerLib

private final class FloatingPanelSurfaceAdapter: CalendarPanelSurface {
    private let panel: FloatingPanel

    init(panel: FloatingPanel) {
        self.panel = panel
    }

    var frame: CGRect { panel.frame }
    var isVisible: Bool { panel.isVisible }
    var isKey: Bool { panel.isKeyWindow }

    func show() {
        panel.orderFront(nil)
    }

    func hide() {
        panel.orderOut(nil)
    }

    func focus() {
        panel.makeKey()
    }

    func setFrame(_ frame: CGRect) {
        panel.setFrame(frame, display: true, animate: false)
    }
}

private final class AgendaPopoverSurfaceAdapter: NSObject, CalendarPanelPopoverSurface {
    private let popover: NSPopover
    private weak var anchorPanel: FloatingPanel?

    init(popover: NSPopover, anchorPanel: FloatingPanel) {
        self.popover = popover
        self.anchorPanel = anchorPanel
    }

    var isPresented: Bool { popover.isShown }
    var isFocused: Bool {
        popover.contentViewController?.view.window?.isKeyWindow == true
    }

    func show() {
        guard !popover.isShown,
              let anchor = anchorPanel?.contentView else { return }
        popover.show(relativeTo: anchor.bounds, of: anchor, preferredEdge: .maxX)
    }

    func dismiss() {
        guard popover.isShown else { return }
        popover.performClose(nil)
    }

    func focus() {
        popover.contentViewController?.view.window?.makeKeyAndOrderFront(nil)
    }
}

private struct NativeWorkspaceTarget {
    let destination: CalendarDestination
    let main: CGRect
    let calendar: CGRect
    let workspace: CalendarWorkspaceFrames?
    let restoration: CalendarWorkspaceRestoration?
}

/// AppKit adapter for the pure paired-panel policy in TimeZonerLib.
@MainActor
final class CalendarPanelCoordinator: NSObject, CalendarPanelControlling {
    let mainPanel: FloatingPanel
    let agendaPanel: FloatingPanel

    private let agendaPopover: NSPopover
    private let presentation: CalendarPresentationState
    private let pair: CalendarPanelPairController
    private let cityCount: () -> Int
    private let prepareCalendar: () -> Void
    private let refreshCalendar: () -> Void
    private var observerTokens: [NSObjectProtocol] = []
    private var accessibilityDisplayObserver: NSObjectProtocol?
    private var isUpdatingAttachment = false
    private var savedNormalLayout: CalendarNormalLayoutSnapshot?
    private var transitionGate = CalendarWorkspaceTransitionGate()
    private var activeNativeTarget: NativeWorkspaceTarget?

    init(
        mainPanel: FloatingPanel,
        agendaPanel: FloatingPanel,
        agendaPopover: NSPopover,
        presentation: CalendarPresentationState,
        cityCount: @escaping () -> Int,
        prepareCalendar: @escaping () -> Void,
        refreshCalendar: @escaping () -> Void
    ) {
        self.mainPanel = mainPanel
        self.agendaPanel = agendaPanel
        self.agendaPopover = agendaPopover
        self.presentation = presentation
        self.cityCount = cityCount
        self.prepareCalendar = prepareCalendar
        self.refreshCalendar = refreshCalendar

        let mainSurface = FloatingPanelSurfaceAdapter(panel: mainPanel)
        let agendaSurface = FloatingPanelSurfaceAdapter(panel: agendaPanel)
        let popoverSurface = AgendaPopoverSurfaceAdapter(popover: agendaPopover, anchorPanel: mainPanel)
        self.pair = CalendarPanelPairController(
            main: mainSurface,
            agenda: agendaSurface,
            agendaPopover: popoverSurface,
            visibleFrame: { [weak mainPanel] in
                mainPanel?.screen?.visibleFrame
                    ?? NSScreen.screens.first(where: { $0.frame.intersects(mainPanel?.frame ?? .zero) })?.visibleFrame
                    ?? NSScreen.main?.visibleFrame
                    ?? .zero
            },
            scheduleDeferredDismissal: { work in
                RunLoop.main.perform(inModes: [.common]) {
                    work()
                }
            }
        )

        super.init()

        mainPanel.interactionDelegate = self
        agendaPanel.interactionDelegate = self
        agendaPopover.delegate = self
        presentation.mainPanelHugsMenuBar = mainPanel.isHuggingMenuBar
        presentation.agendaPanelHugsMenuBar = agendaPanel.isHuggingMenuBar
        observePanels()
    }

    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
        if let accessibilityDisplayObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(accessibilityDisplayObserver)
        }
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        pair.show(showAgenda: CalendarWorkspacePolicy.calendarVisible(
            destination: presentation.destination,
            showAgenda: presentation.showAgendaWing
        ))
    }

    func hide() {
        settleWorkspaceTransition()
        presentation.isSettingsPresented = false
        presentation.attendeePopoverEventID = nil
        pair.setOwnedPopoverPresented(false)
        pair.hide()
        presentation.focusedPanel = nil
    }

    func toggle() {
        if mainPanel.isVisible {
            hide()
        } else {
            show()
        }
    }

    func syncAgendaVisibility() {
        updateAttachment {
            pair.syncAgendaVisibility(
                showAgenda: CalendarWorkspacePolicy.calendarVisible(
                    destination: presentation.destination,
                    showAgenda: presentation.showAgendaWing
                )
            )
        }
    }

    @discardableResult
    func focusAgenda() -> CalendarAgendaFocusTarget? {
        pair.focusAgenda()
    }

    func resizeMain(to size: CGSize) {
        guard presentation.destination == .timezoner else { return }
        updateAttachment {
            pair.resizeMain(to: size, showAgenda: presentation.showAgendaWing)
        }
    }

    func enterCalendarMode() {
        requestTransition(to: .calendar)
    }

    func returnToTimeZoner() {
        requestTransition(to: .timezoner)
    }

    func restoreTimeZonerImmediately() {
        settleWorkspaceTransition()
        guard let target = target(for: .timezoner) else { return }
        closeOwnedPopovers()
        prepareContent(for: target)
        completeFrames(target, focus: false)
        mainPanel.persistsNormalPosition = true
        refreshCalendar()
        NotificationCenter.default.post(name: .focusChatField, object: nil)
    }

    func settleWorkspaceTransition() {
        guard let destination = transitionGate.cancel() else { return }
        let settled = activeNativeTarget?.destination == destination
            ? activeNativeTarget
            : target(for: destination)
        guard let settled else { return }

        activeNativeTarget = nil
        prepareContent(for: settled)
        NSAnimationContext.runAnimationGroup { context in
            // Replacing an animator target in a zero-duration transaction cancels the in-flight
            // frame animation. A direct setter alone does not clear AppKit's animator state.
            context.duration = 0
            mainPanel.animator().setFrame(settled.main, display: true)
            agendaPanel.animator().setFrame(settled.calendar, display: true)
        }
        completeFrames(settled, focus: false)
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            presentation.workspaceContentOpacity = 1
            presentation.workspaceContentOffset = 0
            presentation.isWorkspaceTransitioning = false
        }
        pair.setTransitionInProgress(false)
        mainPanel.persistsNormalPosition = destination == .timezoner
    }

    func setOwnedPopoverPresented(_ isPresented: Bool) {
        pair.setOwnedPopoverPresented(isPresented)
    }

    func focusTimeZoner() {
        pair.focusTimeZoner()
    }

    func toggleSettings() {
        let opening = !presentation.isSettingsPresented
        if opening {
            switch CalendarWorkspacePolicy.settingsOwner(destination: presentation.destination) {
            case .timezoner:
                mainPanel.makeKey()
            case .calendar:
                agendaPanel.makeKey()
            }
        }
        presentation.isSettingsPresented = opening
        pair.setOwnedPopoverPresented(presentation.hasOwnedPopover)
    }

    func handleEscape() {
        hide()
    }

    private func requestTransition(to destination: CalendarDestination) {
        if transitionGate.active == nil && presentation.destination == destination { return }
        guard let request = transitionGate.begin(to: destination) else {
            // The pure gate recorded the latest destination for the active timeline. Its
            // current callback must remain valid so it can finish, then begin that target.
            return
        }
        guard let target = target(for: destination) else {
            _ = transitionGate.cancel()
            return
        }

        activeNativeTarget = target
        pair.setTransitionInProgress(true)
        presentation.isWorkspaceTransitioning = true
        mainPanel.persistsNormalPosition = false
        closeOwnedPopovers()

        let motion = CalendarWorkspaceMotion(
            reduceMotion: NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        )
        withAnimation(.easeOut(duration: motion.fadeOut)) {
            presentation.workspaceContentOpacity = 0
        }

        Task { @MainActor [weak self] in
            let nanoseconds = UInt64((motion.fadeOut * 1_000_000_000).rounded())
            try? await Task.sleep(nanoseconds: nanoseconds)
            guard let self, self.transitionGate.isCurrent(request.id) else { return }

            self.prepareContent(for: target)
            self.presentation.workspaceContentOffset = destination == .calendar ? motion.travel : -motion.travel
            NSAnimationContext.runAnimationGroup { context in
                context.duration = motion.move
                context.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
                self.mainPanel.animator().setFrame(target.main, display: true)
                self.agendaPanel.animator().setFrame(target.calendar, display: true)
            } completionHandler: { [weak self] in
                Task { @MainActor [weak self] in
                    guard let self, self.transitionGate.isCurrent(request.id) else { return }
                    self.completeFrames(target, focus: false)
                    withAnimation(.easeOut(duration: motion.fadeIn)) {
                        self.presentation.workspaceContentOpacity = 1
                        self.presentation.workspaceContentOffset = 0
                    }

                    let fadeNanoseconds = UInt64((motion.fadeIn * 1_000_000_000).rounded())
                    try? await Task.sleep(nanoseconds: fadeNanoseconds)
                    guard self.transitionGate.isCurrent(request.id) else { return }

                    let next = self.transitionGate.finish(request.id)
                    self.activeNativeTarget = nil
                    self.presentation.isWorkspaceTransitioning = false
                    self.pair.setTransitionInProgress(false)
                    self.mainPanel.persistsNormalPosition = destination == .timezoner
                    self.focusCompletedTarget(destination)
                    if let next {
                        self.requestTransition(to: next)
                    }
                }
            }
        }
    }

    private func target(for destination: CalendarDestination) -> NativeWorkspaceTarget? {
        if destination == .calendar {
            if savedNormalLayout == nil {
                savedNormalLayout = CalendarNormalLayoutSnapshot(
                    main: mainPanel.frame,
                    agenda: agendaPanel.isVisible ? agendaPanel.frame : nil,
                    placement: pair.placement,
                    screenID: screenIdentifier(for: mainPanel.screen)?.stringValue,
                    visibleFrame: visibleFrame(),
                    cityCount: cityCount()
                )
            }
            guard let saved = savedNormalLayout else { return nil }
            let frames = CalendarWorkspaceLayout.calculate(
                main: saved.main,
                agenda: saved.agenda,
                placement: saved.placement,
                visibleFrame: visibleFrame()
            )
            return NativeWorkspaceTarget(
                destination: .calendar,
                main: frames.main,
                calendar: frames.calendar,
                workspace: frames,
                restoration: nil
            )
        }

        guard let saved = savedNormalLayout else { return nil }
        let visible = visibleFrame()
        let restored = CalendarWorkspaceLayout.restore(
            saved,
            visibleFrame: visible,
            screenID: screenIdentifier(for: mainPanel.screen)?.stringValue,
            cityCount: cityCount()
        )
        return NativeWorkspaceTarget(
            destination: .timezoner,
            main: restored.main,
            calendar: restored.agenda.frame ?? temporaryAgendaFrame(around: restored.main, visibleFrame: visible),
            workspace: nil,
            restoration: restored
        )
    }

    private func prepareContent(for target: NativeWorkspaceTarget) {
        if target.destination == .calendar {
            if presentation.destination != .calendar {
                prepareCalendar()
            }
            if let frames = target.workspace {
                // A normal popover has no window frame. Give the hidden real panel a clamped
                // on-screen start before promotion so the first animator transaction never
                // exposes a frame-zero flash.
                if pair.placement == .popover && !agendaPanel.isVisible {
                    agendaPanel.setFrame(
                        temporaryAgendaFrame(around: mainPanel.frame, visibleFrame: visibleFrame()),
                        display: true,
                        animate: false
                    )
                }
                updateAttachment {
                    pair.beginWorkspace(frames, applyFrames: false, focusCalendar: false)
                }
            }
        } else {
            presentation.returnToTimeZoner()
        }
        refreshCalendar()
    }

    private func completeFrames(_ target: NativeWorkspaceTarget, focus: Bool) {
        updateAttachment {
            if let frames = target.workspace {
                pair.beginWorkspace(frames, applyFrames: true, focusCalendar: focus)
            } else if let restored = target.restoration {
                pair.endWorkspace(restored, showAgenda: presentation.showAgendaWing, focusMain: focus)
                savedNormalLayout = nil
            }
        }
        updateHuggingForFinalFrames()
    }

    private func focusCompletedTarget(_ destination: CalendarDestination) {
        guard mainPanel.isVisible else { return }
        if destination == .calendar {
            agendaPanel.makeKey()
        } else {
            mainPanel.makeKey()
            NotificationCenter.default.post(name: .focusChatField, object: nil)
        }
    }

    private func temporaryAgendaFrame(around main: CGRect, visibleFrame: CGRect) -> CGRect {
        let width = min(CGFloat(220), visibleFrame.width)
        let height = min(CGFloat(580), visibleFrame.height)
        return CGRect(
            x: min(max(main.maxX + 10, visibleFrame.minX), visibleFrame.maxX - width),
            y: min(max(main.maxY - height, visibleFrame.minY), visibleFrame.maxY - height),
            width: width,
            height: height
        )
    }

    private func updateHuggingForFinalFrames() {
        let mainVisible = visibleFrame()
        let agendaVisible = agendaPanel.screen?.visibleFrame
            ?? NSScreen.screens.first(where: { $0.frame.intersects(agendaPanel.frame) })?.visibleFrame
            ?? mainVisible
        presentation.mainPanelHugsMenuBar = abs(mainPanel.frame.maxY - mainVisible.maxY) < 30
        presentation.agendaPanelHugsMenuBar = abs(agendaPanel.frame.maxY - agendaVisible.maxY) < 30
    }

    private func observePanels() {
        let center = NotificationCenter.default
        let names = [
            NSWindow.didMoveNotification,
            NSWindow.didResizeNotification,
            NSWindow.didChangeScreenNotification,
        ]
        for panel in [mainPanel, agendaPanel] {
            for name in names {
                observerTokens.append(center.addObserver(forName: name, object: panel, queue: .main) { [weak self, weak panel] _ in
                    guard let panel else { return }
                    Task { @MainActor [weak self] in
                        self?.panelFrameChanged(panel, screenChanged: name == NSWindow.didChangeScreenNotification)
                    }
                })
            }
        }
        observerTokens.append(center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.settleWorkspaceTransition()
                self?.pair.applicationDidResignActive()
            }
        })
        observerTokens.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.screenParametersChanged()
            }
        })

        accessibilityDisplayObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.accessibilityDisplayOptionsDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.settleWorkspaceTransition()
            }
        }
    }

    private func panelFrameChanged(_ panel: FloatingPanel, screenChanged: Bool) {
        guard !isUpdatingAttachment else { return }
        if presentation.isWorkspaceTransitioning {
            guard screenChanged else { return }
            settleWorkspaceTransition()
        }
        guard let frames = pair.workspaceFrames else {
            if panel === mainPanel { syncAgendaVisibility() }
            return
        }
        let oldFrame = panel === mainPanel ? frames.main : frames.calendar
        let screen = panel.screen?.visibleFrame ?? visibleFrame()
        let adjusted: CalendarWorkspaceFrames
        if screenChanged {
            adjusted = CalendarWorkspaceLayout.calculate(
                main: mainPanel.frame,
                agenda: agendaPanel.frame,
                placement: .right,
                visibleFrame: screen
            )
        } else {
            adjusted = CalendarWorkspaceLayout.translated(
                frames,
                by: CGSize(
                    width: panel.frame.minX - oldFrame.minX,
                    height: panel.frame.minY - oldFrame.minY
                ),
                visibleFrame: screen
            )
        }
        updateAttachment {
            pair.beginWorkspace(adjusted, focusCalendar: false)
        }
    }

    private func screenParametersChanged() {
        settleWorkspaceTransition()
        guard pair.workspaceFrames != nil else { return }
        let visible = visibleFrame()
        let adjusted = CalendarWorkspaceLayout.calculate(
            main: mainPanel.frame,
            agenda: agendaPanel.frame,
            placement: .right,
            visibleFrame: visible
        )
        updateAttachment {
            pair.beginWorkspace(adjusted, focusCalendar: false)
        }
    }

    private func updateAttachment(_ operation: () -> Void) {
        guard !isUpdatingAttachment else { return }
        isUpdatingAttachment = true
        operation()
        isUpdatingAttachment = false
    }

    private func visibleFrame() -> CGRect {
        mainPanel.screen?.visibleFrame
            ?? NSScreen.screens.first(where: { $0.frame.intersects(mainPanel.frame) })?.visibleFrame
            ?? NSScreen.main?.visibleFrame
            ?? .zero
    }

    private func screenIdentifier(for screen: NSScreen?) -> NSNumber? {
        screen?.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber
    }

    private func closeOwnedPopovers() {
        presentation.isSettingsPresented = false
        presentation.eventDetailPopoverTarget = nil
        pair.setOwnedPopoverPresented(false)
    }
}

extension CalendarPanelCoordinator: FloatingPanelInteractionDelegate {
    nonisolated func floatingPanelDidBecomeKey(_ panel: FloatingPanel) {
        Task { @MainActor [weak self, weak panel] in
            guard let self, let panel else { return }
            self.presentation.focusedPanel = panel === self.mainPanel ? .timezoner : .calendar
        }
    }

    nonisolated func floatingPanelDidResignKey(_ panel: FloatingPanel) {
        Task { @MainActor [weak self] in
            self?.pair.panelDidResignKey()
        }
    }

    nonisolated func floatingPanelDidPressEscape(_ panel: FloatingPanel) {
        Task { @MainActor [weak self] in
            self?.handleEscape()
        }
    }

    nonisolated func floatingPanelDidChangeOrdering(_ panel: FloatingPanel) {
        Task { @MainActor [weak self, weak panel] in
            guard let self, let panel else { return }
            if !self.mainPanel.isVisible && !self.agendaPanel.isVisible {
                self.presentation.focusedPanel = nil
            }
            if panel === self.mainPanel {
                self.syncAgendaVisibility()
            }
        }
    }

    nonisolated func floatingPanel(_ panel: FloatingPanel, didChangeHugging hugging: Bool) {
        Task { @MainActor [weak self] in
            guard let self, !self.presentation.isWorkspaceTransitioning else { return }
            // This callback may have been emitted mid-animation but delivered after the
            // coordinator's final transaction. Never apply its stale bool; both corners must
            // instead reflect the actual settled frames and their current visible tops.
            self.updateHuggingForFinalFrames()
        }
    }
}

extension CalendarPanelCoordinator: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        pair.setOwnedPopoverPresented(presentation.hasOwnedPopover)
    }
}
