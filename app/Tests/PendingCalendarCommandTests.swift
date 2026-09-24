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
    private let requestLock = NSLock()
    private var recordedRequests: [Request] = []
    private var requestCountWaiters: [(minimumCount: Int, continuation: CheckedContinuation<Void, Never>)] = []
    let changes: AsyncStream<Void>
    private let changesContinuation: AsyncStream<Void>.Continuation

    init() {
        let stream = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(8))
        changes = stream.stream
        changesContinuation = stream.continuation
    }

    deinit { changesContinuation.finish() }

    var requests: [Request] {
        requestLock.lock()
        defer { requestLock.unlock() }
        return recordedRequests
    }

    func requestAccess() async throws -> Bool { authorizationStatus == .fullAccess }
    func calendars() async throws -> [CalendarDescriptor] { descriptors }
    func events(
        from start: Date,
        to end: Date,
        calendarIDs: Set<String>
    ) async throws -> [CalendarEventSnapshot] {
        let request = Request(start: start, end: end, calendarIDs: calendarIDs)
        let waiters = record(request)
        waiters.forEach { $0.resume() }
        if let failure { throw failure }
        return snapshots.filter { calendarIDs.contains($0.calendarID) }
    }

    func clearRequests() {
        requestLock.lock()
        recordedRequests = []
        requestLock.unlock()
    }

    func waitForRequestCount(_ minimumCount: Int) async {
        await withCheckedContinuation { continuation in
            requestLock.lock()
            if recordedRequests.count >= minimumCount {
                requestLock.unlock()
                continuation.resume()
            } else {
                requestCountWaiters.append((minimumCount, continuation))
                requestLock.unlock()
            }
        }
    }

    private func record(_ request: Request) -> [CheckedContinuation<Void, Never>] {
        requestLock.lock()
        recordedRequests.append(request)
        let waiters = requestCountWaiters
            .filter { recordedRequests.count >= $0.minimumCount }
            .map(\.continuation)
        requestCountWaiters.removeAll { recordedRequests.count >= $0.minimumCount }
        requestLock.unlock()
        return waiters
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

    do {
        let sourceZone = TimeZone(identifier: "Asia/Bangkok")!
        var freshSelectionCount = 0
        var selectedFallback: PendingCalendarCommand?
        let router = CalendarNotificationCommandRouter(
            resolveEvent: { _, _ in nil },
            showPairedPanels: {},
            selectEvent: { _, _ in freshSelectionCount += 1 },
            selectFallback: { occurrenceID, title, start, zone in
                selectedFallback = PendingCalendarCommand(occurrenceID: occurrenceID, title: title, startDate: start)
                expectPendingCalendarCommand(zone.identifier, sourceZone.identifier, "missing event fallback preserves the router source zone")
            },
            sourceZone: { sourceZone }
        )

        await router.route(command!)
        expectPendingCalendarCommand(freshSelectionCount, 0, "a missing event cannot select a stale fresh snapshot")
        expectPendingCalendarCommand(selectedFallback, command, "a missing event selects the stored occurrence, title, and timestamp")
    }

    do {
        let suiteName = "PendingCalendarCommandTests.routing-accessibility.fresh.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let presentation = CalendarPresentationState(defaults: defaults)
        presentation.enterCalendar(now: startDate, calendar: .current)
        let fresh = pendingCalendarCommandEvent(id: "accessible-fresh", title: "Accessible fresh", start: startDate)
        var operations: [String] = []
        let router = CalendarNotificationCommandRouter(
            resolveEvent: { _, _ in fresh },
            prepareTimeZonerSurface: {
                operations.append("restore")
                presentation.returnToTimeZoner()
            },
            showPairedPanels: { operations.append("show") },
            selectEvent: { _, _ in operations.append("fresh") },
            selectFallback: { _, _, _, _ in operations.append("fallback") },
            focusSelectedEventContext: { operations.append("focus") }
        )

        await router.route(command!)
        expectPendingCalendarCommand(presentation.destination, .timezoner, "fresh alert routing restores TimeZoner before selecting the event")
        expectPendingCalendarCommand(operations, ["restore", "show", "fresh", "focus"], "fresh alert routing restores, presents, selects, then focuses the selected context")
    }

    do {
        let suiteName = "PendingCalendarCommandTests.routing-accessibility.fallback.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let presentation = CalendarPresentationState(defaults: defaults)
        presentation.enterCalendar(now: startDate, calendar: .current)
        var operations: [String] = []
        let router = CalendarNotificationCommandRouter(
            resolveEvent: { _, _ in nil },
            prepareTimeZonerSurface: {
                operations.append("restore")
                presentation.returnToTimeZoner()
            },
            showPairedPanels: { operations.append("show") },
            selectEvent: { _, _ in operations.append("fresh") },
            selectFallback: { _, _, _, _ in operations.append("fallback") },
            focusSelectedEventContext: { operations.append("focus") }
        )

        await router.route(command!)
        expectPendingCalendarCommand(presentation.destination, .timezoner, "fallback alert routing restores TimeZoner before selecting stored event context")
        expectPendingCalendarCommand(operations, ["restore", "show", "fallback", "focus"], "fallback alert routing restores, presents, selects, then focuses the selected context")
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
        settings.setNotificationLeadMinutes([15, 5])
        expectPendingCalendarCommandTrue(
            await waitForPendingCalendarCommand { provider.requests.count == 1 },
            "lead-time preference changes trigger reconciliation"
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

    do {
        let suiteName = "PendingCalendarCommandTests.lifecycle.launch-authorized.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(userDefaults: defaults, keys: .default)
        settings.alertsEnabled = true
        let preferences = CalendarPreferenceStore(userDefaults: defaults, storageKey: "calendar.preferences")
        let provider = PendingCalendarCommandReaderFake()
        provider.descriptors = [pendingCalendarCommandDescriptor("work")]
        provider.snapshots = [pendingCalendarCommandEvent(
            id: "launch-authorized",
            title: "Launch authorized",
            start: startDate.addingTimeInterval(60 * 60)
        )]
        let center = PendingCalendarAlertCenterFake()
        let lifecycle = CalendarAlertLifecycleCoordinator(
            settings: settings,
            preferenceStore: preferences,
            calendarClock: CalendarClock(now: { startDate }),
            scheduler: CalendarNotificationScheduler(eventReader: provider, preferenceStore: preferences, notificationCenter: center),
            notificationCenter: center
        )

        await lifecycle.resolveLaunchAuthorization()
        expectPendingCalendarCommand(settings.alertsEnabled, true, "authorized persisted alerts remain enabled after launch resolution")
        expectPendingCalendarCommandTrue(!lifecycle.showsNotificationSettingsRecovery, "authorized persisted alerts hide recovery")
        expectPendingCalendarCommand(center.authorizationRequestCount, 0, "launch authorization resolution never prompts")
        expectPendingCalendarCommandTrue(provider.requests.count == 1 && !center.added.isEmpty, "authorized persisted alerts reconcile the seven-day scheduler on launch")
    }

    do {
        let first = CalendarNotificationRequest(
            identifier: "timezoner.event.first.30",
            title: "First",
            body: "First",
            fireDate: startDate,
            userInfo: CalendarNotificationUserInfo(occurrenceID: "first", title: "First", startTimestamp: startDate.timeIntervalSince1970)
        )
        let second = CalendarNotificationRequest(
            identifier: "timezoner.event.second.10",
            title: "Second",
            body: "Second",
            fireDate: startDate,
            userInfo: CalendarNotificationUserInfo(occurrenceID: "second", title: "Second", startTimestamp: startDate.timeIntervalSince1970)
        )
        let foreign = CalendarNotificationRequest(
            identifier: "com.example.foreign",
            title: "Foreign",
            body: "Foreign",
            fireDate: startDate,
            userInfo: CalendarNotificationUserInfo(occurrenceID: "foreign", title: "Foreign", startTimestamp: startDate.timeIntervalSince1970)
        )
        let suiteName = "PendingCalendarCommandTests.lifecycle.scoped-removal.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(userDefaults: defaults, keys: .default)
        let preferences = CalendarPreferenceStore(userDefaults: defaults, storageKey: "calendar.preferences")
        let provider = PendingCalendarCommandReaderFake()
        let center = PendingCalendarAlertCenterFake(pending: [first, second, foreign])
        let lifecycle = CalendarAlertLifecycleCoordinator(
            settings: settings,
            preferenceStore: preferences,
            calendarClock: CalendarClock(now: { startDate }),
            scheduler: CalendarNotificationScheduler(eventReader: provider, preferenceStore: preferences, notificationCenter: center),
            notificationCenter: center
        )

        await lifecycle.setGlobalAlertsEnabled(false)
        expectPendingCalendarCommand(Set(center.removedIdentifiers), Set([first.identifier, second.identifier]), "ordinary global disable removes every TimeZoner request")
        expectPendingCalendarCommandTrue(
            await center.pendingRequests().map(\.identifier) == [foreign.identifier],
            "ordinary global disable preserves foreign requests"
        )

        let revocationCenter = PendingCalendarAlertCenterFake(pending: [first, second, foreign])
        let revocationLifecycle = CalendarAlertLifecycleCoordinator(
            settings: settings,
            preferenceStore: preferences,
            calendarClock: CalendarClock(now: { startDate }),
            scheduler: CalendarNotificationScheduler(eventReader: provider, preferenceStore: preferences, notificationCenter: revocationCenter),
            notificationCenter: revocationCenter
        )
        await revocationLifecycle.calendarPermissionDidBecomeUnavailable()
        expectPendingCalendarCommand(Set(revocationCenter.removedIdentifiers), Set([first.identifier, second.identifier]), "Calendar permission loss removes every TimeZoner request")
        expectPendingCalendarCommandTrue(
            await revocationCenter.pendingRequests().map(\.identifier) == [foreign.identifier],
            "Calendar permission loss preserves foreign requests"
        )
    }

    do {
        let suiteName = "PendingCalendarCommandTests.lifecycle.revocation.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(userDefaults: defaults, keys: .default)
        let preferences = CalendarPreferenceStore(userDefaults: defaults, storageKey: "calendar.preferences")
        let provider = PendingCalendarCommandReaderFake()
        provider.descriptors = [pendingCalendarCommandDescriptor("work")]
        provider.snapshots = [pendingCalendarCommandEvent(
            id: "revocation",
            title: "Revocation",
            start: startDate.addingTimeInterval(60 * 60)
        )]
        let center = PendingCalendarAlertCenterFake()
        let lifecycle = CalendarAlertLifecycleCoordinator(
            settings: settings,
            preferenceStore: preferences,
            calendarClock: CalendarClock(now: { startDate }),
            scheduler: CalendarNotificationScheduler(eventReader: provider, preferenceStore: preferences, notificationCenter: center),
            notificationCenter: center
        )
        await lifecycle.setGlobalAlertsEnabled(true)
        let otherApp = CalendarNotificationRequest(
            identifier: "com.example.keep-after-revocation",
            title: "Keep",
            body: "Keep",
            fireDate: startDate,
            userInfo: CalendarNotificationUserInfo(occurrenceID: "keep", title: "Keep", startTimestamp: startDate.timeIntervalSince1970)
        )
        try? await center.addOrReplace(otherApp)
        center.authorizationStatus = .denied

        lifecycle.requestReconciliation()
        expectPendingCalendarCommandTrue(
            await waitForPendingCalendarCommand {
                !settings.alertsEnabled
                    && lifecycle.showsNotificationSettingsRecovery
                    && center.removedIdentifiers.contains(where: { $0.hasPrefix("timezoner.event.") })
            },
            "post-launch notification revocation resets alerts and exposes settings recovery"
        )
        expectPendingCalendarCommandTrue(
            center.removedIdentifiers.contains(where: { $0.hasPrefix("timezoner.event.") }),
            "post-launch notification revocation removes stale TimeZoner requests"
        )
        expectPendingCalendarCommand(provider.authorizationStatus, .fullAccess, "post-launch notification revocation leaves calendar display authorization active")
        expectPendingCalendarCommandTrue(
            await center.pendingRequests().contains(where: { $0.identifier == "com.example.keep-after-revocation" }),
            "post-launch notification revocation preserves other apps' pending requests"
        )
    }

    do {
        let suiteName = "PendingCalendarCommandTests.lifecycle.composition.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let settings = SettingsStore(userDefaults: defaults, keys: .default)
        let preferences = CalendarPreferenceStore(userDefaults: defaults, storageKey: "calendar.preferences")
        let provider = PendingCalendarCommandReaderFake()
        provider.descriptors = [pendingCalendarCommandDescriptor("work")]
        provider.snapshots = [pendingCalendarCommandEvent(
            id: "composition",
            title: "Composition",
            start: startDate.addingTimeInterval(60 * 60)
        )]
        let center = PendingCalendarAlertCenterFake()
        let signals = PendingCalendarAlertSignals()
        let clock = CalendarClock(
            now: { startDate },
            hourTicks: signals.hourTicks,
            timeZoneChanges: signals.timeZoneChanges
        )
        let scheduler = CalendarNotificationScheduler(
            eventReader: provider,
            preferenceStore: preferences,
            notificationCenter: center
        )
        var lifecycle: CalendarAlertLifecycleCoordinator?
        var providerForwards = 0
        var hourForwards = 0
        var timeZoneForwards = 0
        let calendarStore = CalendarStore(
            provider: provider,
            preferenceStore: preferences,
            clock: clock,
            onCalendarProviderChange: {
                providerForwards += 1
                lifecycle?.requestReconciliation()
            },
            onHourTick: {
                hourForwards += 1
                lifecycle?.requestReconciliation()
            },
            onTimeZoneChange: {
                timeZoneForwards += 1
                lifecycle?.requestReconciliation()
            }
        )
        lifecycle = CalendarAlertLifecycleCoordinator(
            settings: settings,
            preferenceStore: preferences,
            calendarClock: clock,
            scheduler: scheduler,
            notificationCenter: center
        )
        await lifecycle?.setGlobalAlertsEnabled(true)
        calendarStore.refresh(interval: DateInterval(start: startDate, duration: 60 * 60))
        _ = await waitForPendingCalendarCommand { !calendarStore.isLoading }

        provider.clearRequests()
        provider.emitChange()
        await provider.waitForRequestCount(2)
        expectPendingCalendarCommand(
            providerForwards,
            1,
            "one CalendarStore provider observer forwards one alert reconciliation"
        )
        expectPendingCalendarCommand(
            Set(provider.requests.map { $0.end.timeIntervalSince($0.start) }),
            Set([60 * 60, 7 * 24 * 60 * 60]),
            "provider changes complete the presentation and seven-day alert fetches"
        )

        provider.clearRequests()
        signals.emitHourTick()
        await provider.waitForRequestCount(1)
        expectPendingCalendarCommand(
            hourForwards,
            1,
            "one CalendarStore hourly observer forwards the alert lifecycle without a competing iterator"
        )
        expectPendingCalendarCommand(
            provider.requests.map { $0.end.timeIntervalSince($0.start) },
            [7 * 24 * 60 * 60],
            "hourly forwarding completes one seven-day alert fetch"
        )

        provider.clearRequests()
        signals.emitTimeZoneChange()
        await provider.waitForRequestCount(2)
        expectPendingCalendarCommand(
            timeZoneForwards,
            1,
            "one CalendarStore timezone observer forwards alerts exactly once"
        )
        expectPendingCalendarCommand(
            Set(provider.requests.map { $0.end.timeIntervalSince($0.start) }),
            Set([3 * 24 * 60 * 60, 7 * 24 * 60 * 60]),
            "timezone changes complete the refreshed presentation and seven-day alert fetches"
        )
    }
}
