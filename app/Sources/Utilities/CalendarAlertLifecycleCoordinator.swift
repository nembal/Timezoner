import Foundation

/// Owns alert authorization and reconciliation triggers without duplicating scheduler fetch logic.
///
/// Reconciliation and cleanup share one ordered operation chain. That is intentionally stronger
/// than task cancellation: an underlying notification add may finish after cancellation, so a
/// later cleanup must wait for that add and remove its TimeZoner-owned request afterwards.
@MainActor
@Observable
public final class CalendarAlertLifecycleCoordinator {
    public private(set) var showsNotificationSettingsRecovery = false

    private let settings: SettingsStore
    private let preferenceStore: CalendarPreferenceStore
    private let calendarClock: CalendarClock
    private let scheduler: CalendarNotificationScheduler
    private let notificationCenter: any CalendarNotificationCenter
    private let calendarAuthorizationStatus: () -> CalendarAuthorizationStatus
    private var reconciliationDrainTask: Task<Void, Never>?
    private var reconciliationPending = false
    private var isApplyingAlertSetting = false
    private var reconciliationGeneration: UInt = 0
    private var operationTail: (id: UInt, task: Task<Void, Never>)?
    private var operationID: UInt = 0

    public init(
        settings: SettingsStore,
        preferenceStore: CalendarPreferenceStore,
        calendarClock: CalendarClock,
        scheduler: CalendarNotificationScheduler,
        notificationCenter: any CalendarNotificationCenter,
        calendarAuthorizationStatus: @escaping () -> CalendarAuthorizationStatus = { .fullAccess }
    ) {
        self.settings = settings
        self.preferenceStore = preferenceStore
        self.calendarClock = calendarClock
        self.scheduler = scheduler
        self.notificationCenter = notificationCenter
        self.calendarAuthorizationStatus = calendarAuthorizationStatus
        observeTriggers()
    }

    isolated deinit {
        reconciliationDrainTask?.cancel()
    }

    /// Resolves persisted state at launch without ever prompting for notification authorization.
    public func resolveLaunchAuthorization() async {
        guard settings.alertsEnabled else {
            await invalidateAndRemoveTimeZonerRequests()
            return
        }

        guard await notificationCenter.currentAuthorizationStatus().permitsAlerts else {
            applyStoredAlertsEnabled(false)
            showsNotificationSettingsRecovery = true
            await invalidateAndRemoveTimeZonerRequests()
            return
        }

        showsNotificationSettingsRecovery = false
        await enqueueReconciliation()
    }

    /// The sole permission-request path: an explicit false-to-true user intent.
    public func setGlobalAlertsEnabled(_ isEnabled: Bool) async {
        guard isEnabled else {
            applyStoredAlertsEnabled(false)
            showsNotificationSettingsRecovery = false
            await invalidateAndRemoveTimeZonerRequests()
            return
        }

        guard !settings.alertsEnabled else {
            await enqueueReconciliation()
            return
        }

        let requestGeneration = reconciliationGeneration
        let granted: Bool
        do {
            granted = try await notificationCenter.requestAuthorization()
        } catch {
            granted = false
        }

        guard requestGeneration == reconciliationGeneration else { return }

        guard granted, await notificationCenter.currentAuthorizationStatus().permitsAlerts else {
            applyStoredAlertsEnabled(false)
            showsNotificationSettingsRecovery = true
            await invalidateAndRemoveTimeZonerRequests()
            return
        }

        applyStoredAlertsEnabled(true)
        showsNotificationSettingsRecovery = false
        await enqueueReconciliation()
    }

    /// Calendar permission loss must not disturb calendar preferences or other apps' notifications.
    public func calendarPermissionDidBecomeUnavailable() async {
        await invalidateAndRemoveTimeZonerRequests()
    }

    public func requestReconciliation() {
        reconciliationPending = true
        guard reconciliationDrainTask == nil else { return }
        reconciliationDrainTask = Task { @MainActor [weak self] in
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
                    await self?.invalidateAndRemoveTimeZonerRequests()
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
            await enqueueReconciliation()
        }
        reconciliationDrainTask = nil
    }

    private func enqueueReconciliation() async {
        let generation = reconciliationGeneration
        await enqueueOperation { [weak self] in
            await self?.reconcileIfEligible(generation: generation)
        }
    }

    private func reconcileIfEligible(generation: UInt) async {
        guard settings.alertsEnabled else { return }

        guard calendarAuthorizationStatus() == .fullAccess else {
            await removeTimeZonerRequests()
            return
        }

        guard await notificationCenter.currentAuthorizationStatus().permitsAlerts else {
            guard generation == reconciliationGeneration else { return }
            applyStoredAlertsEnabled(false)
            showsNotificationSettingsRecovery = true
            invalidateReconciliationGeneration()
            await removeTimeZonerRequests()
            return
        }

        do {
            let completed = try await scheduler.reconcile(
                now: calendarClock.now(),
                timeZone: calendarClock.calendar.timeZone,
                shouldContinue: { [weak self] in
                    guard let self else { return false }
                    return await self.isCurrentReconciliation(generation)
                }
            )
            guard !completed else { return }
            await removeTimeZonerRequestsIfCurrent(generation)
        } catch {
            // Calendar data can change mid-reconciliation; a later lifecycle trigger retries.
        }
    }

    private func isCurrentReconciliation(_ generation: UInt) async -> Bool {
        guard generation == reconciliationGeneration,
              settings.alertsEnabled,
              calendarAuthorizationStatus() == .fullAccess else {
            return false
        }
        return await notificationCenter.currentAuthorizationStatus().permitsAlerts
    }

    /// Runs inside an already-serialized reconciliation operation. If this run was invalidated,
    /// its successor cleanup is already queued behind it and owns the final removal. If the same
    /// generation merely lost notification authorization, this operation invalidates and cleans up
    /// itself after the just-finished add boundary.
    private func removeTimeZonerRequestsIfCurrent(_ generation: UInt) async {
        guard generation == reconciliationGeneration else { return }
        if !settings.alertsEnabled || calendarAuthorizationStatus() != .fullAccess {
            await removeTimeZonerRequests()
            return
        }
        guard !(await notificationCenter.currentAuthorizationStatus().permitsAlerts) else { return }
        applyStoredAlertsEnabled(false)
        showsNotificationSettingsRecovery = true
        invalidateReconciliationGeneration()
        await removeTimeZonerRequests()
    }

    private func invalidateAndRemoveTimeZonerRequests() async {
        invalidateReconciliationGeneration()
        await enqueueOperation { [weak self] in
            await self?.removeTimeZonerRequests()
        }
    }

    private func invalidateReconciliationGeneration() {
        reconciliationGeneration &+= 1
        reconciliationPending = false
    }

    /// Appends work to a single FIFO operation chain. Do not replace this with a cancellation-only
    /// strategy: UserNotifications may complete an already-issued add after cancellation.
    private func enqueueOperation(_ operation: @escaping @MainActor () async -> Void) async {
        let predecessor = operationTail?.task
        operationID &+= 1
        let id = operationID
        let task = Task { @MainActor in
            await predecessor?.value
            await operation()
        }
        operationTail = (id, task)
        await task.value
        if operationTail?.id == id {
            operationTail = nil
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
