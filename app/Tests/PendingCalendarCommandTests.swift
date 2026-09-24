import Foundation
import TimeZonerLib

private func expectPendingCalendarCommand<T: Equatable>(
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

private func expectPendingCalendarCommandTrue(
    _ condition: Bool,
    _ label: String,
    line: Int = #line
) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected true, got false")
    }
}

private final class PendingCalendarCommandReaderFake: CalendarEventReading {
    struct Request: Equatable {
        let start: Date
        let end: Date
        let calendarIDs: Set<String>
    }

    var authorizationStatus: CalendarAuthorizationStatus = .fullAccess
    var descriptors: [CalendarDescriptor] = []
    var snapshots: [CalendarEventSnapshot] = []
    var failure: Error?
    private(set) var requests: [Request] = []
    let changes: AsyncStream<Void>
    private let changesContinuation: AsyncStream<Void>.Continuation

    init() {
        let stream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(8))
        changes = stream.stream
        changesContinuation = stream.continuation
    }

    deinit { changesContinuation.finish() }

    func requestAccess() async throws -> Bool { authorizationStatus == .fullAccess }
    func calendars() async throws -> [CalendarDescriptor] { descriptors }
    func events(
        from start: Date,
        to end: Date,
        calendarIDs: Set<String>
    ) async throws -> [CalendarEventSnapshot] {
        requests.append(Request(start: start, end: end, calendarIDs: calendarIDs))
        if let failure { throw failure }
        return snapshots.filter { calendarIDs.contains($0.calendarID) }
    }

    func clearRequests() {
        requests = []
    }

    func emitChange() { changesContinuation.yield(()) }
}

private func pendingCalendarCommandDescriptor(_ id: String) -> CalendarDescriptor {
    CalendarDescriptor(
        id: id,
        title: id.capitalized,
        sourceTitle: "Account",
        color: CalendarColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
    )
}

private func pendingCalendarCommandEvent(
    id: String,
    title: String,
    start: Date,
    calendarID: String = "work"
) -> CalendarEventSnapshot {
    CalendarEventSnapshot(
        id: id,
        calendarID: calendarID,
        calendarTitle: "Work",
        title: title,
        startDate: start,
        endDate: start.addingTimeInterval(60 * 60),
        isAllDay: false,
        attendeeNames: [],
        availability: .busy,
        participationStatus: .accepted
    )
}

private enum PendingCalendarCommandTestError: Error {
    case eventReadFailed
}

private final class PendingCalendarAlertCenterFake: CalendarNotificationCenter {
    var authorizationStatus: CalendarNotificationAuthorizationStatus = .authorized
    var authorizationRequestResult = true
    var authorizationRequestError: Error?
    private(set) var authorizationRequestCount = 0
    private(set) var added: [CalendarNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []
    private var pending: [CalendarNotificationRequest]

    init(pending: [CalendarNotificationRequest] = []) {
        self.pending = pending
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        if let authorizationRequestError { throw authorizationRequestError }
        return authorizationRequestResult
    }

    func currentAuthorizationStatus() async -> CalendarNotificationAuthorizationStatus {
        authorizationStatus
    }

    func pendingRequests() async -> [CalendarNotificationRequest] { pending }

    func addOrReplace(_ request: CalendarNotificationRequest) async throws {
        added.append(request)
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        removedIdentifiers.append(contentsOf: identifiers)
        pending.removeAll { identifiers.contains($0.identifier) }
    }
}

private final class PendingCalendarAlertSignals {
    let hourTicks: AsyncStream<Void>
    let timeZoneChanges: AsyncStream<Void>
    private let hourContinuation: AsyncStream<Void>.Continuation
    private let timeZoneContinuation: AsyncStream<Void>.Continuation

