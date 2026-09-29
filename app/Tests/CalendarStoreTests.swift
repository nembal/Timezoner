import Foundation
import TimeZonerLib

private final class CalendarStoreProviderFake: CalendarEventReading {
    struct EventRequest {
        let start: Date
        let end: Date
        let calendarIDs: Set<String>
    }

    var authorizationStatus: CalendarAuthorizationStatus
    var descriptors: [CalendarDescriptor]
    var calendarError: Error?
    var requestAccessError: Error?
    var requestAccessHandler: (() -> Void)?
    private(set) var accessRequestCount = 0
    private(set) var eventRequests: [EventRequest] = []
    var onMissingEventRequest: (Int) -> Void = { index in
        testsFailed += 1
        print("  FAIL: event request \(index) was not recorded")
    }

    let changes: AsyncStream<Void>
    private let changesContinuation: AsyncStream<Void>.Continuation
    private var eventContinuations: [CheckedContinuation<[CalendarEventSnapshot], Error>?] = []

    init(
        authorizationStatus: CalendarAuthorizationStatus = .fullAccess,
        descriptors: [CalendarDescriptor] = [calendarStoreDescriptor(id: "work", title: "Work")]
    ) {
        self.authorizationStatus = authorizationStatus
        self.descriptors = descriptors
        let changeStream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(8))
        changes = changeStream.stream
        changesContinuation = changeStream.continuation
    }

    deinit {
        changesContinuation.finish()
    }

    func requestAccess() async throws -> Bool {
        accessRequestCount += 1
        if let requestAccessError {
            throw requestAccessError
        }
        requestAccessHandler?()
        return authorizationStatus == .fullAccess
    }

    func calendars() async throws -> [CalendarDescriptor] {
        if let calendarError {
            throw calendarError
        }
        return descriptors
    }

    func events(
        from start: Date,
        to end: Date,
        calendarIDs: Set<String>
    ) async throws -> [CalendarEventSnapshot] {
        return try await withCheckedThrowingContinuation { continuation in
            eventContinuations.append(continuation)
            eventRequests.append(EventRequest(start: start, end: end, calendarIDs: calendarIDs))
        }
    }

    func completeEventRequest(
        _ index: Int,
        with result: Result<[CalendarEventSnapshot], Error>
    ) {
        guard eventContinuations.indices.contains(index), let continuation = eventContinuations[index] else {
            onMissingEventRequest(index)
            return
        }
        eventContinuations[index] = nil
        continuation.resume(with: result)
    }

    func eventRequest(at index: Int) -> EventRequest? {
        guard eventRequests.indices.contains(index) else {
            onMissingEventRequest(index)
            return nil
        }
        return eventRequests[index]
    }

    func emitStoreChange() {
        changesContinuation.yield(())
    }
}

private func calendarStoreClock(
    now: @escaping () -> Date,
    calendar: @escaping () -> Calendar,
    signals: CalendarClockTestSignals
) -> CalendarClock {
    CalendarClock(
        now: now,
        calendar: calendar,
        minuteTicks: signals.minuteTicks,
        midnightTicks: signals.midnightTicks,
        hourTicks: signals.hourTicks,
        wakeEvents: signals.wakeEvents,
        activationEvents: signals.activationEvents,
        reopenEvents: signals.reopenEvents,
        timeZoneChanges: signals.timeZoneChanges
    )
}

private func calendarStoreDescriptor(id: String, title: String) -> CalendarDescriptor {
    CalendarDescriptor(
        id: id,
        title: title,
        sourceTitle: "Account",
        color: CalendarColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
    )
}

private func calendarStoreEvent(
    id: String,
    calendarID: String = "work",
    start: Date,
    end: Date? = nil,
    isAllDay: Bool = false
) -> CalendarEventSnapshot {
    CalendarEventSnapshot(
        id: id,
        calendarID: calendarID,
        calendarTitle: calendarID.capitalized,
        title: id,
        startDate: start,
        endDate: end ?? start.addingTimeInterval(60 * 60),
        isAllDay: isAllDay,
        attendeeNames: [],
        availability: .busy,
        participationStatus: .accepted
    )
}

