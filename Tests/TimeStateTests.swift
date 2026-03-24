import Foundation
import TimeZonerLib

// ── Helper ──────────────────────────────────────────────────────────

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

private func hourAndMinute(of date: Date, in zone: TimeZone) -> (Int, Int) {
    var calendar = Calendar.current
    calendar.timeZone = zone
    let comps = calendar.dateComponents([.hour, .minute], from: date)
    return (comps.hour!, comps.minute!)
}

// ── Tests ────────────────────────────────────────────────────────────

func runTimeStateTests() {
    print("Running TimeStateTests...")

    let bangkok = TimeZone(identifier: "Asia/Bangkok")!       // UTC+7
    let sf      = TimeZone(identifier: "America/Los_Angeles")! // UTC-7 (PDT in July)
    let ny      = TimeZone(identifier: "America/New_York")!    // UTC-4 (EDT in July)
    let cet     = TimeZone(identifier: "Europe/Paris")!        // UTC+2 (CEST in July)

    // ── Test 1: Set 11:30 AM Bangkok, check other zones ──────────

    // Use July 1 2025 to avoid DST ambiguity
    let state = TimeState()
    // First set referenceDate to a known date in Bangkok
    var cal = Calendar.current
    cal.timeZone = bangkok
    var baseComps = DateComponents()
    baseComps.year = 2025
    baseComps.month = 7
    baseComps.day = 1
    baseComps.hour = 12
    baseComps.minute = 0
    state.referenceDate = cal.date(from: baseComps)!

    // Now set time to 11:30 in Bangkok
    state.setTime(hour: 11, minute: 30, in: bangkok)

    // Bangkok: 11:30 AM (UTC+7) => UTC 04:30
    // SF (PDT, UTC-7): 04:30 - 7 = 21:30 previous day => but let's compute:
    // UTC 04:30 => SF (UTC-7) = 21:30 (previous day, June 30)
    let (sfHour1, sfMin1) = hourAndMinute(of: state.time(in: sf), in: sf)
    expectEqualInt(sfHour1, 21, "Bangkok 11:30 -> SF hour")
    expectEqualInt(sfMin1, 30, "Bangkok 11:30 -> SF minute")

    // NY (EDT, UTC-4): 04:30 - 4 = 00:30 (July 1)
    let (nyHour1, nyMin1) = hourAndMinute(of: state.time(in: ny), in: ny)
    expectEqualInt(nyHour1, 0, "Bangkok 11:30 -> NY hour")
    expectEqualInt(nyMin1, 30, "Bangkok 11:30 -> NY minute")

    // CET (CEST, UTC+2): 04:30 + 2 = 06:30 (July 1)
    let (cetHour1, cetMin1) = hourAndMinute(of: state.time(in: cet), in: cet)
    expectEqualInt(cetHour1, 6, "Bangkok 11:30 -> CET hour")
    expectEqualInt(cetMin1, 30, "Bangkok 11:30 -> CET minute")

    // ── Test 2: Set 3:00 PM SF, check Bangkok & NY ──────────────

    state.setTime(hour: 15, minute: 0, in: sf)

    // SF 15:00 PDT (UTC-7) => UTC 22:00 (June 30)
    // Wait — we need to be careful. After test 1, referenceDate is July 1 04:30 UTC.
    // setTime keeps the year/month/day in the given zone.
    // In SF zone, July 1 04:30 UTC = June 30 21:30 PDT. So date components in SF = June 30.
    // setTime(15:00, SF) => June 30 15:00 PDT = June 30 22:00 UTC.
    // Bangkok (UTC+7): June 30 22:00 + 7 = July 1 05:00
    let (bkkHour2, bkkMin2) = hourAndMinute(of: state.time(in: bangkok), in: bangkok)
    expectEqualInt(bkkHour2, 5, "SF 15:00 -> Bangkok hour")
    expectEqualInt(bkkMin2, 0, "SF 15:00 -> Bangkok minute")

    // NY (EDT, UTC-4): June 30 22:00 - 4 = June 30 18:00
    let (nyHour2, nyMin2) = hourAndMinute(of: state.time(in: ny), in: ny)
    expectEqualInt(nyHour2, 18, "SF 15:00 -> NY hour")
    expectEqualInt(nyMin2, 0, "SF 15:00 -> NY minute")

    // ── Test 3: ZoneInfo Codable round-trip ──────────────────────

    let zone = ZoneInfo(label: "Bangkok", timeZoneId: "Asia/Bangkok")
    let encoder = JSONEncoder()
    let decoder = JSONDecoder()
    do {
        let data = try encoder.encode(zone)
        let decoded = try decoder.decode(ZoneInfo.self, from: data)
        expectTrue(zone == decoded, "ZoneInfo Codable round-trip equality")
        expectTrue(zone.id == decoded.id, "ZoneInfo Codable round-trip id")
        expectTrue(zone.label == decoded.label, "ZoneInfo Codable round-trip label")
        expectTrue(zone.timeZoneId == decoded.timeZoneId, "ZoneInfo Codable round-trip timeZoneId")
    } catch {
        testsFailed += 4
        print("  FAIL ZoneInfo Codable round-trip threw: \(error)")
    }
}
