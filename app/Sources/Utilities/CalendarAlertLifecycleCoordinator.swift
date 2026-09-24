import Foundation

/// Owns alert authorization and reconciliation triggers without duplicating scheduler fetch logic.
@MainActor
@Observable
public final class CalendarAlertLifecycleCoordinator {
    public private(set) var showsNotificationSettingsRecovery = false

    private let settings: SettingsStore
    private let preferenceStore: CalendarPreferenceStore
    private let calendarClock: CalendarClock
    private let scheduler: CalendarNotificationScheduler
    private let notificationCenter: any CalendarNotificationCenter
    private var reconciliationTask: Task<Void, Never>?
    private var reconciliationPending = false
    private var isApplyingAlertSetting = false

    public init(
        settings: SettingsStore,
        preferenceStore: CalendarPreferenceStore,
        calendarClock: CalendarClock,
        scheduler: CalendarNotificationScheduler,
        notificationCenter: any CalendarNotificationCenter
    ) {
        self.settings = settings
        self.preferenceStore = preferenceStore
        self.calendarClock = calendarClock
        self.scheduler = scheduler
        self.notificationCenter = notificationCenter
        observeTriggers()
    }

    isolated deinit {
        reconciliationTask?.cancel()
    }

    /// Resolves persisted state at launch without ever prompting for notification authorization.
    public func resolveLaunchAuthorization() async {
        guard settings.alertsEnabled else {
            await removeTimeZonerRequests()
            return
        }

        guard await notificationCenter.currentAuthorizationStatus().permitsAlerts else {
            applyStoredAlertsEnabled(false)
            showsNotificationSettingsRecovery = true
            await removeTimeZonerRequests()
            return
        }

        showsNotificationSettingsRecovery = false
        await reconcileIfEligible()
    }

    /// The sole permission-request path: an explicit false-to-true user intent.
    public func setGlobalAlertsEnabled(_ isEnabled: Bool) async {
        guard isEnabled else {
            applyStoredAlertsEnabled(false)
            showsNotificationSettingsRecovery = false
            await removeTimeZonerRequests()
            return
        }

        guard !settings.alertsEnabled else {
            await reconcileIfEligible()
            return
        }

        let granted: Bool
        do {
            granted = try await notificationCenter.requestAuthorization()
        } catch {
            granted = false
        }

        guard granted, await notificationCenter.currentAuthorizationStatus().permitsAlerts else {
            applyStoredAlertsEnabled(false)
            showsNotificationSettingsRecovery = true
            await removeTimeZonerRequests()
            return
        }

        applyStoredAlertsEnabled(true)
        showsNotificationSettingsRecovery = false
        await reconcileIfEligible()
    }

    /// Calendar permission loss must not disturb calendar preferences or other apps' notifications.
    public func calendarPermissionDidBecomeUnavailable() async {
        await removeTimeZonerRequests()
    }

    public func requestReconciliation() {
        reconciliationPending = true
        guard reconciliationTask == nil else { return }
        reconciliationTask = Task { [weak self] in
            await self?.drainReconciliations()
        }
    }

    private func observeTriggers() {
        settings.onAlertsEnabledChange = { [weak self] enabled in
            guard let self, !self.isApplyingAlertSetting else { return }
            if enabled {
                self.requestReconciliation()
            } else {
                Task { @MainActor [weak self] in
                    await self?.removeTimeZonerRequests()
                }
            }
        }
        settings.onNotificationLeadMinutesChange = { [weak self] _ in
            self?.requestReconciliation()
        }
        preferenceStore.onAlertsEnabledChange = { [weak self] _, _ in
            self?.requestReconciliation()
        }

    }

    private func drainReconciliations() async {
        while reconciliationPending {
            reconciliationPending = false
            await reconcileIfEligible()
        }
        reconciliationTask = nil
    }

    private func reconcileIfEligible() async {
        guard settings.alertsEnabled else {
            return
        }

        guard await notificationCenter.currentAuthorizationStatus().permitsAlerts else {
            applyStoredAlertsEnabled(false)
            showsNotificationSettingsRecovery = true
            await removeTimeZonerRequests()
            return
        }

        do {
            try await scheduler.reconcile(
                now: calendarClock.now(),
                timeZone: calendarClock.calendar.timeZone
            )
        } catch {
            // Calendar data can change mid-reconciliation; a later lifecycle trigger retries.
        }
    }

    private func applyStoredAlertsEnabled(_ enabled: Bool) {
        isApplyingAlertSetting = true
        settings.alertsEnabled = enabled
        isApplyingAlertSetting = false
    }

    private func removeTimeZonerRequests() async {
        let identifiers = await notificationCenter.pendingRequests()
            .map(\.identifier)
            .filter { $0.hasPrefix(CalendarNotificationScheduler.requestIdentifierPrefix) }
        guard !identifiers.isEmpty else { return }
        await notificationCenter.removePendingRequests(withIdentifiers: identifiers)
    }
}
