import AppKit
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

/// AppKit adapter for the pure paired-panel policy in TimeZonerLib.
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
    private var isUpdatingAttachment = false
    private var savedNormalLayout: CalendarNormalLayoutSnapshot?

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
                DispatchQueue.main.async(execute: work)
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
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        pair.show(showAgenda: CalendarWorkspacePolicy.calendarVisible(
            destination: presentation.destination,
            showAgenda: presentation.showAgendaWing
        ))
    }

    func hide() {
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
        guard savedNormalLayout == nil else { return }
        savedNormalLayout = CalendarNormalLayoutSnapshot(
            main: mainPanel.frame,
            agenda: agendaPanel.isVisible ? agendaPanel.frame : nil,
            placement: pair.placement,
            screenID: screenIdentifier(for: mainPanel.screen)?.stringValue,
            visibleFrame: visibleFrame(),
            cityCount: cityCount()
        )
        closeOwnedPopovers()
        mainPanel.persistsNormalPosition = false
        let frames = CalendarWorkspaceLayout.calculate(
            main: mainPanel.frame,
            agenda: agendaPanel.isVisible ? agendaPanel.frame : nil,
            placement: pair.placement,
            visibleFrame: visibleFrame()
        )
        prepareCalendar()
        updateAttachment {
            pair.beginWorkspace(frames)
        }
        refreshCalendar()
    }

    func returnToTimeZoner() {
        restoreTimeZonerImmediately()
    }

    func restoreTimeZonerImmediately() {
        guard let snapshot = savedNormalLayout else { return }
        closeOwnedPopovers()
        let restored = CalendarWorkspaceLayout.restore(
            snapshot,
            visibleFrame: visibleFrame(),
            screenID: screenIdentifier(for: mainPanel.screen)?.stringValue,
            cityCount: cityCount()
        )
        presentation.returnToTimeZoner()
        updateAttachment {
            pair.endWorkspace(restored, showAgenda: presentation.showAgendaWing)
        }
        savedNormalLayout = nil
        mainPanel.persistsNormalPosition = true
        refreshCalendar()
        NotificationCenter.default.post(name: .focusChatField, object: nil)
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
                    self?.panelFrameChanged(panel, screenChanged: name == NSWindow.didChangeScreenNotification)
                })
            }
        }
        observerTokens.append(center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pair.applicationDidResignActive()
        })
        observerTokens.append(center.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.screenParametersChanged()
        })
    }

    private func panelFrameChanged(_ panel: FloatingPanel, screenChanged: Bool) {
        guard !isUpdatingAttachment else { return }
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
    func floatingPanelDidBecomeKey(_ panel: FloatingPanel) {
        presentation.focusedPanel = panel === mainPanel ? .timezoner : .calendar
    }

    func floatingPanelDidResignKey(_ panel: FloatingPanel) {
        pair.panelDidResignKey()
    }

    func floatingPanelDidPressEscape(_ panel: FloatingPanel) {
        handleEscape()
    }

    func floatingPanelDidChangeOrdering(_ panel: FloatingPanel) {
        if !mainPanel.isVisible && !agendaPanel.isVisible {
            presentation.focusedPanel = nil
        }
        if panel === mainPanel { syncAgendaVisibility() }
    }

    func floatingPanel(_ panel: FloatingPanel, didChangeHugging hugging: Bool) {
        if panel === mainPanel {
            presentation.mainPanelHugsMenuBar = hugging
        } else if panel === agendaPanel {
            presentation.agendaPanelHugsMenuBar = hugging
        }
    }
}

extension CalendarPanelCoordinator: NSPopoverDelegate {
    func popoverDidClose(_ notification: Notification) {
        pair.setOwnedPopoverPresented(presentation.hasOwnedPopover)
    }
}
