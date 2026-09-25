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

@MainActor
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
    func restoreTimeZonerImmediately() { target?.restoreTimeZonerImmediately() }
    func settleWorkspaceTransition() { target?.settleWorkspaceTransition() }
    func focusTimeZoner() { target?.focusTimeZoner() }
    func toggleSettings() { target?.toggleSettings() }
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
            notificationCenter: notificationCenter,
            calendarAuthorizationStatus: { [weak self] in
                self?.calendarStore.authorizationStatus ?? .denied
            }
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
                self?.prepareCurrentWorkspaceForNotification()
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
            },
            fallbackPermission: { [weak self] in
                CalendarWorkspacePolicy.mayReadEvents(
                    status: self?.calendarStore.authorizationStatus ?? .denied
                )
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

        let agendaHost = CalendarPanelHosting.fixed(
            root: makeCalendarPanelRootView(panelProxy: panelProxy),
            size: CGSize(
                width: AgendaPlacementCalculator.wingWidth,
                height: CalendarPanelMetrics.preferredHeight
            )
        )
        let agendaPanel = FloatingPanel(contentView: agendaHost, role: .agenda)
        let agendaPopover = NSPopover()
        agendaPopover.behavior = .applicationDefined
        agendaPopover.contentSize = NSSize(width: AgendaPlacementCalculator.wingWidth, height: 580)
        agendaPopover.contentViewController = NSHostingController(rootView: makeAgendaView(panelProxy: panelProxy))

        let coordinator = CalendarPanelCoordinator(
            mainPanel: mainPanel,
            agendaPanel: agendaPanel,
            agendaPopover: agendaPopover,
            presentation: presentation,
            cityCount: { [zoneStore] in zoneStore.zones.count },
            prepareCalendar: { [weak self] in
                guard let self else { return }
                self.presentation.enterCalendar(
                    now: self.calendarStore.currentDate,
                    calendar: self.calendarStore.localCalendar
                )
            },
            refreshCalendar: { [weak self] in
                guard let self,
                      self.calendarStore.authorizationStatus == .fullAccess else { return }
                self.calendarStore.refreshPresentationInterval()
            }
        )
        panelProxy.target = coordinator
        panelCoordinator = coordinator
    }

    private func makeCalendarPanelRootView(panelProxy: CalendarPanelControllerProxy) -> CalendarPanelRootView {
        CalendarPanelRootView(
            presentation: presentation,
            agenda: makeAgendaView(panelProxy: panelProxy),
            calendar: makeCalendarModeView(panelProxy: panelProxy),
            onToggleSettings: panelProxy.toggleSettings,
            onFocusCalendar: { _ = panelProxy.focusAgenda() }
        )
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

    private func makeCalendarModeView(panelProxy: CalendarPanelControllerProxy) -> CalendarModeView {
        CalendarModeView(
            calendarStore: calendarStore,
            referenceMoment: referenceMoment,
            presentation: presentation,
            settingsButton: CalendarSettingsButton(
                owner: .calendar,
                presentation: presentation,
                onActivate: panelProxy.toggleSettings,
                onOwnedPopoverChanged: { isPresented in
                    panelProxy.setOwnedPopoverPresented(isPresented)
                }
            ) {
                SettingsPopover(
                    settings: settings,
                    calendarStore: calendarStore,
                    calendarPreferences: calendarPreferences,
                    calendarAlertLifecycle: calendarAlertLifecycle,
                    setAgendaWingRequested: { [weak self] requested in
                        self?.setAgendaWingRequested(requested)
                    },
                    openCalendarPrivacySettings: { [weak self] in
                        panelProxy.hide()
                        self?.openCalendarPrivacySettings()
                    },
                    openNotificationSettings: { [weak self] in
                        self?.openNotificationSettings()
                    }
                )
            },
            onOpenPrivacySettings: { [weak self] in
                panelProxy.hide()
                self?.openCalendarPrivacySettings()
            },
            onOwnedPopoverChanged: { isPresented in
                panelProxy.setOwnedPopoverPresented(isPresented)
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

    /// Notification activation keeps an already-open calendar workspace intact so the selected
    /// event and compact TimeZoner rail remain visible together.
    private func prepareCurrentWorkspaceForNotification() {
        panelCoordinator?.settleWorkspaceTransition()
        panelCoordinator?.syncAgendaVisibility()
    }

    private func focusSelectedEventContext() {
        panelCoordinator?.focusTimeZoner()
        NotificationCenter.default.post(name: .focusSelectedEventContext, object: nil)
    }

    private func refreshPersistedAgendaIfNeeded() {
        guard presentation.showAgendaWing else { return }
        guard CalendarWorkspacePolicy.mayReadEvents(status: calendarStore.authorizationStatus) else {
            return
        }
        calendarStore.refreshPresentationInterval()
    }

    private func setAgendaWingRequested(_ requested: Bool) {
        presentation.showAgendaWing = requested
        presentation.dismissAccessDestination()
        if requested && CalendarWorkspacePolicy.mayReadEvents(status: calendarStore.authorizationStatus) {
            calendarStore.refreshPresentationInterval()
        }
        panelCoordinator?.syncAgendaVisibility()
    }

    private func openCalendarMode(panelProxy: CalendarPanelControllerProxy) {
        panelProxy.enterCalendarMode()
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
