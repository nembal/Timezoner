import Foundation
import TimeZonerLib

// ── Helpers ──────────────────────────────────────────────────────────

private func expectEqualInt(_ a: Int, _ b: Int, _ label: String, line: Int = #line) {
    if a == b {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \(b), got \(a)")
    }
}

private func expectTrue(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected true, got false")
    }
}

// ── Tests ────────────────────────────────────────────────────────────

func runZoneStoreTests() {
    print("Running ZoneStoreTests...")

    // Use a unique key so we don't collide with real data
    let testKey = "zones_test_\(UUID().uuidString)"
    let defaults = UserDefaults.standard

    // Clean up before test (should be empty, but be safe)
    defaults.removeObject(forKey: testKey)

    // ── Test 1: Default zones count and content ─────────────────
    let store = ZoneStore(userDefaults: defaults, storageKey: testKey)
    expectEqualInt(store.zones.count, 4, "default zones count")
    expectTrue(store.zones[0].label == "Bangkok", "default zone 0 label")
    expectTrue(store.zones[0].timeZoneId == "Asia/Bangkok", "default zone 0 timeZoneId")
    expectTrue(store.zones[1].label == "SF", "default zone 1 label")
    expectTrue(store.zones[2].label == "New York", "default zone 2 label")
    expectTrue(store.zones[3].label == "Europe", "default zone 3 label")

    // ── Test 2: Adding a zone increases count ───────────────────
    store.add(label: "Tokyo", timezoneId: "Asia/Tokyo")
    expectEqualInt(store.zones.count, 5, "count after add")
    expectTrue(store.zones[4].label == "Tokyo", "added zone label")
    expectTrue(store.zones[4].timeZoneId == "Asia/Tokyo", "added zone timeZoneId")

    // ── Test 3: Removing a zone decreases count ─────────────────
    let toRemove = store.zones[4].id
    store.remove(id: toRemove)
    expectEqualInt(store.zones.count, 4, "count after remove")
    expectTrue(store.zones.allSatisfy({ $0.id != toRemove }), "removed zone no longer present")

    // ── Test 4: ZoneInfo array round-trips through JSON ─────────
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    do {
        let data = try encoder.encode(ZoneStore.defaults)
        let decoded = try decoder.decode([ZoneInfo].self, from: data)
        expectEqualInt(decoded.count, ZoneStore.defaults.count, "round-trip count")
        expectTrue(decoded == ZoneStore.defaults, "round-trip equality")
    } catch {
        testsFailed += 2
        print("  FAIL round-trip threw: \(error)")
    }

    // ── Test 5: Persistence — new store reads saved data ────────
    store.add(label: "Seoul", timezoneId: "Asia/Seoul")
    let store2 = ZoneStore(userDefaults: defaults, storageKey: testKey)
    expectEqualInt(store2.zones.count, 5, "persisted store count")
    expectTrue(store2.zones.last?.label == "Seoul", "persisted zone label")

    // Clean up
    defaults.removeObject(forKey: testKey)
}