    init() {
        let hour = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(8))
        hourTicks = hour.stream
        hourContinuation = hour.continuation
        let zone = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(8))
        timeZoneChanges = zone.stream
        timeZoneContinuation = zone.continuation
    }

    deinit {
        hourContinuation.finish()
        timeZoneContinuation.finish()
    }

    func emitHourTick() { hourContinuation.yield(()) }
    func emitTimeZoneChange() { timeZoneContinuation.yield(()) }
}

@MainActor
private func waitForPendingCalendarCommand(
    _ condition: @escaping () -> Bool,
    attempts: Int = 100
) async -> Bool {
    for _ in 0 ..< attempts {
        if condition() { return true }
        await Task.yield()
    }
    return condition()
}

@MainActor
func runPendingCalendarCommandTests() async {
    print("Running PendingCalendarCommandTests...")

    let startDate = Date(timeIntervalSince1970: 1_750_000_000)
    let payload: [AnyHashable: Any] = [
        "occurrenceID": "planning|1750000000",
        "title": "Planning",
        "startTimestamp": startDate.timeIntervalSince1970,
    ]

    let command = PendingCalendarCommand.notificationCommand(
        requestIdentifier: "timezoner.event.planning|1750000000.30",
        userInfo: payload
    )

    expectPendingCalendarCommand(
        command,
        PendingCalendarCommand(
            occurrenceID: "planning|1750000000",
            title: "Planning",
            startDate: startDate
        ),
        "a TimeZoner notification payload produces a value-only command"
    )
    expectPendingCalendarCommand(
        PendingCalendarCommand.notificationCommand(
            requestIdentifier: "com.example.other-app",
            userInfo: payload
        ),
        nil,
        "unrelated notification identifiers cannot route into TimeZoner"
    )
    expectPendingCalendarCommand(
        PendingCalendarCommand.notificationCommand(
            requestIdentifier: "timezoner.event.bad.30",
            userInfo: ["occurrenceID": "", "title": "Planning", "startTimestamp": 1],
        ),
        nil,
        "empty occurrence identifiers are rejected"
    )
    expectPendingCalendarCommand(
        PendingCalendarCommand.notificationCommand(
            requestIdentifier: "timezoner.event.bad.30",
            userInfo: ["occurrenceID": "bad", "title": "Planning", "startTimestamp": Double.nan],
        ),
        nil,
        "non-finite timestamps are rejected"
    )
    expectPendingCalendarCommand(
        PendingCalendarCommand.notificationCommand(
            requestIdentifier: "timezoner.event.bad.30",
            userInfo: ["occurrenceID": "bad", "title": "Planning", "startTimestamp": "1750000000"],
        ),
        nil,
        "non-numeric timestamps are rejected"
    )
    expectPendingCalendarCommand(
        PendingCalendarCommand.notificationCommand(
            requestIdentifier: "timezoner.event.bad.30",
            userInfo: ["occurrenceID": "bad", "title": "Planning", "startTimestamp": true],
        ),
        nil,
        "boolean timestamps are rejected as malformed payload types"
    )

    var routed: [PendingCalendarCommand] = []
    let queue = PendingCalendarCommandQueue { pending in
        routed.append(pending)
    }
    let second = PendingCalendarCommand(
        occurrenceID: "second",
        title: "Second",
        startDate: startDate.addingTimeInterval(60)
    )

    queue.enqueue(command!)
    queue.enqueue(second)
    await Task.yield()
    expectPendingCalendarCommand(routed, [], "commands remain in memory before panel readiness")

    queue.markReady()
    for _ in 0 ..< 10 { await Task.yield() }
    expectPendingCalendarCommand(
        routed,
        [command!, second],
        "readiness drains each queued command in FIFO order exactly once"
    )

    queue.markReady()
    await Task.yield()
    expectPendingCalendarCommand(
        routed,
        [command!, second],
        "repeated readiness cannot reconsume commands"
    )
    expectPendingCalendarCommandTrue(
        !UserDefaults.standard.dictionaryRepresentation().keys.contains(where: { $0.contains("PendingCalendarCommand") }),
        "commands have no persistence surface"
    )

    do {
        var firstRouteCanFinish = false
        var firstRouteStarted = false
        var serialRoutes: [String] = []
        let serialQueue = PendingCalendarCommandQueue { pending in
            if pending.occurrenceID == "first" {
                firstRouteStarted = true
                while !firstRouteCanFinish {
                    await Task.yield()
                }
            }
            serialRoutes.append(pending.occurrenceID)
        }
        let first = PendingCalendarCommand(occurrenceID: "first", title: "First", startDate: startDate)
        serialQueue.enqueue(first)
        serialQueue.markReady()
        for _ in 0 ..< 10 { await Task.yield() }
        expectPendingCalendarCommandTrue(firstRouteStarted, "the first ready command begins draining")

        serialQueue.enqueue(second)
        for _ in 0 ..< 10 { await Task.yield() }
        expectPendingCalendarCommand(serialRoutes, [], "a later command cannot pass a still-routing command")
        firstRouteCanFinish = true
        for _ in 0 ..< 10 { await Task.yield() }
        expectPendingCalendarCommand(serialRoutes, ["first", "second"], "commands arriving during a drain retain FIFO order")
    }

    do {
        let freshStart = startDate.addingTimeInterval(120)
        let reader = PendingCalendarCommandReaderFake()
        reader.descriptors = [pendingCalendarCommandDescriptor("work"), pendingCalendarCommandDescriptor("hidden")]
        let fresh = pendingCalendarCommandEvent(id: "fresh", title: "Fresh planning", start: freshStart, calendarID: "hidden")
        reader.snapshots = [fresh]
        let store = CalendarStore(provider: reader)

        let matched = await store.event(matching: "fresh", near: freshStart)
        expectPendingCalendarCommand(matched, fresh, "routing refreshes a matching occurrence directly from EventKit data")
        expectPendingCalendarCommand(reader.requests.first?.calendarIDs, ["work", "hidden"], "fresh lookup includes hidden calendars")
        expectPendingCalendarCommand(
            reader.requests.first.map { $0.end.timeIntervalSince($0.start) },
            10 * 60,
            "fresh lookup uses its own narrow bounded interval"
        )
        expectPendingCalendarCommand(store.events, [], "fresh lookup cannot replace the presentation snapshot")
        expectPendingCalendarCommand(store.activeInterval, nil, "fresh lookup cannot replace the presentation interval")
    }

    do {
        let fresh = pendingCalendarCommandEvent(id: "fresh-route", title: "Fresh title", start: startDate)
        var showCount = 0
        var selectedFresh: CalendarEventSnapshot?
        var selectedFallback: PendingCalendarCommand?
        let router = CalendarNotificationCommandRouter(
            resolveEvent: { _, _ in fresh },
            showPairedPanels: { showCount += 1 },
            selectEvent: { event, _ in selectedFresh = event },
            selectFallback: { occurrenceID, title, start, _ in
                selectedFallback = PendingCalendarCommand(occurrenceID: occurrenceID, title: title, startDate: start)
            }
        )

        await router.route(command!)
        expectPendingCalendarCommand(showCount, 1, "running, hidden, and cold-start routing share the paired-panel show path")
        expectPendingCalendarCommand(selectedFresh, fresh, "a fresh matching event wins over stored notification values")
        expectPendingCalendarCommand(selectedFallback, nil, "fresh selection does not take the fallback path")
    }

    do {
        var selectedFallback: PendingCalendarCommand?
        let router = CalendarNotificationCommandRouter(
            resolveEvent: { _, _ in throw PendingCalendarCommandTestError.eventReadFailed },
            showPairedPanels: {},
            selectEvent: { _, _ in },
            selectFallback: { occurrenceID, title, start, _ in
                selectedFallback = PendingCalendarCommand(occurrenceID: occurrenceID, title: title, startDate: start)
            }
        )

        await router.route(command!)
        expectPendingCalendarCommand(selectedFallback, command, "missing or unreadable calendar events use the stored absolute timestamp fallback")
    }

    expectPendingCalendarCommand(
        CalendarNotificationForegroundPolicy.presentation(
            requestIdentifier: "timezoner.event.planning|1750000000.30",
            userInfo: payload
        ),
        .bannerAndSound,
        "valid TimeZoner alerts present banner and sound in the foreground"
    )
    expectPendingCalendarCommand(
        CalendarNotificationForegroundPolicy.presentation(
            requestIdentifier: "timezoner.event.bad.30",
            userInfo: ["occurrenceID": "bad", "title": "", "startTimestamp": 1],
        ),
        .none,
        "malformed alerts have no foreground presentation policy"
    )

    do {
        let suiteName = "PendingCalendarCommandTests.lifecycle.granted.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(userDefaults: defaults, keys: .default)
        let preferences = CalendarPreferenceStore(userDefaults: defaults, storageKey: "calendar.preferences")
        let provider = PendingCalendarCommandReaderFake()
        provider.descriptors = [pendingCalendarCommandDescriptor("work")]
        provider.snapshots = [pendingCalendarCommandEvent(
            id: "scheduled",
            title: "Scheduled",
            start: startDate.addingTimeInterval(60 * 60)
        )]
        let center = PendingCalendarAlertCenterFake()
        let scheduler = CalendarNotificationScheduler(
            eventReader: provider,
            preferenceStore: preferences,
            notificationCenter: center,
            leadMinutes: { settings.notificationLeadMinutes }
        )
        let signals = PendingCalendarAlertSignals()
        let clock = CalendarClock(
            now: { startDate },
            hourTicks: signals.hourTicks,
            timeZoneChanges: signals.timeZoneChanges
        )
        let lifecycle = CalendarAlertLifecycleCoordinator(
            settings: settings,
            preferenceStore: preferences,
            calendarProvider: provider,
            calendarClock: clock,
            scheduler: scheduler,
            notificationCenter: center
        )

        await lifecycle.setGlobalAlertsEnabled(true)
        expectPendingCalendarCommand(settings.alertsEnabled, true, "granted global alerts persist only after authorization succeeds")
        expectPendingCalendarCommand(center.authorizationRequestCount, 1, "enabling global alerts is the only explicit authorization request path")
        expectPendingCalendarCommandTrue(!lifecycle.showsNotificationSettingsRecovery, "granted authorization clears notification recovery")
        expectPendingCalendarCommandTrue(!center.added.isEmpty, "granted global alerts reconcile the seven-day scheduler")

        let afterEnableCount = provider.requests.count
        provider.clearRequests()
        preferences.setAlertsEnabled(false, calendarID: "work")
        expectPendingCalendarCommandTrue(
            await waitForPendingCalendarCommand { provider.requests.count == 1 },
            "per-calendar alert changes trigger one reconciliation"
        )
        provider.clearRequests()
        signals.emitHourTick()
        signals.emitHourTick()
        expectPendingCalendarCommandTrue(
            await waitForPendingCalendarCommand { provider.requests.count == 1 },
            "coalesced hourly lifecycle ticks trigger one reconciliation"
        )
        provider.clearRequests()
        signals.emitTimeZoneChange()
        expectPendingCalendarCommandTrue(
            await waitForPendingCalendarCommand { provider.requests.count == 1 },
            "timezone changes trigger reconciliation through the injected clock")
        provider.clearRequests()
        settings.setNotificationLeadMinutes([15, 5])
        expectPendingCalendarCommandTrue(
            await waitForPendingCalendarCommand { provider.requests.count == 1 },
            "lead-time preference changes trigger reconciliation"
        )
        provider.clearRequests()
        provider.emitChange()
        expectPendingCalendarCommandTrue(
            await waitForPendingCalendarCommand { provider.requests.count == 1 },
            "EventKit changes from the shared provider trigger reconciliation"
        )
        expectPendingCalendarCommandTrue(afterEnableCount > 0, "authorization path performed the initial scheduler read")
    }

    do {
        let suiteName = "PendingCalendarCommandTests.lifecycle.denied.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(userDefaults: defaults, keys: .default)
        let preferences = CalendarPreferenceStore(userDefaults: defaults, storageKey: "calendar.preferences")
        let provider = PendingCalendarCommandReaderFake()
        provider.authorizationStatus = .fullAccess
        let stale = CalendarNotificationRequest(
            identifier: "timezoner.event.stale.30",
            title: "Stale",
            body: "Stale",
            fireDate: startDate,
            userInfo: CalendarNotificationUserInfo(occurrenceID: "stale", title: "Stale", startTimestamp: startDate.timeIntervalSince1970)
        )
        let otherApp = CalendarNotificationRequest(
            identifier: "com.example.keep",
            title: "Keep",
            body: "Keep",
            fireDate: startDate,
            userInfo: CalendarNotificationUserInfo(occurrenceID: "keep", title: "Keep", startTimestamp: startDate.timeIntervalSince1970)
        )
        let center = PendingCalendarAlertCenterFake(pending: [stale, otherApp])
        center.authorizationStatus = .denied
        center.authorizationRequestResult = false
        let lifecycle = CalendarAlertLifecycleCoordinator(
            settings: settings,
            preferenceStore: preferences,
            calendarProvider: provider,
            calendarClock: CalendarClock(now: { startDate }),
            scheduler: CalendarNotificationScheduler(eventReader: provider, preferenceStore: preferences, notificationCenter: center),
            notificationCenter: center
        )
        let displayStore = CalendarStore(provider: provider)

        await lifecycle.setGlobalAlertsEnabled(true)
        expectPendingCalendarCommand(settings.alertsEnabled, false, "denied notification permission restores the global toggle to off")
        expectPendingCalendarCommandTrue(lifecycle.showsNotificationSettingsRecovery, "denial exposes notification settings recovery")
        expectPendingCalendarCommand(center.authorizationRequestCount, 1, "denial still comes only from an explicit enable action")
        expectPendingCalendarCommand(provider.authorizationStatus, .fullAccess, "notification denial leaves Calendar display authorization untouched")
        expectPendingCalendarCommand(displayStore.authorizationStatus, .fullAccess, "notification denial leaves the calendar display store active")
        expectPendingCalendarCommand(center.removedIdentifiers, ["timezoner.event.stale.30"], "denial removes only TimeZoner-owned pending requests")
        expectPendingCalendarCommandTrue(
            await center.pendingRequests().contains(where: { $0.identifier == "com.example.keep" }),
            "notification recovery never removes another app's pending request"
        )

        settings.alertsEnabled = true
        await lifecycle.resolveLaunchAuthorization()
        expectPendingCalendarCommand(settings.alertsEnabled, false, "launch-time notification revocation resets a persisted on setting")
        expectPendingCalendarCommand(center.authorizationRequestCount, 1, "launch authorization resolution never prompts")

        let laterTimeZonerRequest = CalendarNotificationRequest(
            identifier: "timezoner.event.later.10",
            title: "Later",
            body: "Later",
            fireDate: startDate,
            userInfo: CalendarNotificationUserInfo(occurrenceID: "later", title: "Later", startTimestamp: startDate.timeIntervalSince1970)
        )
        try? await center.addOrReplace(laterTimeZonerRequest)
        await lifecycle.calendarPermissionDidBecomeUnavailable()
        expectPendingCalendarCommandTrue(
            center.removedIdentifiers.contains("timezoner.event.later.10"),
            "Calendar permission loss removes every pending TimeZoner request"
        )
        expectPendingCalendarCommandTrue(
            center.removedIdentifiers.allSatisfy { $0.hasPrefix("timezoner.event.") },
            "Calendar permission loss removes only TimeZoner-owned requests"
        )
    }
}
