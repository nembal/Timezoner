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
}

/// AppKit adapter for the pure paired-panel policy in TimeZonerLib.
final class CalendarPanelCoordinator: NSObject, CalendarPanelControlling {
    let mainPanel: FloatingPanel
    let agendaPanel: FloatingPanel

    private let agendaPopover: NSPopover
    private let presentation: CalendarPresentationState
    private let pair: CalendarPanelPairController
    private var observerTokens: [NSObjectProtocol] = []
    private var isUpdatingAttachment = false
    private var savedNormalFrame: CGRect?
    private var savedNormalScreenIdentifier: NSNumber?

    init(
        mainPanel: FloatingPanel,
        agendaPanel: FloatingPanel,
        agendaPopover: NSPopover,
        presentation: CalendarPresentationState
    ) {
        self.mainPanel = mainPanel
        self.agendaPanel = agendaPanel
        self.agendaPopover = agendaPopover
        self.presentation = presentation

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
        observeMainPanel()
    }

    deinit {
        observerTokens.forEach(NotificationCenter.default.removeObserver)
    }

    func show() {
        NSApp.activate(ignoringOtherApps: true)
        pair.show(showAgenda: presentation.destination == .timezoner && presentation.showAgendaWing)
    }

    func hide() {
        presentation.isSettingsPresented = false
        presentation.attendeePopoverEventID = nil
        pair.setOwnedPopoverPresented(false)
        pair.hide()
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
                showAgenda: presentation.destination == .timezoner && presentation.showAgendaWing
            )
        }
    }

    func resizeMain(to size: CGSize) {
        guard presentation.destination == .timezoner else { return }
        updateAttachment {
            pair.resizeMain(to: size, showAgenda: presentation.showAgendaWing)
        }
    }

    func enterCalendarMode() {
        guard savedNormalFrame == nil else { return }
        savedNormalFrame = mainPanel.frame
        savedNormalScreenIdentifier = screenIdentifier(for: mainPanel.screen)
        updateAttachment {
            pair.syncAgendaVisibility(showAgenda: false)
            mainPanel.setFrame(
                CalendarPanelFrameCalculator.calendarFrame(
                    normalFrame: mainPanel.frame,
                    visibleFrame: visibleFrame()
                ),
                display: true,
                animate: false
            )
        }
    }

    func returnToTimeZoner() {
        guard let savedNormalFrame else { return }
        updateAttachment {
            let screenDidChange = savedNormalScreenIdentifier != screenIdentifier(for: mainPanel.screen)
            mainPanel.setFrame(
                CalendarPanelFrameCalculator.restoredNormalFrame(
                    savedNormalFrame,
                    visibleFrame: visibleFrame(),
                    screenDidChange: screenDidChange
                ),
                display: true,
                animate: false
            )
            self.savedNormalFrame = nil
            self.savedNormalScreenIdentifier = nil
            pair.syncAgendaVisibility(showAgenda: presentation.showAgendaWing)
        }
    }

    func setOwnedPopoverPresented(_ isPresented: Bool) {
        pair.setOwnedPopoverPresented(isPresented)
    }

    func handleEscape() {
        hide()
    }

    private func observeMainPanel() {
        let center = NotificationCenter.default
        for name in [
            NSWindow.didMoveNotification,
            NSWindow.didResizeNotification,
            NSWindow.didChangeScreenNotification,
        ] {
            observerTokens.append(center.addObserver(forName: name, object: mainPanel, queue: .main) { [weak self] _ in
                self?.syncAgendaVisibility()
            })
        }
        observerTokens.append(center.addObserver(
            forName: NSApplication.didResignActiveNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.pair.applicationDidResignActive()
        })
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
}

extension CalendarPanelCoordinator: FloatingPanelInteractionDelegate {
    func floatingPanelDidResignKey(_ panel: FloatingPanel) {
        pair.panelDidResignKey()
    }

    func floatingPanelDidPressEscape(_ panel: FloatingPanel) {
        handleEscape()
    }

    func floatingPanelDidChangeOrdering(_ panel: FloatingPanel) {
        guard panel === mainPanel else { return }
        syncAgendaVisibility()
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
