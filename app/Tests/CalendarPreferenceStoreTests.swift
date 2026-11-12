import Foundation
import TimeZonerLib

private func expectCalendarPreferenceEqual<T: Equatable>(
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

func runCalendarPreferenceStoreTests() {
    print("Running CalendarPreferenceStoreTests...")

    let suiteName = "calendar_preferences_test_\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        testsFailed += 1
        print("  FAIL could not create calendar preference UserDefaults suite")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let storageKey = "calendar.preferences"
    let store = CalendarPreferenceStore(userDefaults: defaults, storageKey: storageKey)

    expectCalendarPreferenceEqual(
        store.preference(for: "new-calendar"),
        CalendarPreference(isVisible: true, alertsEnabled: true),
        "newly discovered calendars default to visible with alerts enabled"
    )

    store.setVisible(false, calendarID: "work-calendar")
    expectCalendarPreferenceEqual(
        store.preference(for: "work-calendar"),
        CalendarPreference(isVisible: false, alertsEnabled: true),
        "hiding a calendar does not mute its alerts"
    )
    store.setAlertsEnabled(false, calendarID: "work-calendar")
    expectCalendarPreferenceEqual(
        store.preference(for: "work-calendar"),
        CalendarPreference(isVisible: false, alertsEnabled: false),
        "muting alerts preserves a hidden calendar"
    )
    store.setVisible(true, calendarID: "work-calendar")
    expectCalendarPreferenceEqual(
        store.preference(for: "work-calendar"),
        CalendarPreference(isVisible: true, alertsEnabled: false),
        "showing a calendar does not re-enable an explicit alert mute"
    )

    let reloaded = CalendarPreferenceStore(userDefaults: defaults, storageKey: storageKey)
    expectCalendarPreferenceEqual(
        reloaded.preference(for: "work-calendar"),
        CalendarPreference(isVisible: true, alertsEnabled: false),
        "per-calendar visibility and alerts persist independently"
    )

    if let data = defaults.data(forKey: storageKey),
       let saved = try? JSONDecoder().decode([String: CalendarPreference].self, from: data) {
        expectCalendarPreferenceEqual(
            saved["work-calendar"],
            CalendarPreference(isVisible: true, alertsEnabled: false),
            "preferences are persisted as a calendar-ID JSON dictionary"
        )
    } else {
        testsFailed += 1
        print("  FAIL preferences are not persisted as decodable JSON data")
    }

    store.setVisible(false, calendarID: "temporarily-disconnected")
    store.setAlertsEnabled(false, calendarID: "temporarily-disconnected")
    _ = store.preference(for: "currently-discovered")
    let afterDiscovery = CalendarPreferenceStore(userDefaults: defaults, storageKey: storageKey)
    expectCalendarPreferenceEqual(
        afterDiscovery.preference(for: "temporarily-disconnected"),
        CalendarPreference(isVisible: false, alertsEnabled: false),
        "preferences survive when a calendar is absent from a later discovery"
    )
}
