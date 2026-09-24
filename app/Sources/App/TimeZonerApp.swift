import AppKit
import SwiftUI
import TimeZonerLib
import UserNotifications

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
    func focusAgenda() -> CalendarAgendaFocusTarget? { target?.focusAgenda() }
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
    private let calendarProvider: EventKitCalendarProvider
    private let notificationCenter: UserNotificationCenterAdapter
    private let zoneStore: ZoneStore
    private lazy var notificationScheduler: CalendarNotificationScheduler = {
        CalendarNotificationScheduler(
            eventReader: calendarProvider,
            preferenceStore: calendarPreferences,
            notificationCenter: notificationCenter,
            leadMinutes: { [settings] in settings.notificationLeadMinutes }
        )
    }()
    private lazy var calendarAlertLifecycle: CalendarAlertLifecycleCoordinator = {
        CalendarAlertLifecycleCoordinator(
            settings: settings,
            preferenceStore: calendarPreferences,
            calendarClock: calendarClock,
            scheduler: notificationScheduler,
            notificationCenter: notificationCenter
        )
    }()
    private lazy var calendarStore: CalendarStore = {
        CalendarStore(
            provider: calendarProvider,
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
                guard let self else { return }
                CalendarPermissionLossCoordinator.handle(
                    referenceMoment: self.referenceMoment,
                    presentation: self.presentation
                )
                self.panelCoordinator?.syncAgendaVisibility()
            },
            onRemoveCalendarNotifications: { [weak self] in
                Task { @MainActor [weak self] in
                    await self?.calendarAlertLifecycle.calendarPermissionDidBecomeUnavailable()
                }
            },
            onCalendarProviderChange: { [weak self] in
                self?.calendarAlertLifecycle.requestReconciliation()
            },
            onHourTick: { [weak self] in
                self?.calendarAlertLifecycle.requestReconciliation()
            },
            onTimeZoneChange: { [weak self] in
                self?.calendarAlertLifecycle.requestReconciliation()
            }
        )
    }()
    private lazy var calendarNotificationRouter: CalendarNotificationCommandRouter = {
        CalendarNotificationCommandRouter(
            resolveEvent: { [weak self] occurrenceID, startDate in
                guard let self else { return nil }
                return await self.calendarStore.event(matching: occurrenceID, near: startDate)
            },
            prepareTimeZonerSurface: { [weak self] in
                self?.restoreTimeZonerSurfaceForNotification()
            },
            showPairedPanels: { [weak self] in
                self?.panelCoordinator?.show()
            },
            selectEvent: { [weak self] event, sourceZone in
                self?.referenceMoment.selectEvent(event, sourceZone: sourceZone)
            },
            selectFallback: { [weak self] occurrenceID, title, startDate, sourceZone in
                self?.referenceMoment.selectEvent(
                    occurrenceID: occurrenceID,
                    title: title,
                    startDate: startDate,
                    sourceZone: sourceZone
                )
            },
            focusSelectedEventContext: { [weak self] in
                self?.focusSelectedEventContext()
            }
        )
    }()
    private lazy var calendarCommandQueue: PendingCalendarCommandQueue = {
        PendingCalendarCommandQueue { [weak self] command in
            guard let self else { return }
            await self.calendarNotificationRouter.route(command)
        }
    }()

    private var panelCoordinator: CalendarPanelCoordinator?
    private var permissionProbePanel: FloatingPanel?
    private var statusItem: NSStatusItem!
    private var notificationDelegate: CalendarNotificationDelegate?

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
        self.calendarProvider = EventKitCalendarProvider()
        self.notificationCenter = UserNotificationCenterAdapter()
        self.zoneStore = ZoneStore()
        super.init()
    }

    func applicationWillFinishLaunching(_ notification: Notification) {
        let delegate = CalendarNotificationDelegate { [weak self] command in
            self?.calendarCommandQueue.enqueue(command)
        }
        notificationDelegate = delegate
        UNUserNotificationCenter.current().delegate = delegate
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
            // Both hosting views and both paired surfaces now exist, so cold-start alert responses
            // can leave their in-memory queue exactly once.
            calendarCommandQueue.markReady()
            refreshPersistedAgendaIfNeeded()
        }

        Task { @MainActor [weak self] in
            await self?.calendarAlertLifecycle.resolveLaunchAuthorization()
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
            calendarAlertLifecycle: calendarAlertLifecycle,
            panelController: panelProxy,
            setAgendaWingRequested: { [weak self] requested in
                self?.setAgendaWingRequested(requested)
            },
            openCalendarPrivacySettings: { [weak self] in
                self?.openCalendarPrivacySettings()
            },
            openNotificationSettings: { [weak self] in
                self?.openNotificationSettings()
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

    private func openNotificationSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.notifications") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    /// Notification activation must leave full Calendar mode before its selected-event context
    /// can be rendered and focused in the TimeZoner surface.
    private func restoreTimeZonerSurfaceForNotification() {
        guard presentation.destination == .calendar else { return }
        presentation.returnToTimeZoner()
        if presentation.showAgendaWing,
           calendarStore.authorizationStatus == .fullAccess {
            calendarStore.refreshPresentationInterval()
        }
        panelCoordinator?.returnToTimeZoner()
    }

    private func focusSelectedEventContext() {
        NotificationCenter.default.post(name: .focusSelectedEventContext, object: nil)
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