private func expectCalendarStore<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ label: String,
    line: Int = #line
) {
    if actual == expected {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \(expected), got \(actual)")
    }
}

private func expectCalendarStoreTrue(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected true, got false")
    }
}

@MainActor
private func waitForCalendarStore(
    _ condition: @escaping () -> Bool,
    attempts: Int = 200
) async -> Bool {
    for _ in 0 ..< attempts {
        if condition() {
            return true
        }
        await Task.yield()
    }
    return condition()
}

@MainActor
func runCalendarStoreTests() async {
    print("Running CalendarStoreTests...")

    do {
        let provider = CalendarStoreProviderFake()
        var missingIndices: [Int] = []
        provider.onMissingEventRequest = { missingIndices.append($0) }
        provider.completeEventRequest(0, with: .success([]))
        expectCalendarStore(missingIndices, [0], "a missing async event request reports a test failure")
    }

    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.locale = Locale(identifier: "en_US_POSIX")
    utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let morning = Date(timeIntervalSince1970: 1_725_000_000)
    let initialInterval = DateInterval(start: morning, duration: 3 * 60 * 60)

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        var alertInputChanges = 0
        let store = CalendarStore(
            provider: provider,
            clock: clock,
            onAlertInputsChanged: { _ in alertInputChanges += 1 }
        )
        store.refresh(interval: initialInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "alert-input setup fetch begins")
        provider.completeEventRequest(0, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "alert-input setup fetch completes")

        provider.emitStoreChange()
        expectCalendarStoreTrue(await waitForCalendarStore { alertInputChanges == 1 }, "provider changes request one alert reconciliation")
        expectCalendarStore(alertInputChanges, 1, "provider changes do not duplicate alert reconciliation")
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 2 }, "provider change refresh begins")
        provider.completeEventRequest(1, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "provider change refresh completes")

        signals.emitHourTick()
        expectCalendarStoreTrue(await waitForCalendarStore { alertInputChanges == 2 }, "hour ticks request one alert reconciliation")
        expectCalendarStore(alertInputChanges, 2, "hour ticks do not duplicate alert reconciliation")

        signals.emitTimeZoneChange()
        expectCalendarStoreTrue(await waitForCalendarStore { alertInputChanges == 3 }, "timezone changes request one alert reconciliation")
        expectCalendarStore(alertInputChanges, 3, "timezone changes do not duplicate alert reconciliation")
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 3 }, "timezone refresh begins")
        provider.completeEventRequest(2, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "timezone refresh completes")
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarStoreClockSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let store = CalendarStore(provider: provider, clock: clock)

        store.refresh(interval: initialInterval)
        expectCalendarStoreTrue(
            await waitForCalendarStore { provider.eventRequests.count == 1 },
            "a full-access refresh fetches visible calendars"
        )
        provider.completeEventRequest(0, with: .success([]))
        expectCalendarStoreTrue(
            await waitForCalendarStore { !store.isLoading },
            "an empty snapshot completes the request"
        )
        expectCalendarStore(store.events, [], "a successful empty fetch is stored as an empty snapshot")
        expectCalendarStore(store.isStale, false, "a successful empty fetch is not stale")
        expectCalendarStore(store.errorMessage, nil, "a successful empty fetch has no error")

        store.refresh(interval: initialInterval)
        expectCalendarStoreTrue(
            await waitForCalendarStore { provider.eventRequests.count == 2 },
            "a later refresh starts a new fetch"
        )
        provider.completeEventRequest(1, with: .failure(CalendarStoreTestError.fetchFailed))
        expectCalendarStoreTrue(
            await waitForCalendarStore { !store.isLoading },
            "a failed refresh completes its request"
        )
        expectCalendarStore(store.events, [], "a failed refresh retains a successful empty snapshot")
        expectCalendarStore(store.isStale, true, "a failed refresh is marked stale")
        expectCalendarStoreTrue(store.errorMessage != nil, "a failed refresh exposes an error")
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let suiteName = "CalendarStoreTests.preferences.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = CalendarPreferenceStore(userDefaults: defaults)
        let store = CalendarStore(provider: provider, preferenceStore: preferences, clock: clock)
        let visibleEvent = calendarStoreEvent(id: "visible", start: morning)

        store.refresh(interval: initialInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "calendar preference setup request begins")
        provider.completeEventRequest(0, with: .success([visibleEvent]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "calendar preference setup request completes")

        store.setVisible(false, calendarID: "work")
        expectCalendarStoreTrue(
            await waitForCalendarStore { store.events.isEmpty && !store.isLoading },
            "hiding a calendar refreshes the active presentation range without its events"
        )
        expectCalendarStore(
            preferences.preference(for: "work"),
            CalendarPreference(isVisible: false, alertsEnabled: true),
            "hiding through CalendarStore preserves that calendar's alert setting"
        )

        store.setAlertsEnabled(false, calendarID: "work")
        expectCalendarStore(
            preferences.preference(for: "work"),
            CalendarPreference(isVisible: false, alertsEnabled: false),
            "alert preferences remain editable for a hidden calendar"
        )
        expectCalendarStore(provider.eventRequests.count, 1, "changing alerts alone does not refetch visible events")

        store.setVisible(true, calendarID: "work")
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 2 }, "showing a calendar refetches the active presentation range")
        provider.completeEventRequest(1, with: .success([visibleEvent]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "showing a calendar refresh completes")
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let store = CalendarStore(provider: provider, clock: clock)
        let oldEvent = calendarStoreEvent(id: "old", start: morning)

        store.refresh(interval: initialInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "initial snapshot request begins")
        provider.completeEventRequest(0, with: .success([oldEvent]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "initial snapshot request completes")

        store.refresh(interval: initialInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 2 }, "failure test refresh begins")
        provider.completeEventRequest(1, with: .failure(CalendarStoreTestError.fetchFailed))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "failure test refresh completes")
        expectCalendarStore(store.events, [oldEvent], "fetch failure retains the last successful events for this session")
        expectCalendarStore(store.isStale, true, "retained events are explicitly marked stale")
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let store = CalendarStore(provider: provider, clock: clock)
        let firstInterval = DateInterval(start: morning, duration: 60 * 60)
        let secondInterval = DateInterval(start: morning.addingTimeInterval(60 * 60), duration: 60 * 60)
        let firstEvent = calendarStoreEvent(id: "first-range", start: firstInterval.start)

        store.refresh(interval: firstInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "snapshot-range setup request begins")
        provider.completeEventRequest(0, with: .success([firstEvent]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "snapshot-range setup request completes")
        expectCalendarStore(store.snapshotInterval, firstInterval, "a successful fetch records the interval that owns its snapshots")
        expectCalendarStoreTrue(store.hasSnapshot(for: firstInterval), "the successful interval exposes its own snapshot")

        store.refresh(interval: secondInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 2 }, "changing the range starts a replacement request")
        expectCalendarStoreTrue(!store.hasSnapshot(for: secondInterval), "a new active range never presents the old successful snapshot as current")
        provider.completeEventRequest(1, with: .failure(CalendarStoreTestError.fetchFailed))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "replacement range failure completes")
        expectCalendarStore(store.snapshotInterval, firstInterval, "a failed replacement keeps ownership with the last successful interval")
        expectCalendarStoreTrue(!store.hasSnapshot(for: secondInterval), "a failed replacement remains gated from displaying the old range as active")
    }

    do {
        let hidden = calendarStoreDescriptor(id: "hidden", title: "Hidden")
        let visible = calendarStoreDescriptor(id: "visible", title: "Visible")
        let provider = CalendarStoreProviderFake(descriptors: [hidden, visible])
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let suiteName = "CalendarStoreTests.hidden.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let preferences = CalendarPreferenceStore(userDefaults: defaults)
        preferences.setVisible(false, calendarID: hidden.id)
        let store = CalendarStore(provider: provider, preferenceStore: preferences, clock: clock)

        store.refresh(interval: initialInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "visible-calendar request begins")
        expectCalendarStore(
            provider.eventRequest(at: 0)?.calendarIDs,
            Set([visible.id]),
            "hidden calendars are excluded from the UI event fetch"
        )
        provider.completeEventRequest(0, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "visible-calendar request completes")
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let store = CalendarStore(provider: provider, clock: clock)
        let firstInterval = DateInterval(start: morning, duration: 60 * 60)
        let secondInterval = DateInterval(start: morning.addingTimeInterval(60 * 60), duration: 60 * 60)
        let latestEvent = calendarStoreEvent(id: "latest", start: secondInterval.start)

        store.refresh(interval: firstInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "first supersession request begins")
        store.refresh(interval: secondInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 2 }, "second supersession request begins")
        provider.completeEventRequest(0, with: .success([calendarStoreEvent(id: "obsolete", start: firstInterval.start)]))
        await Task.yield()
        expectCalendarStore(store.events, [], "a superseded success cannot replace the latest snapshot")
        expectCalendarStore(store.isLoading, true, "a superseded success cannot finish the active request")
        provider.completeEventRequest(1, with: .success([latestEvent]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "latest supersession request completes")
        expectCalendarStore(store.events, [latestEvent], "the latest request owns the resulting snapshot")

        store.refresh(interval: firstInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 3 }, "first stale-error request begins")
        store.refresh(interval: secondInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 4 }, "second stale-error request begins")
        provider.completeEventRequest(2, with: .failure(CalendarStoreTestError.fetchFailed))
        await Task.yield()
        expectCalendarStore(store.errorMessage, nil, "a superseded error cannot replace the active request state")
        expectCalendarStore(store.isStale, false, "a superseded error cannot mark current data stale")
        provider.completeEventRequest(3, with: .success([latestEvent]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "latest request after stale error completes")
    }

    do {
        var clockNow = morning
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { clockNow }, calendar: { utcCalendar }, signals: signals)
        let rebuiltInterval: (Date, Calendar) -> DateInterval = { now, calendar in
            CalendarDateIntervalCalculator.interval(for: .today, anchor: now, calendar: calendar)
        }
        let store = CalendarStore(provider: provider, clock: clock, intervalBuilder: rebuiltInterval)

        store.refresh(interval: rebuiltInterval(clockNow, utcCalendar))
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "initial lifecycle request begins")
        provider.completeEventRequest(0, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "initial lifecycle request completes")

        clockNow = morning.addingTimeInterval(24 * 60 * 60)
        signals.emitMidnightTick()
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 2 }, "midnight rebuilds and refetches the active range")
        expectCalendarStore(
            provider.eventRequest(at: 1)?.start,
            rebuiltInterval(clockNow, utcCalendar).start,
            "midnight uses the wall clock rather than TimeState's reference date"
        )
        provider.completeEventRequest(1, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "midnight refresh completes")

        clockNow = clockNow.addingTimeInterval(24 * 60 * 60)
        signals.emitTimeZoneChange()
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 3 }, "timezone changes rebuild and refetch the active range")
        expectCalendarStore(
            provider.eventRequest(at: 2)?.start,
            rebuiltInterval(clockNow, utcCalendar).start,
            "timezone rebuilding uses the injected wall clock calendar"
        )
        provider.completeEventRequest(2, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "timezone refresh completes")

        provider.emitStoreChange()
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 4 }, "EventKit store changes refetch the current range")
        provider.completeEventRequest(3, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "store-change refresh completes")
    }

    do {
        var clockNow = morning
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { clockNow }, calendar: { utcCalendar }, signals: signals)
        let suiteName = "CalendarStoreTests.presentation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let presentation = CalendarPresentationState(defaults: defaults)
        let intervalBuilder: CalendarStore.IntervalBuilder = { now, calendar in
            switch presentation.destination {
            case .timezoner:
                return CalendarStore.agendaInterval(for: now, calendar: calendar)
            case .calendar:
                return presentation.activeInterval(calendar: calendar)
            }
        }
        let store = CalendarStore(provider: provider, clock: clock, intervalBuilder: intervalBuilder)

        presentation.enterCalendar(now: clockNow, calendar: utcCalendar)
        presentation.setRange(.week)
        presentation.move(.next, calendar: utcCalendar)
        let historicalWeek = presentation.activeInterval(calendar: utcCalendar)
        store.refresh(interval: historicalWeek)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "calendar-mode lifecycle setup request begins")
        provider.completeEventRequest(0, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "calendar-mode lifecycle setup request completes")

        clockNow = clockNow.addingTimeInterval(24 * 60 * 60)
        signals.emitMidnightTick()
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 2 }, "midnight refetches while calendar mode is active")
        expectCalendarStore(
            provider.eventRequest(at: 1)?.start,
            historicalWeek.start,
            "midnight retains the active calendar range instead of resetting to the agenda range"
        )
        expectCalendarStore(
            provider.eventRequest(at: 1)?.end,
            historicalWeek.end,
            "calendar-mode lifecycle refresh retains the active range end"
        )
        provider.completeEventRequest(1, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "calendar-mode midnight refresh completes")

        presentation.returnToTimeZoner()
        signals.emitTimeZoneChange()
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 3 }, "timezone change refetches after returning to TimeZoner")
        let expectedAgenda = CalendarStore.agendaInterval(for: clockNow, calendar: utcCalendar)
        expectCalendarStore(provider.eventRequest(at: 2)?.start, expectedAgenda.start, "TimeZoner mode rebuilds the agenda interval")
        expectCalendarStore(provider.eventRequest(at: 2)?.end, expectedAgenda.end, "TimeZoner mode uses the agenda interval end")
        provider.completeEventRequest(2, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "TimeZoner-mode timezone refresh completes")
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let suiteName = "CalendarStoreTests.presentation-refresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let presentation = CalendarPresentationState(defaults: defaults)
        let intervalBuilder: CalendarStore.IntervalBuilder = { now, calendar in
            presentation.destination == .calendar
                ? presentation.activeInterval(calendar: calendar)
                : CalendarStore.agendaInterval(for: now, calendar: calendar)
        }
        let store = CalendarStore(provider: provider, clock: clock, intervalBuilder: intervalBuilder)

        presentation.enterCalendar(now: morning, calendar: utcCalendar)
        presentation.move(.next, calendar: utcCalendar)
        let selectedWeek = presentation.activeInterval(calendar: utcCalendar)
        store.refreshPresentationInterval()
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "presentation refresh begins for an open calendar range")
        expectCalendarStore(provider.eventRequest(at: 0)?.start, selectedWeek.start, "presentation refresh retains the selected Week start")
        expectCalendarStore(provider.eventRequest(at: 0)?.end, selectedWeek.end, "presentation refresh retains the selected Week end")
        provider.completeEventRequest(0, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "calendar presentation refresh completes")

        presentation.returnToTimeZoner()
        store.refreshPresentationInterval()
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 2 }, "presentation refresh starts after returning to TimeZoner")
        let expectedAgenda = CalendarStore.agendaInterval(for: morning, calendar: utcCalendar)
        expectCalendarStore(provider.eventRequest(at: 1)?.start, expectedAgenda.start, "returning to TimeZoner refreshes the normal agenda interval")
        expectCalendarStore(provider.eventRequest(at: 1)?.end, expectedAgenda.end, "normal agenda refresh uses the three-day interval end")
        provider.completeEventRequest(1, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "normal agenda presentation refresh completes")
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        weak var releasedStore: CalendarStore?

        do {
            let store = CalendarStore(provider: provider, clock: clock)
            releasedStore = store
            for _ in 0 ..< 8 {
                await Task.yield()
            }
        }

        expectCalendarStoreTrue(
            await waitForCalendarStore { releasedStore == nil },
            "CalendarStore releases its observer tasks when its owner releases the store"
        )
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let store = CalendarStore(provider: provider, clock: clock)

        store.refresh(interval: initialInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "lifecycle authorization setup request begins")
        provider.completeEventRequest(0, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "lifecycle authorization setup request completes")

        signals.emitWake()
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 2 }, "wake rechecks authorization and refreshes")
        provider.completeEventRequest(1, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "wake refresh completes")

        signals.emitActivation()
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 3 }, "activation rechecks authorization and refreshes")
        provider.completeEventRequest(2, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "activation refresh completes")

        signals.emitReopen()
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 4 }, "reopen rechecks authorization and refreshes")
        provider.completeEventRequest(3, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "reopen refresh completes")
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        var permissionLossCount = 0
        var notificationRemovalCount = 0
        let store = CalendarStore(
            provider: provider,
            clock: clock,
            onPermissionLost: { permissionLossCount += 1 },
            onRemoveCalendarNotifications: { notificationRemovalCount += 1 }
        )
        let selectedEvent = calendarStoreEvent(id: "selected", start: morning)

        store.refresh(interval: initialInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "permission-loss setup request begins")
        provider.completeEventRequest(0, with: .success([selectedEvent]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "permission-loss setup request completes")

        store.refresh(interval: initialInterval)
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 2 }, "in-flight permission-loss request begins")
        provider.authorizationStatus = .denied
        store.handlePermissionChange()
        expectCalendarStore(store.authorizationStatus, .denied, "permission loss updates authorization immediately")
        expectCalendarStore(store.descriptors, [], "permission loss clears calendar descriptors immediately")
        expectCalendarStore(store.events, [], "permission loss clears event snapshots immediately")
        expectCalendarStore(store.errorMessage, nil, "permission loss does not use the stale-fetch error state")
        expectCalendarStore(store.isStale, false, "permission loss clears the stale marker")
        expectCalendarStore(store.isLoading, false, "permission loss ends the active loading state")
        expectCalendarStore(permissionLossCount, 1, "permission loss invokes the callback once")
        expectCalendarStore(notificationRemovalCount, 1, "permission loss removes TimeZoner calendar notifications once")
        provider.completeEventRequest(1, with: .success([selectedEvent]))
        await Task.yield()
        expectCalendarStore(store.events, [], "invalidated in-flight success cannot restore revoked snapshots")
        store.handlePermissionChange()
        expectCalendarStore(permissionLossCount, 1, "repeating an unavailable status does not invoke the callback again")
        expectCalendarStore(notificationRemovalCount, 1, "repeating an unavailable status does not remove notifications again")

        provider.authorizationStatus = .fullAccess
        store.handlePermissionChange()
        provider.authorizationStatus = .restricted
        store.handlePermissionChange()
        expectCalendarStore(permissionLossCount, 2, "a later full-to-unavailable transition invokes the callback once")
        expectCalendarStore(notificationRemovalCount, 2, "a later full-to-unavailable transition removes notifications once")
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let suiteName = "CalendarStoreTests.permission-composition.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(
            userDefaults: defaults,
            keys: SettingsStore.Keys(
                appearance: "composition.appearance",
                launchAtLogin: "composition.launchAtLogin",
                hotkey: "composition.hotkey",
                showAgendaWing: "composition.showAgendaWing",
                alertsEnabled: "composition.alertsEnabled",
                notificationLeadMinutes: "composition.notificationLeadMinutes"
            )
        )
        let presentation = CalendarPresentationState(
            settings: settings,
            defaults: defaults,
            mapExpandedKey: "composition.mapExpanded"
        )
        let referenceMoment = ReferenceMomentController(timeState: TimeState(), presentation: presentation)
        let selectedEvent = calendarStoreEvent(id: "selected-for-revocation", start: morning)
        var notificationRemovalCount = 0
        let store = CalendarStore(
            provider: provider,
            clock: clock,
            onPermissionLost: {
                CalendarPermissionLossCoordinator.handle(
                    referenceMoment: referenceMoment,
                    presentation: presentation
                )
            },
            onRemoveCalendarNotifications: { notificationRemovalCount += 1 }
        )

        referenceMoment.selectEvent(selectedEvent, sourceZone: TimeZone(secondsFromGMT: 0)!)
        presentation.attendeePopoverEventID = selectedEvent.id
        presentation.showAgendaWing = true
        expectCalendarStoreTrue(!presentation.isMapExpanded, "selected calendar events collapse the map before permission loss")

        provider.authorizationStatus = .denied
        store.handlePermissionChange()

        expectCalendarStore(referenceMoment.selectedEvent, nil, "permission loss clears the selected event context through the app callback seam")
        expectCalendarStoreTrue(presentation.isMapExpanded, "permission loss restores the pre-selection map expansion when no manual toggle occurred")
        expectCalendarStore(presentation.attendeePopoverEventID, nil, "permission loss clears calendar-owned highlight state")
        expectCalendarStoreTrue(presentation.showAgendaWing, "permission loss preserves the persisted agenda wing")
        expectCalendarStore(presentation.accessDestination, .recovery, "permission loss routes the shared presentation state to recovery")
        expectCalendarStore(notificationRemovalCount, 1, "permission loss invokes the notification-removal callback alongside UI cleanup")

        provider.authorizationStatus = .fullAccess
        store.handlePermissionChange()
        referenceMoment.selectEvent(selectedEvent, sourceZone: TimeZone(secondsFromGMT: 0)!)
        presentation.attendeePopoverEventID = selectedEvent.id
        presentation.toggleMapManually()
        referenceMoment.didManuallyToggleMap()
        provider.authorizationStatus = .writeOnly
        store.handlePermissionChange()

        expectCalendarStore(referenceMoment.selectedEvent, nil, "a later permission loss also clears a manually adjusted selected event")
        expectCalendarStoreTrue(presentation.isMapExpanded, "permission loss preserves the manual map state after restoration was cancelled")
        expectCalendarStore(presentation.attendeePopoverEventID, nil, "later permission loss clears the calendar highlight again")
        expectCalendarStore(notificationRemovalCount, 2, "a later permission loss invokes notification removal again")
    }

    do {
        let deniedProvider = CalendarStoreProviderFake(authorizationStatus: .denied)
        let deniedSignals = CalendarClockTestSignals()
        let deniedClock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: deniedSignals)
        let deniedStore = CalendarStore(provider: deniedProvider, clock: deniedClock)
        deniedStore.refreshPresentationInterval()
        await Task.yield()
        expectCalendarStore(deniedProvider.accessRequestCount, 0, "visible recovery cannot request permission")
        expectCalendarStoreTrue(deniedProvider.eventRequests.isEmpty, "denied calendar cannot fetch events")
    }

    do {
        let provider = CalendarStoreProviderFake(authorizationStatus: .notDetermined)
        provider.requestAccessHandler = { provider.authorizationStatus = .fullAccess }
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let store = CalendarStore(provider: provider, clock: clock)

        store.requestAccess()
        expectCalendarStoreTrue(
            await waitForCalendarStore { provider.eventRequests.count == 1 },
            "granting access starts the default wall-clock calendar fetch"
        )
        provider.completeEventRequest(0, with: .success([]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "post-grant default fetch completes")
        expectCalendarStore(store.authorizationStatus, .fullAccess, "requestAccess records the granted authorization")
    }

    do {
        let provider = CalendarStoreProviderFake()
        let signals = CalendarClockTestSignals()
        let clock = calendarStoreClock(now: { morning }, calendar: { utcCalendar }, signals: signals)
        let store = CalendarStore(provider: provider, clock: clock)
        let dayStart = utcCalendar.startOfDay(for: morning)
        let timedLater = calendarStoreEvent(id: "timed-later", start: dayStart.addingTimeInterval(5 * 60 * 60))
        let allDay = calendarStoreEvent(
            id: "all-day",
            start: dayStart,
            end: dayStart.addingTimeInterval(24 * 60 * 60),
            isAllDay: true
        )
        let timedEarlier = calendarStoreEvent(id: "timed-earlier", start: dayStart.addingTimeInterval(2 * 60 * 60))

        store.refresh(interval: DateInterval(start: dayStart, duration: 24 * 60 * 60))
        expectCalendarStoreTrue(await waitForCalendarStore { provider.eventRequests.count == 1 }, "day grouping request begins")
        provider.completeEventRequest(0, with: .success([timedLater, allDay, timedEarlier]))
        expectCalendarStoreTrue(await waitForCalendarStore { !store.isLoading }, "day grouping request completes")
        expectCalendarStore(
            store.events(on: dayStart).map(\.id),
            [allDay.id, timedEarlier.id, timedLater.id],
            "events(on:) groups a local day with all-day items before timed items"
        )
    }
}

private enum CalendarStoreTestError: Error {
    case fetchFailed
}
