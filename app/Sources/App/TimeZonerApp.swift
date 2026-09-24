import AppKit
import SwiftUI
import TimeZonerLib

@main
struct TimeZonerApp {
    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

private final class CalendarPanelControllerProxy: CalendarPanelControlling {
    weak var target: (any CalendarPanelControlling)?

    func show() { target?.show() }
    func hide() { target?.hide() }
    func toggle() { target?.toggle() }
    func syncAgendaVisibility() { target?.syncAgendaVisibility() }
    func resizeMain(to size: CGSize) { target?.resizeMain(to: size) }
    func enterCalendarMode() { target?.enterCalendarMode() }
    func returnToTimeZoner() { target?.returnToTimeZoner() }
    func setOwnedPopoverPresented(_ isPresented: Bool) { target?.setOwnedPopoverPresented(isPresented) }
    func handleEscape() { target?.handleEscape() }
}

@MainActor
class AppDelegate: NSObject, NSApplicationDelegate {
    private let settings: SettingsStore
    private let presentation: CalendarPresentationState
    private let timeState: TimeState
    private let referenceMoment: ReferenceMomentController
    private let calendarPreferences: CalendarPreferenceStore
    private let calendarClock: CalendarClock
    private let zoneStore: ZoneStore
    private lazy var calendarStore: CalendarStore = {
        CalendarStore(
            preferenceStore: calendarPreferences,
            clock: calendarClock,
            intervalBuilder: { [presentation] now, calendar in
                switch presentation.destination {
                case .timezoner:
                    return CalendarStore.agendaInterval(for: now, calendar: calendar)
                case .calendar:
                    return presentation.activeInterval(calendar: calendar)
                }
            },
            onPermissionLost: { [weak self] in
                self?.referenceMoment.clearSelectedEvent()
                self?.presentation.attendeePopoverEventID = nil
                self?.presentation.showAgendaWing = false
                self?.presentation.presentRecovery()
                self?.panelCoordinator?.syncAgendaVisibility()
            }
        )
    }()

    private var panelCoordinator: CalendarPanelCoordinator?
    private var permissionProbePanel: FloatingPanel?
    private var statusItem: NSStatusItem!

    override init() {
        let settings = SettingsStore.shared
        let presentation = CalendarPresentationState(settings: settings)
        let timeState = TimeState()

        self.settings = settings
        self.presentation = presentation
        self.timeState = timeState
        self.referenceMoment = ReferenceMomentController(timeState: timeState, presentation: presentation)
        self.calendarPreferences = CalendarPreferenceStore()
        self.calendarClock = CalendarClock()
        self.zoneStore = ZoneStore()
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        settings.applyAppearance()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "clock.fill", accessibilityDescription: "TimeZoner")
            button.action = #selector(togglePanel)
            button.target = self
        }

        if ProcessInfo.processInfo.arguments.contains("--calendar-permission-spike") {
            let contentView = NSHostingView(rootView: CalendarPermissionProbeView())
            contentView.setFrameSize(NSSize(width: 420, height: 300))
            permissionProbePanel = FloatingPanel(contentView: contentView, role: .main)
        } else {
            buildPanels()
            refreshPersistedAgendaIfNeeded()
        }

        _ = LaunchAtLogin.reconcile(desired: settings.launchAtLogin)

        HotkeyManager.shared.onTrigger = { [weak self] in self?.togglePanel() }
        HotkeyManager.shared.rebind(settings.hotkey)
        settings.onHotkeyChange = { shortcut in
            HotkeyManager.shared.rebind(shortcut)
        }

