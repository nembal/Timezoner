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
        hotkey: "s.hotkey"
    )

    // ── Test 1: Defaults on empty store ────────────────────────
    do {
        let s = SettingsStore(userDefaults: defaults, keys: keys)
        expectTrueS(s.appearance == SettingsStore.AppearancePref.system, "default appearance is system")
        expectTrueS(s.launchAtLogin == false, "default launchAtLogin is false")
        expectTrueS(s.hotkey == SettingsStore.defaultHotkey, "default hotkey is ⌘⌥T")
    }

    // ── Test 2: Round-trip through UserDefaults ────────────────
    do {
        let s = SettingsStore(userDefaults: defaults, keys: keys)
        s.appearance = SettingsStore.AppearancePref.dark
        s.launchAtLogin = true
        s.hotkey = SettingsStore.Shortcut(keyCode: 49, modifiers: 0x0100, display: "⌘Space")

        let reloaded = SettingsStore(userDefaults: defaults, keys: keys)
        expectTrueS(reloaded.appearance == SettingsStore.AppearancePref.dark, "persisted appearance")
        expectTrueS(reloaded.launchAtLogin == true, "persisted launchAtLogin")
        expectTrueS(reloaded.hotkey?.display == "⌘Space", "persisted hotkey display")
        expectTrueS(reloaded.hotkey?.keyCode == 49, "persisted hotkey keyCode")
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
}
