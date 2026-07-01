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
}