        showPanel()
    }

    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls {
            guard let deepLink = TimeZonerDeepLink.parse(url) else { continue }
            DeepLinkRouter.shared.pendingCommand = deepLink
            showPanel()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        calendarClock.reopen()
        showPanel()
        return true
    }

    @objc func togglePanel() {
        if let panelCoordinator {
            panelCoordinator.toggle()
        } else if let permissionProbePanel {
            if permissionProbePanel.isVisible {
                permissionProbePanel.orderOut(nil)
            } else {
                showPanel()
            }
        } else {
            showPanel()
        }
    }

    private func buildPanels() {
        let panelProxy = CalendarPanelControllerProxy()

        let mainView = ContentView(
            referenceMoment: referenceMoment,
            presentation: presentation,
            zoneStore: zoneStore,
            calendarStore: calendarStore,
            settings: settings,
            calendarPreferences: calendarPreferences,
            panelController: panelProxy,
            setAgendaWingRequested: { [weak self] requested in
                self?.setAgendaWingRequested(requested)
            },
            openCalendarPrivacySettings: { [weak self] in
                self?.openCalendarPrivacySettings()
            }
        )
        let mainHost = NSHostingView(rootView: mainView)
        mainHost.setFrameSize(NSSize(width: 750, height: 580))
        let mainPanel = FloatingPanel(contentView: mainHost, role: .main)

        let agendaPanel = FloatingPanel(
            contentView: NSHostingView(rootView: makeAgendaView(panelProxy: panelProxy)),
            role: .agenda
        )
        let agendaPopover = NSPopover()
        agendaPopover.behavior = .applicationDefined
        agendaPopover.contentSize = NSSize(width: AgendaPlacementCalculator.wingWidth, height: 580)
        agendaPopover.contentViewController = NSHostingController(rootView: makeAgendaView(panelProxy: panelProxy))

        let coordinator = CalendarPanelCoordinator(
            mainPanel: mainPanel,
            agendaPanel: agendaPanel,
            agendaPopover: agendaPopover,
            presentation: presentation
        )
        panelProxy.target = coordinator
        panelCoordinator = coordinator
    }

    private func makeAgendaView(panelProxy: CalendarPanelControllerProxy) -> AgendaView {
        AgendaView(
            calendarStore: calendarStore,
            referenceMoment: referenceMoment,
            presentation: presentation,
            onRequestAccess: { [weak self] in
                self?.calendarStore.requestAccess()
            },
            onOpenPrivacySettings: { [weak self] in
                panelProxy.hide()
                self?.openCalendarPrivacySettings()
            },
            onOpenWeek: { [weak self] in
                self?.openCalendarMode(panelProxy: panelProxy)
            },
            onOwnedPopoverChanged: { isPresented in
                panelProxy.setOwnedPopoverPresented(isPresented)
            },
            onEscape: {
                panelProxy.handleEscape()
            }
        )
    }

    private func openCalendarPrivacySettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Calendars") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func refreshPersistedAgendaIfNeeded() {
        guard presentation.showAgendaWing else {
            return
        }

        guard calendarStore.authorizationStatus == .fullAccess else {
            presentation.showAgendaWing = false
            return
        }

        calendarStore.refreshPresentationInterval()
    }

    private func setAgendaWingRequested(_ requested: Bool) {
        switch CalendarAgendaWingRequest.outcome(
            requested: requested,
            authorizationStatus: calendarStore.authorizationStatus
        ) {
        case .hide:
            presentation.showAgendaWing = false
            presentation.dismissAccessDestination()
        case .show:
            presentation.showAgendaWing = true
            calendarStore.refresh(interval: CalendarStore.agendaInterval(
                for: calendarStore.currentDate,
                calendar: calendarStore.localCalendar
            ))
        case .explainAccess:
            presentation.showAgendaWing = false
            presentation.presentAccessExplanation()
        case .recoverAccess:
            presentation.showAgendaWing = false
            presentation.presentRecovery()
        }
        panelCoordinator?.syncAgendaVisibility()
    }

    private func openCalendarMode(panelProxy: CalendarPanelControllerProxy) {
        guard calendarStore.authorizationStatus == .fullAccess else { return }
        presentation.enterCalendar(now: calendarStore.currentDate, calendar: calendarStore.localCalendar)
        panelProxy.enterCalendarMode()
        calendarStore.refresh(interval: presentation.activeInterval(calendar: calendarStore.localCalendar))
    }

    private func showPanel() {
        if let panelCoordinator {
            panelCoordinator.show()
        } else if let permissionProbePanel {
            permissionProbePanel.orderFront(nil)
            permissionProbePanel.makeKey()
            NSApp.activate(ignoringOtherApps: true)
        } else {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
