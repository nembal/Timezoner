import Foundation
import TimeZonerLib

// ── Helpers ──────────────────────────────────────────────────────────

private func expectTimeConversion(
    _ result: ParseResult?,
    hour expectedHour: Int,
    minute expectedMinute: Int,
    zoneId expectedZoneId: String,
    _ label: String,
    line: Int = #line
) {
    guard let result = result else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected timeConversion, got nil")
        return
    }
    if case .timeConversion(let h, let m, let tz) = result {
        if h == expectedHour && m == expectedMinute && tz.identifier == expectedZoneId {
            testsPassed += 1
        } else {
            testsFailed += 1
            print("  FAIL [line \(line)] \(label): expected timeConversion(hour:\(expectedHour), minute:\(expectedMinute), zone:\(expectedZoneId)), got timeConversion(hour:\(h), minute:\(m), zone:\(tz.identifier))")
        }
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected timeConversion, got different case")
    }
}

private func expectAddZone(
    _ result: ParseResult?,
    label expectedLabel: String,
    zoneId expectedZoneId: String,
    _ description: String,
    line: Int = #line
) {
    guard let result = result else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(description): expected addZone, got nil")
        return
    }
    if case .addZone(let lbl, let tz) = result {
        if lbl == expectedLabel && tz.identifier == expectedZoneId {
            testsPassed += 1
        } else {
            testsFailed += 1
            print("  FAIL [line \(line)] \(description): expected addZone(label:\(expectedLabel), zone:\(expectedZoneId)), got addZone(label:\(lbl), zone:\(tz.identifier))")
        }
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(description): expected addZone, got different case")
    }
}

private func expectRemoveZone(
    _ result: ParseResult?,
    label expectedLabel: String,
    _ description: String,
    line: Int = #line
) {
    guard let result = result else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(description): expected removeZone, got nil")
        return
    }
    if case .removeZone(let lbl) = result {
        if lbl == expectedLabel {
            testsPassed += 1
        } else {
            testsFailed += 1
            print("  FAIL [line \(line)] \(description): expected removeZone(label:\(expectedLabel)), got removeZone(label:\(lbl))")
        }
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(description): expected removeZone, got different case")
    }
}

private func expectNilResult(_ result: ParseResult?, _ description: String, line: Int = #line) {
    if result == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(description): expected nil, got a result")
    }
}

// ── Tests ────────────────────────────────────────────────────────────

func runInputParserTests() {
    print("Running InputParserTests...")

    // ── Time conversion: colon + am/pm stuck ─────────────────────
    expectTimeConversion(
        InputParser.parse("11:30am PT"),
        hour: 11, minute: 30, zoneId: "America/Los_Angeles",
        "11:30am PT"
    )

    // ── Time conversion: colon + space before am/pm ──────────────
    expectTimeConversion(
        InputParser.parse("11:30 am PT"),
        hour: 11, minute: 30, zoneId: "America/Los_Angeles",
        "11:30 am PT"
    )

    // ── Time conversion: no colon + am/pm stuck ──────────────────
    expectTimeConversion(
        InputParser.parse("1130am PT"),
        hour: 11, minute: 30, zoneId: "America/Los_Angeles",
        "1130am PT"
    )

    // ── Time conversion: no colon + space before am/pm ───────────
    expectTimeConversion(
        InputParser.parse("1130 am PT"),
        hour: 11, minute: 30, zoneId: "America/Los_Angeles",
        "1130 am PT"
    )

    // ── Time conversion: short am indicator ──────────────────────
    expectTimeConversion(
        InputParser.parse("1130 a BKK"),
        hour: 11, minute: 30, zoneId: "Asia/Bangkok",
        "1130 a BKK"
    )

    // ── Time conversion: short pm indicator, single digit hour ───
    expectTimeConversion(
        InputParser.parse("3 p SF"),
        hour: 15, minute: 0, zoneId: "America/Los_Angeles",
        "3 p SF"
    )

    // ── Time conversion: dotted am ───────────────────────────────
    expectTimeConversion(
        InputParser.parse("11:30 a.m. NYC"),
        hour: 11, minute: 30, zoneId: "America/New_York",
        "11:30 a.m. NYC"
    )

    // ── Time conversion: single digit hour + pm ──────────────────
    expectTimeConversion(
        InputParser.parse("3pm bangkok"),
        hour: 15, minute: 0, zoneId: "Asia/Bangkok",
        "3pm bangkok"
    )

    // ── Time conversion: 24-hour format ──────────────────────────
    expectTimeConversion(
        InputParser.parse("15:00 BKK"),
        hour: 15, minute: 0, zoneId: "Asia/Bangkok",
        "15:00 BKK"
    )

    // ── Special words ────────────────────────────────────────────
    expectTimeConversion(
        InputParser.parse("noon NYC"),
        hour: 12, minute: 0, zoneId: "America/New_York",
        "noon NYC"
    )

    expectTimeConversion(
        InputParser.parse("midnight CET"),
        hour: 0, minute: 0, zoneId: "Europe/Paris",
        "midnight CET"
    )

    // ── Add zone commands ────────────────────────────────────────
    expectAddZone(
        InputParser.parse("+Tokyo"),
        label: "Tokyo", zoneId: "Asia/Tokyo",
        "+Tokyo"
    )

    expectAddZone(
        InputParser.parse("add HK"),
        label: "HK", zoneId: "Asia/Hong_Kong",
        "add HK"
    )

    // ── Remove zone commands ─────────────────────────────────────
    expectRemoveZone(
        InputParser.parse("-SF"),
        label: "SF",
        "-SF"
    )

    expectRemoveZone(
        InputParser.parse("remove NYC"),
        label: "NYC",
        "remove NYC"
    )

    // ── Nil cases ────────────────────────────────────────────────
    expectNilResult(InputParser.parse(""), "empty string")
    expectNilResult(InputParser.parse("hello world"), "no time pattern")
}
