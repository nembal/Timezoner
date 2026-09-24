import Foundation

/// The calendar presentation cache. All changes are serialized on the main actor so UI state,
/// authorization transitions, and asynchronous EventKit results have one coherent owner.
@MainActor
@Observable
public final class CalendarStore {
    public typealias IntervalBuilder = @MainActor (Date, Calendar) -> DateInterval

    public private(set) var authorizationStatus: CalendarAuthorizationStatus
    public private(set) var descriptors: [CalendarDescriptor] = []
    public private(set) var events: [CalendarEventSnapshot] = []
    public private(set) var isLoading = false
    public private(set) var isStale = false
    public private(set) var errorMessage: String?
    public private(set) var activeInterval: DateInterval?
    /// The interval that produced the currently retained snapshot. It can differ from
    /// activeInterval after a range change fails, so presentation must gate stale values.
    public private(set) var snapshotInterval: DateInterval?
    public private(set) var currentDate: Date

    private let provider: any CalendarEventReading
    private let preferenceStore: CalendarPreferenceStore
    private let clock: CalendarClock
    private let intervalBuilder: IntervalBuilder
    private let onPermissionLost: () -> Void
    private let onRemoveCalendarNotifications: () -> Void
    private var requestGeneration = 0
    private var observationTasks: [Task<Void, Never>] = []

    public init(
        provider: any CalendarEventReading = EventKitCalendarProvider(),
        preferenceStore: CalendarPreferenceStore = CalendarPreferenceStore(),
        clock: CalendarClock = CalendarClock(),
        intervalBuilder: @escaping IntervalBuilder = CalendarStore.agendaInterval,
        onPermissionLost: @escaping () -> Void = {},
        onRemoveCalendarNotifications: @escaping () -> Void = {}
    ) {
        self.provider = provider
        self.preferenceStore = preferenceStore
        self.clock = clock
        self.intervalBuilder = intervalBuilder
        self.onPermissionLost = onPermissionLost
        self.onRemoveCalendarNotifications = onRemoveCalendarNotifications
        authorizationStatus = provider.authorizationStatus
        currentDate = clock.now()
        observeClockAndProvider()
    }

    isolated deinit {
        observationTasks.forEach { $0.cancel() }
    }

    /// The injected local wall-clock Calendar shared by refresh ownership and grid geometry.
    public var localCalendar: Calendar { clock.calendar }

    /// A retained snapshot is safe to render only for the exact interval that fetched it.
    public func hasSnapshot(for interval: DateInterval) -> Bool {
        snapshotInterval == interval
    }

    /// Rebuilds from the injected presentation interval builder. Callers use this instead of
    /// assuming the agenda range, because calendar mode owns a different active interval.
    public func refreshPresentationInterval() {
        refresh(interval: defaultInterval())
    }

    /// Persists a calendar's visibility and refreshes the current presentation range so the
    /// agenda and calendar views stop rendering that calendar's retained events immediately.
    public func setVisible(_ isVisible: Bool, calendarID: String) {
        preferenceStore.setVisible(isVisible, calendarID: calendarID)
        guard authorizationStatus == .fullAccess else { return }
        refresh(interval: activeInterval ?? defaultInterval())
    }

    /// Persists an alert preference without changing the event-fetch slice. Hidden calendars can
    /// still retain alerts, so this must not be coupled to visibility.
    public func setAlertsEnabled(_ alertsEnabled: Bool, calendarID: String) {
        preferenceStore.setAlertsEnabled(alertsEnabled, calendarID: calendarID)
    }

    /// Refreshes a specific presentation range. Starting a new request invalidates every older one.
    public func refresh(interval: DateInterval) {
        activeInterval = interval
        currentDate = clock.now()
        handlePermissionChange()
        guard authorizationStatus == .fullAccess else { return }

        let generation = beginRequest()
        let provider = provider
        let preferences = preferenceStore
        Task { [weak self] in
            do {
                let descriptors = try await provider.calendars()
                guard let self, self.requestGeneration == generation else { return }
                self.handlePermissionChange()
                guard self.authorizationStatus == .fullAccess, self.requestGeneration == generation else { return }

                let visibleIDs = Set(descriptors.compactMap { descriptor in
                    preferences.preference(for: descriptor.id).isVisible ? descriptor.id : nil
                })
                guard !visibleIDs.isEmpty else {
                    self.finishSuccess(
                        descriptors: descriptors,
                        events: [],
                        interval: interval,
                        generation: generation
                    )
                    return
                }

                let fetchedEvents = try await provider.events(
                    from: interval.start,
                    to: interval.end,
                    calendarIDs: visibleIDs
                )
                guard self.requestGeneration == generation else { return }
                self.handlePermissionChange()
                guard self.authorizationStatus == .fullAccess, self.requestGeneration == generation else { return }
                self.finishSuccess(
                    descriptors: descriptors,
                    events: fetchedEvents,
                    interval: interval,
                    generation: generation
                )
            } catch {
                guard let self, self.requestGeneration == generation else { return }
                self.handlePermissionChange()
                guard self.authorizationStatus == .fullAccess, self.requestGeneration == generation else { return }
                self.finishFailure(error, generation: generation)
            }
        }
    }

