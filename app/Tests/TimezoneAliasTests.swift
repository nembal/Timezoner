import Foundation
import TimeZonerLib

// ── Mini test framework ──────────────────────────────────────────────

var testsPassed = 0
var testsFailed = 0

func expectEqual(_ a: String?, _ b: String, _ label: String, line: Int = #line) {
    if a == b {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \"\(b)\", got \"\(a ?? "nil")\"")
    }
}

func expectNil(_ a: TimeZone?, _ label: String, line: Int = #line) {
    if a == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected nil, got \(a!.identifier)")
    }
}

// ── Tests ────────────────────────────────────────────────────────────

func runTimezoneAliasTests() {
    print("Running TimezoneAliasTests...")

    // City Abbreviations
    expectEqual(resolveTimezone("SF")?.identifier, "America/Los_Angeles", "SF")
    expectEqual(resolveTimezone("NYC")?.identifier, "America/New_York", "NYC")
    expectEqual(resolveTimezone("BKK")?.identifier, "Asia/Bangkok", "BKK")
    expectEqual(resolveTimezone("HK")?.identifier, "Asia/Hong_Kong", "HK")
    expectEqual(resolveTimezone("LA")?.identifier, "America/Los_Angeles", "LA")
    expectEqual(resolveTimezone("LDN")?.identifier, "Europe/London", "LDN")

    // City Names
    expectEqual(resolveTimezone("bangkok")?.identifier, "Asia/Bangkok", "bangkok")
    expectEqual(resolveTimezone("san francisco")?.identifier, "America/Los_Angeles", "san francisco")
    expectEqual(resolveTimezone("new york")?.identifier, "America/New_York", "new york")
    expectEqual(resolveTimezone("tokyo")?.identifier, "Asia/Tokyo", "tokyo")
    expectEqual(resolveTimezone("london")?.identifier, "Europe/London", "london")
    expectEqual(resolveTimezone("sydney")?.identifier, "Australia/Sydney", "sydney")
    expectEqual(resolveTimezone("dubai")?.identifier, "Asia/Dubai", "dubai")
    expectEqual(resolveTimezone("ho chi minh")?.identifier, "Asia/Ho_Chi_Minh", "ho chi minh")

    // Country Names
    expectEqual(resolveTimezone("japan")?.identifier, "Asia/Tokyo", "japan")
    expectEqual(resolveTimezone("thailand")?.identifier, "Asia/Bangkok", "thailand")
    expectEqual(resolveTimezone("germany")?.identifier, "Europe/Berlin", "germany")
    expectEqual(resolveTimezone("united kingdom")?.identifier, "Europe/London", "united kingdom")
    expectEqual(resolveTimezone("india")?.identifier, "Asia/Kolkata", "india")

    // Region Aliases
    expectEqual(resolveTimezone("Europe")?.identifier, "Europe/Paris", "Europe region")
    expectEqual(resolveTimezone("pacific")?.identifier, "America/Los_Angeles", "pacific region")

    // Timezone Abbreviations
    expectEqual(resolveTimezone("PT")?.identifier, "America/Los_Angeles", "PT")
    expectEqual(resolveTimezone("ET")?.identifier, "America/New_York", "ET")
    expectEqual(resolveTimezone("JST")?.identifier, "Asia/Tokyo", "JST")
    expectEqual(resolveTimezone("ICT")?.identifier, "Asia/Bangkok", "ICT")
    expectEqual(resolveTimezone("UTC")?.identifier, "GMT", "UTC")

    // Airport Codes
    expectEqual(resolveTimezone("SFO")?.identifier, "America/Los_Angeles", "SFO")
    expectEqual(resolveTimezone("JFK")?.identifier, "America/New_York", "JFK")
    expectEqual(resolveTimezone("LHR")?.identifier, "Europe/London", "LHR")
    expectEqual(resolveTimezone("NRT")?.identifier, "Asia/Tokyo", "NRT")
    expectEqual(resolveTimezone("SIN")?.identifier, "Asia/Singapore", "SIN")
    expectEqual(resolveTimezone("DXB")?.identifier, "Asia/Dubai", "DXB")

    // Case Insensitivity
    expectEqual(resolveTimezone("sf")?.identifier, "America/Los_Angeles", "sf lowercase")
    expectEqual(resolveTimezone("Bangkok")?.identifier, "Asia/Bangkok", "Bangkok mixed case")
    expectEqual(resolveTimezone("TOKYO")?.identifier, "Asia/Tokyo", "TOKYO uppercase")

    // Whitespace
    expectEqual(resolveTimezone("  SF  ")?.identifier, "America/Los_Angeles", "whitespace SF")

    // IANA Fallback
    expectEqual(resolveTimezone("America/Los_Angeles")?.identifier, "America/Los_Angeles", "IANA LA")
    expectEqual(resolveTimezone("Asia/Tokyo")?.identifier, "Asia/Tokyo", "IANA Tokyo")

    // Unknown
    expectNil(resolveTimezone("xyzzyplugh"), "unknown returns nil")
    expectNil(resolveTimezone(""), "empty returns nil")
}
