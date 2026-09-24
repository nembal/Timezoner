import Foundation
import TimeZonerLib

private func expectEqualStr(_ a: String, _ b: String, _ label: String, line: Int = #line) {
    if a == b {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \(b), got \(a)")
    }
}

private func expectTrueS(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected true, got false")
    }
}

func runSettingsStoreTests() {
    print("Running SettingsStoreTests...")

    let suiteName = "settings_test_\(UUID().uuidString)"
    guard let defaults = UserDefaults(suiteName: suiteName) else {
        testsFailed += 1
        print("  FAIL could not create test UserDefaults suite")
        return
    }
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let keys = SettingsStore.Keys(
        appearance: "s.appearance",
        launchAtLogin: "s.launchAtLogin",
        hotkey: "s.hotkey",
        showAgendaWing: "s.showAgendaWing",
        alertsEnabled: "s.alertsEnabled",
        notificationLeadMinutes: "s.notificationLeadMinutes"
    )

    // ── Test 1: Defaults on empty store ────────────────────────
    do {
        let s = SettingsStore(userDefaults: defaults, keys: keys)
        expectTrueS(s.appearance == SettingsStore.AppearancePref.system, "default appearance is system")
        expectTrueS(s.launchAtLogin == false, "default launchAtLogin is false")
        expectTrueS(s.hotkey == SettingsStore.defaultHotkey, "default hotkey is ⌘⌥T")
        expectTrueS(s.showAgendaWing == false, "default agenda wing is hidden")
        expectTrueS(s.alertsEnabled == false, "default global calendar alerts are disabled")
        expectTrueS(s.notificationLeadMinutes == [30, 10], "default notification leads are thirty and ten minutes")
    }

    // ── Test 2: Round-trip through UserDefaults ────────────────
    do {
        let s = SettingsStore(userDefaults: defaults, keys: keys)
        s.appearance = SettingsStore.AppearancePref.dark
        s.launchAtLogin = true
        s.hotkey = SettingsStore.Shortcut(keyCode: 49, modifiers: 0x0100, display: "⌘Space")
        s.showAgendaWing = true
        s.alertsEnabled = true
        s.setNotificationLeadMinutes([nil, -1, 1_441, 10, 10, 30])

        let reloaded = SettingsStore(userDefaults: defaults, keys: keys)
        expectTrueS(reloaded.appearance == SettingsStore.AppearancePref.dark, "persisted appearance")
        expectTrueS(reloaded.launchAtLogin == true, "persisted launchAtLogin")
        expectTrueS(reloaded.hotkey?.display == "⌘Space", "persisted hotkey display")
        expectTrueS(reloaded.hotkey?.keyCode == 49, "persisted hotkey keyCode")
        expectTrueS(reloaded.showAgendaWing, "persisted agenda wing visibility")
        expectTrueS(reloaded.alertsEnabled, "persisted global calendar alerts")
        expectTrueS(reloaded.notificationLeadMinutes == [30, 10], "persisted normalized notification leads")
        if let data = defaults.data(forKey: keys.notificationLeadMinutes),
           let saved = try? JSONDecoder().decode([Int].self, from: data) {
            expectTrueS(saved == [30, 10], "notification leads persist as normalized JSON integers")
        } else {
            testsFailed += 1
            print("  FAIL notification leads are not persisted as decodable JSON data")
        }
    }

    // ── Test 3: Nil hotkey persists as nil ─────────────────────
    do {
        let s = SettingsStore(userDefaults: defaults, keys: keys)
        s.hotkey = nil
        let reloaded = SettingsStore(userDefaults: defaults, keys: keys)
        expectTrueS(reloaded.hotkey == nil, "cleared hotkey persists as nil")
    }

    // ── Test 4: Shortcut JSON round-trip ───────────────────────
    do {
        let original = SettingsStore.Shortcut(keyCode: 0x11, modifiers: 0x0900, display: "⌘⌥T")
        let data = try JSONEncoder().encode(original)
        let decoded = try JSONDecoder().decode(SettingsStore.Shortcut.self, from: data)
        expectTrueS(decoded == original, "shortcut JSON round-trip equal")
        expectEqualStr(decoded.display, "⌘⌥T", "shortcut display round-trip")
    } catch {
        testsFailed += 2
        print("  FAIL shortcut round-trip threw: \(error)")
    }

    // ── Test 5: Notification lead normalization ────────────────
    do {
        expectTrueS(
            SettingsStore.normalizedNotificationLeadMinutes([nil, -1, 1_441, 10, 10, 30]) == [30, 10],
            "lead normalization drops nil, out-of-range, and duplicate entries before sorting"
        )
        expectTrueS(
            SettingsStore.normalizedNotificationLeadMinutes([10, 30, 0, 1_440]) == [1_440, 30, 10, 0],
            "lead normalization keeps valid boundary values in descending order"
        )

        let s = SettingsStore(userDefaults: defaults, keys: keys)
        s.setNotificationLeadMinutes([])
        expectTrueS(s.notificationLeadMinutes.isEmpty, "an empty lead list disables both alert slots")

        defaults.set(Data([0xFF]), forKey: keys.notificationLeadMinutes)
        let malformed = SettingsStore(userDefaults: defaults, keys: keys)
        expectTrueS(malformed.notificationLeadMinutes == [30, 10], "malformed lead persistence falls back to defaults")
    }
}