    /// Requests full calendar access only after an explicit user action.
    public func requestAccess() {
        let generation = beginRequest()
        let provider = provider
        Task { [weak self] in
            do {
                _ = try await provider.requestAccess()
                guard let self, self.requestGeneration == generation else { return }
                self.handlePermissionChange()
                guard self.authorizationStatus == .fullAccess else { return }
                self.refresh(interval: self.activeInterval ?? self.defaultInterval())
            } catch {
                guard let self, self.requestGeneration == generation else { return }
                self.handlePermissionChange()
                guard self.authorizationStatus == .fullAccess else { return }
                self.finishFailure(error, generation: generation)
            }
        }
    }

    /// Applies an authorization change immediately, including a full-to-unavailable revocation.
    public func handlePermissionChange() {
        let updatedStatus = provider.authorizationStatus
        let hadFullAccess = authorizationStatus == .fullAccess
        authorizationStatus = updatedStatus
        guard updatedStatus != .fullAccess else { return }

        requestGeneration += 1
        descriptors = []
        events = []
        snapshotInterval = nil
        isLoading = false
        isStale = false
        errorMessage = nil

        if hadFullAccess {
            onPermissionLost()
            onRemoveCalendarNotifications()
        }
    }

    /// Returns the events intersecting a local day, with informational all-day rows first.
    public func events(on day: Date) -> [CalendarEventSnapshot] {
        guard let interval = clock.calendar.dateInterval(of: .day, for: day) else { return [] }
        return events
            .filter { $0.startDate < interval.end && $0.endDate > interval.start }
            .sorted { left, right in
                if left.isAllDay != right.isAllDay {
                    return left.isAllDay
                }
                if left.startDate != right.startDate {
                    return left.startDate < right.startDate
                }
                return left.id < right.id
            }
    }

    public static func agendaInterval(for date: Date, calendar: Calendar) -> DateInterval {
        CalendarDateIntervalCalculator.interval(for: .threeDays, anchor: date, calendar: calendar)
    }

    private func beginRequest() -> Int {
        requestGeneration += 1
        isLoading = true
        errorMessage = nil
        return requestGeneration
    }

    private func finishSuccess(
        descriptors: [CalendarDescriptor],
        events: [CalendarEventSnapshot],
        interval: DateInterval,
        generation: Int
    ) {
        guard requestGeneration == generation else { return }
        self.descriptors = descriptors
        self.events = events
        snapshotInterval = interval
        isLoading = false
        isStale = false
        errorMessage = nil
    }

    private func finishFailure(_ error: Error, generation: Int) {
        guard requestGeneration == generation else { return }
        isLoading = false
        isStale = true
        errorMessage = "Calendar fetch failed: \(error.localizedDescription)"
    }

    private func defaultInterval() -> DateInterval {
        intervalBuilder(clock.now(), clock.calendar)
    }

    private func observeClockAndProvider() {
        observationTasks = [
            Task { [weak self, provider] in
                for await _ in provider.changes {
                    guard !Task.isCancelled else { return }
                    self?.refreshCurrentInterval()
                }
            },
            Task { [weak self, clock] in
                for await _ in clock.minuteTicks {
                    guard !Task.isCancelled else { return }
                    self?.currentDate = clock.now()
                }
            },
            Task { [weak self, clock] in
                for await _ in clock.hourTicks {
                    guard !Task.isCancelled else { return }
                    self?.currentDate = clock.now()
                }
            },
            Task { [weak self, clock] in
                for await _ in clock.midnightTicks {
                    guard !Task.isCancelled else { return }
                    self?.refreshForWallClockRangeChange()
                }
            },
            Task { [weak self, clock] in
                for await _ in clock.timeZoneChanges {
                    guard !Task.isCancelled else { return }
                    self?.refreshForWallClockRangeChange()
                }
            },
            Task { [weak self, clock] in
                for await _ in clock.wakeEvents {
                    guard !Task.isCancelled else { return }
                    self?.refreshCurrentInterval()
                }
            },
            Task { [weak self, clock] in
                for await _ in clock.activationEvents {
                    guard !Task.isCancelled else { return }
                    self?.refreshCurrentInterval()
                }
            },
            Task { [weak self, clock] in
                for await _ in clock.reopenEvents {
                    guard !Task.isCancelled else { return }
                    self?.refreshCurrentInterval()
                }
            },
        ]
    }

    private func refreshCurrentInterval() {
        currentDate = clock.now()
        handlePermissionChange()
        guard authorizationStatus == .fullAccess, let activeInterval else { return }
        refresh(interval: activeInterval)
    }

    private func refreshForWallClockRangeChange() {
        currentDate = clock.now()
        handlePermissionChange()
        guard authorizationStatus == .fullAccess, activeInterval != nil else { return }
        refresh(interval: defaultInterval())
    }
}
