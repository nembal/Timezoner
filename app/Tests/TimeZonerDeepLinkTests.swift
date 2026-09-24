import Foundation
import TimeZonerLib

private func expectEqualString(_ actual: String?, _ expected: String, _ label: String, line: Int = #line) {
    if actual == expected {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \"\(expected)\", got \"\(actual ?? "nil")\"")
    }
}

private func expectEqualInt(_ actual: Int, _ expected: Int, _ label: String, line: Int = #line) {
    if actual == expected {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \(expected), got \(actual)")
    }
}

private func expectDeepLinkNil(_ actual: TimeZonerDeepLink?, _ label: String, line: Int = #line) {
    if actual == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected nil, got \(String(describing: actual))")
    }
}

private func expectDeepLinkEqual(_ actual: TimeZonerDeepLink?, _ expected: TimeZonerDeepLink, _ label: String, line: Int = #line) {
    if actual == expected {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \(expected), got \(String(describing: actual))")
    }
}

func runTimeZonerDeepLinkTests() {
    print("Running TimeZonerDeepLinkTests...")

    if TimeZonerDeepLink.parse(URL(string: "timezoner://open")!) == .open {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL: expected timezoner://open to parse as .open")
    }

    let setLink = TimeZonerDeepLink.parse(URL(string: "timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF")!)
    if case .setTime(let hour, let minute, let zoneID, let label) = setLink {
        expectEqualInt(hour, 15, "set link hour")
        expectEqualInt(minute, 30, "set link minute")
        expectEqualString(zoneID, "America/Los_Angeles", "set link zone")
        expectEqualString(label, "SF", "set link label")
    } else {
        testsFailed += 1
        print("  FAIL: expected timezoner://set to parse as .setTime")
    }

    expectDeepLinkNil(
        TimeZonerDeepLink.parse(URL(string: "timezoner://set?hour=25&minute=30&zone=America%2FLos_Angeles")!),
        "invalid hour rejection"
    )

    expectDeepLinkNil(
        TimeZonerDeepLink.parse(URL(string: "https://set?hour=15&minute=30&zone=America%2FLos_Angeles")!),
        "wrong scheme rejection"
    )

    let router = DeepLinkRouter()
    router.pendingCommand = .setTime(hour: 9, minute: 5, zoneID: "America/New_York", label: "NYC")
    expectDeepLinkEqual(
        router.pendingCommand,
        .setTime(hour: 9, minute: 5, zoneID: "America/New_York", label: "NYC"),
        "router stores pending command"
    )

    router.pendingCommand = nil
    expectDeepLinkNil(router.pendingCommand, "router clears pending command")

    let deepLinkSurfaceDefaultsName = "TimeZonerDeepLinkTests.calendar-surface.\(UUID().uuidString)"
    let deepLinkSurfaceDefaults = UserDefaults(suiteName: deepLinkSurfaceDefaultsName)!
    defer { deepLinkSurfaceDefaults.removePersistentDomain(forName: deepLinkSurfaceDefaultsName) }
    let deepLinkPresentation = CalendarPresentationState(defaults: deepLinkSurfaceDefaults)
    let deepLinkZones = ZoneStore(userDefaults: deepLinkSurfaceDefaults, storageKey: "deep-link-zones")
    var addedMissingZoneAfterRestoring = false
    for deepLink in [
        TimeZonerDeepLink.open,
        TimeZonerDeepLink.setTime(hour: 15, minute: 30, zoneID: "America/Toronto", label: "Toronto")
    ] {
        deepLinkPresentation.enterCalendar(now: Date(timeIntervalSince1970: 1_750_000_000), calendar: .current)
        var operations: [String] = []
        TimeZonerDeepLinkPresentationRouter.route(
            deepLink,
            presentation: deepLinkPresentation,
            restoreTimeZonerPanel: { operations.append("restore") },
            apply: { command in
                switch command {
                case .open:
                    operations.append("open")
                case .setTime(_, _, let zoneID, let label):
                    operations.append("set")
                    addedMissingZoneAfterRestoring = deepLinkPresentation.destination == .timezoner
                        && !deepLinkZones.zones.contains(where: { $0.timeZoneId == zoneID })
                    if addedMissingZoneAfterRestoring {
                        deepLinkZones.add(label: label ?? "Toronto", timezoneId: zoneID)
                    }
                }
            }
        )
        if deepLinkPresentation.destination == .timezoner {
            testsPassed += 1
        } else {
            testsFailed += 1
            print("  FAIL: Calendar-mode deep links must restore the TimeZoner surface before they apply")
        }
        let expectedOperations = deepLink == .open ? ["restore", "open"] : ["restore", "set"]
        if operations == expectedOperations {
            testsPassed += 1
        } else {
            testsFailed += 1
            print("  FAIL: Calendar-mode deep link ordering expected \(expectedOperations), got \(operations)")
        }
    }
    if addedMissingZoneAfterRestoring,
       deepLinkZones.zones.contains(where: { $0.timeZoneId == "America/Toronto" }) {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL: a Calendar-mode set link must restore TimeZoner before adding its missing zone")
    }

    let controller = ReferenceMomentController(timeState: TimeState())
    let selectedEvent = CalendarEventSnapshot(
        id: "deep-link-event",
        calendarID: "work",
        calendarTitle: "Work",
        title: "Deep link context",
        startDate: Date(timeIntervalSince1970: 1_750_000_000),
        endDate: Date(timeIntervalSince1970: 1_750_003_600),
        isAllDay: false,
        attendeeNames: [],
        availability: .busy,
        participationStatus: .accepted
    )
    let losAngeles = TimeZone(identifier: "America/Los_Angeles")!
    controller.selectEvent(selectedEvent, sourceZone: losAngeles)

    if case .setTime(let hour, let minute, let zoneID, _) = setLink,
       let zone = TimeZone(identifier: zoneID) {
        controller.setTime(hour: hour, minute: minute, in: zone)
    }

    if controller.selectedEvent == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL: set deep link must clear selected event context through the reference controller")
    }
}
