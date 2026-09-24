import Foundation
import TimeZonerLib

private final class CalendarNotificationReaderFake: CalendarEventReading {
    struct EventRequest: Equatable {
        let start: Date
        let end: Date
        let calendarIDs: Set<String>
    }

    var authorizationStatus: CalendarAuthorizationStatus = .fullAccess
    let descriptors: [CalendarDescriptor]
    let snapshots: [CalendarEventSnapshot]
    let changes: AsyncStream<Void>
    private(set) var eventRequests: [EventRequest] = []

    init(descriptors: [CalendarDescriptor], snapshots: [CalendarEventSnapshot]) {
        self.descriptors = descriptors
        self.snapshots = snapshots
        changes = AsyncStream { continuation in
            continuation.finish()
        }
    }

    func requestAccess() async throws -> Bool {
        authorizationStatus == .fullAccess
    }

    func calendars() async throws -> [CalendarDescriptor] {
        descriptors
    }

    func events(
        from start: Date,
        to end: Date,
        calendarIDs: Set<String>
    ) async throws -> [CalendarEventSnapshot] {
        eventRequests.append(EventRequest(start: start, end: end, calendarIDs: calendarIDs))
        return snapshots.filter { calendarIDs.contains($0.calendarID) }
    }
}

private final class CalendarNotificationCenterFake: CalendarNotificationCenter {
    var authorizationStatus: CalendarNotificationAuthorizationStatus = .authorized
    private(set) var authorizationRequestCount = 0
    private(set) var addedOrReplaced: [CalendarNotificationRequest] = []
    private(set) var removedIdentifiers: [String] = []
    private var pending: [CalendarNotificationRequest]

    init(pending: [CalendarNotificationRequest] = []) {
        self.pending = pending
    }

    func requestAuthorization() async throws -> Bool {
        authorizationRequestCount += 1
        return true
    }

    func currentAuthorizationStatus() async -> CalendarNotificationAuthorizationStatus {
        authorizationStatus
    }

    func pendingRequests() async -> [CalendarNotificationRequest] {
        pending
    }

    func addOrReplace(_ request: CalendarNotificationRequest) async throws {
        addedOrReplaced.append(request)
        pending.removeAll { $0.identifier == request.identifier }
        pending.append(request)
    }

    func removePendingRequests(withIdentifiers identifiers: [String]) async {
        removedIdentifiers.append(contentsOf: identifiers)
        pending.removeAll { identifiers.contains($0.identifier) }
    }
}

