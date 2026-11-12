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
        expectTrueS(s.showAgendaWing, "default agenda wing is visible")
        expectTrueS(s.alertsEnabled == false, "default global calendar alerts are disabled")
        expectTrueS(s.notificationLeadMinutes == [30, 10], "default notification leads are thirty and ten minutes")
    }

    do {
        defaults.set(false, forKey: keys.showAgendaWing)
        let hidden = SettingsStore(userDefaults: defaults, keys: keys)
        expectTrueS(!hidden.showAgendaWing, "explicit hidden preference survives the new default")
        defaults.removeObject(forKey: keys.showAgendaWing)
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

    // ── Test 6: Lead fields keep independent uncommitted drafts ───────────
    do {
        let s = SettingsStore(userDefaults: defaults, keys: keys)
        s.setNotificationLeadMinutes([30, 10])
        let drafts = CalendarNotificationLeadDrafts(committedLeadMinutes: s.notificationLeadMinutes)

        drafts.edit("", at: 0)
        expectTrueS(s.notificationLeadMinutes == [30, 10], "clearing the first lead is only a local draft until commit")
        expectTrueS(drafts.value(at: 1) == "10", "clearing the first lead never shifts the sibling draft")

        drafts.edit("6", at: 0)
        expectTrueS(s.notificationLeadMinutes == [30, 10], "partially typing the first lead cannot normalize the stored schedule")
        expectTrueS(drafts.value(at: 1) == "10", "partial first-lead input preserves the sibling draft")

        drafts.edit("60", at: 0)
        expectTrueS(drafts.commit(at: 0, settings: s), "a valid completed lead draft commits")
        expectTrueS(s.notificationLeadMinutes == [60, 10], "editing thirty to sixty preserves the unedited ten-minute reminder")
        expectTrueS(drafts.value(at: 1) == "10", "committing the first draft retains the sibling field value")

        drafts.edit("not a number", at: 0)
        expectTrueS(!drafts.commit(at: 0, settings: s), "invalid lead input is rejected on commit")
        expectTrueS(s.notificationLeadMinutes == [60, 10], "invalid lead input cannot mutate the committed schedule")
        expectTrueS(drafts.value(at: 1) == "10", "invalid first-lead input cannot mutate the sibling draft")
    }

    // ── Test 7: Empty completed lead fields disable only that slot ─────────
    do {
        let clearFirst = SettingsStore(userDefaults: defaults, keys: keys)
        clearFirst.setNotificationLeadMinutes([30, 10])
        let firstDrafts = CalendarNotificationLeadDrafts(committedLeadMinutes: clearFirst.notificationLeadMinutes)
        firstDrafts.edit("", at: 0)
        expectTrueS(firstDrafts.commit(at: 0, settings: clearFirst), "submitting an empty first lead accepts an intentional disable")
        expectTrueS(clearFirst.notificationLeadMinutes == [10], "clearing the first lead preserves the ten-minute sibling")
        expectTrueS(firstDrafts.value(at: 1) == "10", "clearing the first lead keeps its sibling draft stable")

        let clearSecond = SettingsStore(userDefaults: defaults, keys: keys)
        clearSecond.setNotificationLeadMinutes([30, 10])
        let secondDrafts = CalendarNotificationLeadDrafts(committedLeadMinutes: clearSecond.notificationLeadMinutes)
        secondDrafts.edit("", at: 1)
        expectTrueS(secondDrafts.commit(at: 1, settings: clearSecond), "submitting an empty second lead accepts an intentional disable")
        expectTrueS(clearSecond.notificationLeadMinutes == [30], "clearing the second lead preserves the thirty-minute sibling")
        expectTrueS(secondDrafts.value(at: 0) == "30", "clearing the second lead keeps its sibling draft stable")

        let clearBoth = SettingsStore(userDefaults: defaults, keys: keys)
        clearBoth.setNotificationLeadMinutes([30, 10])
        let bothDrafts = CalendarNotificationLeadDrafts(committedLeadMinutes: clearBoth.notificationLeadMinutes)
        bothDrafts.edit("", at: 0)
        expectTrueS(bothDrafts.commit(at: 0, settings: clearBoth), "clearing the first of two leads commits before clearing the second")
        bothDrafts.edit("\n\t ", at: 1)
        expectTrueS(bothDrafts.commit(at: 1, settings: clearBoth), "whitespace-only completed lead input disables the second lead")
        expectTrueS(clearBoth.notificationLeadMinutes.isEmpty, "clearing both completed leads disables all custom alerts")

        let duplicate = SettingsStore(userDefaults: defaults, keys: keys)
        duplicate.setNotificationLeadMinutes([30, 10])
        let duplicateDrafts = CalendarNotificationLeadDrafts(committedLeadMinutes: duplicate.notificationLeadMinutes)
        duplicateDrafts.edit("10", at: 0)
        expectTrueS(duplicateDrafts.commit(at: 0, settings: duplicate), "a duplicate completed lead still normalizes the persisted schedule")
        expectTrueS(duplicate.notificationLeadMinutes == [10], "duplicate completed leads normalize to one scheduler value")
        duplicateDrafts.edit("", at: 1)
        expectTrueS(duplicateDrafts.commit(at: 1, settings: duplicate), "clearing one duplicate completed lead is accepted")
        expectTrueS(duplicate.notificationLeadMinutes == [10], "clearing one duplicate keeps the remaining lead enabled")

        let reopened = CalendarNotificationLeadDrafts(committedLeadMinutes: duplicate.notificationLeadMinutes)
        expectTrueS(reopened.value(at: 0) == "10" && reopened.value(at: 1).isEmpty, "reopening drafts reflects the persisted one-lead schedule")
    }
}