private func expectCalendarNotificationEqual<T: Equatable>(
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

private func expectCalendarNotificationTrue(
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

private func reconcileCalendarNotifications(
    _ scheduler: CalendarNotificationScheduler,
    now: Date,
    timeZone: TimeZone,
    line: Int = #line
) async -> Bool {
    do {
        try await scheduler.reconcile(now: now, timeZone: timeZone)
        return true
    } catch {
        testsFailed += 1
        print("  FAIL [line \(line)] notification reconciliation threw: \(error)")
        return false
    }
}

private func calendarNotificationDescriptor(_ id: String) -> CalendarDescriptor {
    CalendarDescriptor(
        id: id,
        title: id.capitalized,
        sourceTitle: "Calendar Account",
        color: CalendarColor(red: 0.2, green: 0.4, blue: 0.6, alpha: 1)
    )
}

private func calendarNotificationEvent(
    id: String,
    calendarID: String = "work",
    title: String = "Planning",
    startDate: Date,
    endDate: Date,
    isAllDay: Bool = false,
    participationStatus: EventParticipationStatus = .accepted
) -> CalendarEventSnapshot {
    CalendarEventSnapshot(
        id: id,
        calendarID: calendarID,
        calendarTitle: calendarID.capitalized,
        title: title,
        startDate: startDate,
        endDate: endDate,
        isAllDay: isAllDay,
        attendeeNames: [],
        availability: .busy,
        participationStatus: participationStatus
    )
}

func runCalendarNotificationTests() async {
    print("Running CalendarNotificationTests...")

    let now = Date(timeIntervalSince1970: 1_704_074_400) // 2024-01-01 02:00 UTC
    let bangkok = TimeZone(identifier: "Asia/Bangkok")!
    let suiteName = "calendar_notifications_test_\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        testsFailed += 1
        print("  FAIL could not create calendar notification UserDefaults suite")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    func preferenceStore() -> CalendarPreferenceStore {
        CalendarPreferenceStore(
            userDefaults: defaults,
            storageKey: "calendar.notifications.preferences"
        )
    }

    do {
        let event = calendarNotificationEvent(
            id: "weekly-planning|1704078000",
            title: "Weekly planning",
            startDate: Date(timeIntervalSince1970: 1_704_078_000), // 10:00 BKK
            endDate: Date(timeIntervalSince1970: 1_704_081_600)
        )
        let reader = CalendarNotificationReaderFake(
            descriptors: [calendarNotificationDescriptor("work")],
            snapshots: [event]
        )
        let center = CalendarNotificationCenterFake()
        let scheduler = CalendarNotificationScheduler(
            eventReader: reader,
            preferenceStore: preferenceStore(),
            notificationCenter: center
        )

        _ = await reconcileCalendarNotifications(scheduler, now: now, timeZone: bangkok)

        let requests = center.addedOrReplaced.sorted { $0.identifier < $1.identifier }
        expectCalendarNotificationEqual(requests.count, 2, "an eligible event receives the default 30 and 10 minute requests")
        expectCalendarNotificationEqual(
            requests.map(\.identifier),
            [
                "timezoner.event.weekly-planning|1704078000.10",
                "timezoner.event.weekly-planning|1704078000.30"
            ],
            "request identifiers include the occurrence ID and lead minutes"
        )
        expectCalendarNotificationEqual(
            requests.first { $0.identifier.hasSuffix(".30") }?.body,
            "Starts in 30 min · 10:00 BKK",
            "the request body names the lead and local event time"
        )
        expectCalendarNotificationEqual(
            requests.first { $0.identifier.hasSuffix(".30") }?.fireDate,
            Date(timeIntervalSince1970: 1_704_076_200),
            "a lead request fires before the event start"
        )
        expectCalendarNotificationEqual(
            requests.first { $0.identifier.hasSuffix(".30") }?.userInfo.occurrenceID,
            "weekly-planning|1704078000",
            "request user info retains the occurrence ID"
        )
        expectCalendarNotificationEqual(
            requests.first { $0.identifier.hasSuffix(".30") }?.userInfo.title,
            "Weekly planning",
            "request user info retains the title"
        )
        expectCalendarNotificationEqual(
            requests.first { $0.identifier.hasSuffix(".30") }?.userInfo.startTimestamp,
            1_704_078_000,
            "request user info retains the absolute event start timestamp"
        )
        expectCalendarNotificationEqual(center.authorizationRequestCount, 0, "reconciliation never requests notification authorization")
    }

    do {
        let visibleMuted = calendarNotificationEvent(
            id: "muted|1704081600",
            calendarID: "muted",
            startDate: Date(timeIntervalSince1970: 1_704_081_600),
            endDate: Date(timeIntervalSince1970: 1_704_085_200)
        )
        let hiddenAlertEnabled = calendarNotificationEvent(
            id: "hidden|1704085200",
            calendarID: "hidden",
            title: "Hidden calendar event",
            startDate: Date(timeIntervalSince1970: 1_704_085_200),
            endDate: Date(timeIntervalSince1970: 1_704_088_800)
        )
        let allDay = calendarNotificationEvent(
            id: "all-day|1704088800",
            startDate: Date(timeIntervalSince1970: 1_704_088_800),
            endDate: Date(timeIntervalSince1970: 1_704_092_400),
            isAllDay: true
        )
        let declined = calendarNotificationEvent(
            id: "declined|1704092400",
            startDate: Date(timeIntervalSince1970: 1_704_092_400),
            endDate: Date(timeIntervalSince1970: 1_704_096_000),
            participationStatus: .declined
        )
        let ended = calendarNotificationEvent(
            id: "ended|1704067200",
            startDate: Date(timeIntervalSince1970: 1_704_067_200),
            endDate: Date(timeIntervalSince1970: 1_704_070_800)
        )
        let preferences = preferenceStore()
        preferences.setAlertsEnabled(false, calendarID: "muted")
        preferences.setVisible(false, calendarID: "hidden")
        let reader = CalendarNotificationReaderFake(
            descriptors: [
                calendarNotificationDescriptor("work"),
                calendarNotificationDescriptor("muted"),
                calendarNotificationDescriptor("hidden")
            ],
            snapshots: [visibleMuted, hiddenAlertEnabled, allDay, declined, ended]
        )
        let center = CalendarNotificationCenterFake()
        let scheduler = CalendarNotificationScheduler(
            eventReader: reader,
            preferenceStore: preferences,
            notificationCenter: center
        )

        _ = await reconcileCalendarNotifications(scheduler, now: now, timeZone: bangkok)

        expectCalendarNotificationEqual(
            center.addedOrReplaced.map(\.identifier).sorted(),
            [
                "timezoner.event.hidden|1704085200.10",
                "timezoner.event.hidden|1704085200.30"
            ],
            "all-day, declined, ended, and alert-muted events do not schedule while hidden alert-enabled calendars do"
        )
        expectCalendarNotificationEqual(
            reader.eventRequests.first?.calendarIDs,
            ["hidden", "work"],
            "the alert fetch includes hidden calendars with alerts enabled and excludes muted calendars"
        )
    }

    do {
        let event = calendarNotificationEvent(
            id: "soon|1704074700",
            startDate: Date(timeIntervalSince1970: 1_704_074_700),
            endDate: Date(timeIntervalSince1970: 1_704_078_300)
        )
        let reader = CalendarNotificationReaderFake(
            descriptors: [calendarNotificationDescriptor("work")],
            snapshots: [event]
        )
        let center = CalendarNotificationCenterFake()
        let scheduler = CalendarNotificationScheduler(
            eventReader: reader,
            preferenceStore: preferenceStore(),
            notificationCenter: center,
            leadMinutes: [30, 10, 10]
        )

        _ = await reconcileCalendarNotifications(scheduler, now: now, timeZone: bangkok)

        expectCalendarNotificationEqual(center.addedOrReplaced.count, 0, "past notification fire dates are never scheduled")
    }

    do {
        let event = calendarNotificationEvent(
            id: "mixed-leads|1704075600",
            startDate: Date(timeIntervalSince1970: 1_704_075_600),
            endDate: Date(timeIntervalSince1970: 1_704_079_200)
        )
        let reader = CalendarNotificationReaderFake(
            descriptors: [calendarNotificationDescriptor("work")],
            snapshots: [event]
        )
        let center = CalendarNotificationCenterFake()
        let scheduler = CalendarNotificationScheduler(
            eventReader: reader,
            preferenceStore: preferenceStore(),
            notificationCenter: center
        )

        _ = await reconcileCalendarNotifications(scheduler, now: now, timeZone: bangkok)

        expectCalendarNotificationEqual(
            center.addedOrReplaced.map(\.identifier),
            ["timezoner.event.mixed-leads|1704075600.10"],
            "only future fire dates survive when an event is inside one lead window"
        )
    }

    do {
        let event = calendarNotificationEvent(
            id: "deduplicated|1704081600",
            startDate: Date(timeIntervalSince1970: 1_704_081_600),
            endDate: Date(timeIntervalSince1970: 1_704_085_200)
        )
        let reader = CalendarNotificationReaderFake(
            descriptors: [calendarNotificationDescriptor("work")],
            snapshots: [event]
        )
        let center = CalendarNotificationCenterFake()
        let scheduler = CalendarNotificationScheduler(
            eventReader: reader,
            preferenceStore: preferenceStore(),
            notificationCenter: center,
            leadMinutes: [30, 10, 10]
        )

        _ = await reconcileCalendarNotifications(scheduler, now: now, timeZone: bangkok)

        expectCalendarNotificationEqual(center.addedOrReplaced.count, 2, "duplicate lead values produce one request per unique lead")
        expectCalendarNotificationEqual(
            Set(center.addedOrReplaced.map(\.identifier)).count,
            2,
            "duplicate lead values cannot duplicate a request identifier"
        )
    }

    do {
        let event = calendarNotificationEvent(
            id: "current|1704081600",
            startDate: Date(timeIntervalSince1970: 1_704_081_600),
            endDate: Date(timeIntervalSince1970: 1_704_085_200)
        )
        let staleTimeZonerRequest = CalendarNotificationRequest(
            identifier: "timezoner.event.removed|1700000000.30",
            title: "Removed event",
            body: "Starts in 30 min · 10:00 BKK",
            fireDate: Date(timeIntervalSince1970: 1_704_078_000),
            userInfo: CalendarNotificationUserInfo(
                occurrenceID: "removed|1700000000",
                title: "Removed event",
                startTimestamp: 1_700_000_000
            )
        )
        let otherAppRequest = CalendarNotificationRequest(
            identifier: "com.example.other-app.reminder",
            title: "Other app",
            body: "Keep me",
            fireDate: Date(timeIntervalSince1970: 1_704_078_000),
            userInfo: CalendarNotificationUserInfo(
                occurrenceID: "other",
                title: "Other app",
                startTimestamp: 1_704_078_000
            )
        )
        let reader = CalendarNotificationReaderFake(
            descriptors: [calendarNotificationDescriptor("work")],
            snapshots: [event]
        )
        let center = CalendarNotificationCenterFake(pending: [staleTimeZonerRequest, otherAppRequest])
        let scheduler = CalendarNotificationScheduler(
            eventReader: reader,
            preferenceStore: preferenceStore(),
            notificationCenter: center
        )

        _ = await reconcileCalendarNotifications(scheduler, now: now, timeZone: bangkok)

        expectCalendarNotificationEqual(
            center.removedIdentifiers,
            ["timezoner.event.removed|1700000000.30"],
            "reconciliation removes stale TimeZoner-owned requests only"
        )
        expectCalendarNotificationTrue(
            await center.pendingRequests().contains(where: { $0.identifier == "com.example.other-app.reminder" }),
            "reconciliation preserves pending requests owned by other apps"
        )
    }

    do {
        let reader = CalendarNotificationReaderFake(
            descriptors: [calendarNotificationDescriptor("work")],
            snapshots: []
        )
        let center = CalendarNotificationCenterFake()
        let scheduler = CalendarNotificationScheduler(
            eventReader: reader,
            preferenceStore: preferenceStore(),
            notificationCenter: center
        )

        _ = await reconcileCalendarNotifications(scheduler, now: now, timeZone: bangkok)

        expectCalendarNotificationEqual(reader.eventRequests.count, 1, "reconciliation fetches calendar events once")
        expectCalendarNotificationEqual(reader.eventRequests.first?.start, now, "the notification fetch begins at reconciliation time")
        expectCalendarNotificationEqual(
            reader.eventRequests.first?.end,
            Date(timeIntervalSince1970: 1_704_679_200),
            "the notification fetch owns a half-open seven-day horizon"
        )
    }
}
