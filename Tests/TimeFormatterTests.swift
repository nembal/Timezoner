import Foundation
import TimeZonerLib

// -- Helpers ------------------------------------------------------------------

private func expectEqual(_ actual: String, _ expected: String, _ label: String, line: Int = #line) {
    if actual == expected {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \"\(expected)\", got \"\(actual)\"")
    }
}

// -- Tests --------------------------------------------------------------------

func runTimeFormatterTests() {
    print("Running TimeFormatterTests...")

    let bangkok = TimeZone(identifier: "Asia/Bangkok")!        // UTC+7
    let sf      = TimeZone(identifier: "America/Los_Angeles")! // UTC-7 (PDT in July)
    let india   = TimeZone(identifier: "Asia/Kolkata")!        // UTC+5:30

    // Fixed date: July 1, 2025 at 11:30 AM in Bangkok = UTC 04:30
    var cal = Calendar(identifier: .gregorian)
    cal.timeZone = bangkok
    var comps = DateComponents()
    comps.year = 2025
    comps.month = 7
    comps.day = 1
    comps.hour = 11
    comps.minute = 30
    let fixedDate = cal.date(from: comps)!

    // -- formatTime -----------------------------------------------------------

    // Bangkok should be 11:30 AM
    expectEqual(
        TimeFormatter.formatTime(fixedDate, in: bangkok),
        "11:30 AM",
        "formatTime Bangkok 11:30 AM"
    )

    // SF (PDT, UTC-7): UTC 04:30 - 7 = 21:30 previous day = 9:30 PM
    expectEqual(
        TimeFormatter.formatTime(fixedDate, in: sf),
        "9:30 PM",
        "formatTime SF 9:30 PM"
    )

    // -- formatTimeEditable ---------------------------------------------------

    // Bangkok 11:30 in 24h format
    expectEqual(
        TimeFormatter.formatTimeEditable(fixedDate, in: bangkok),
        "11:30",
        "formatTimeEditable Bangkok 11:30"
    )

    // SF 21:30 in 24h format
    expectEqual(
        TimeFormatter.formatTimeEditable(fixedDate, in: sf),
        "21:30",
        "formatTimeEditable SF 21:30"
    )

    // -- formatDate -----------------------------------------------------------

    // In Bangkok timezone, this is Tue, Jul 1
    expectEqual(
        TimeFormatter.formatDate(fixedDate, in: bangkok),
        "Tue, Jul 1",
        "formatDate Bangkok Tue, Jul 1"
    )

    // In SF timezone (UTC-7), 04:30 UTC = Jun 30 21:30 PDT => Mon, Jun 30
    expectEqual(
        TimeFormatter.formatDate(fixedDate, in: sf),
        "Mon, Jun 30",
        "formatDate SF Mon, Jun 30"
    )

    // -- relativeOffset -------------------------------------------------------

    // Bangkok (UTC+7) to SF (PDT, UTC-7): difference is -14h
    expectEqual(
        TimeFormatter.relativeOffset(from: bangkok, to: sf, at: fixedDate),
        "-14h",
        "relativeOffset Bangkok -> SF = -14h"
    )

    // Same zone -> +0h
    expectEqual(
        TimeFormatter.relativeOffset(from: bangkok, to: bangkok, at: fixedDate),
        "+0h",
        "relativeOffset same zone = +0h"
    )

    // Bangkok (UTC+7) to India (UTC+5:30): difference is -1.5h
    expectEqual(
        TimeFormatter.relativeOffset(from: bangkok, to: india, at: fixedDate),
        "-1.5h",
        "relativeOffset Bangkok -> India = -1.5h"
    )

    // India (UTC+5:30) to Bangkok (UTC+7): difference is +1.5h
    expectEqual(
        TimeFormatter.relativeOffset(from: india, to: bangkok, at: fixedDate),
        "+1.5h",
        "relativeOffset India -> Bangkok = +1.5h"
    )

    // UTC to India: +5.5h
    let utc = TimeZone(identifier: "UTC")!
    expectEqual(
        TimeFormatter.relativeOffset(from: utc, to: india, at: fixedDate),
        "+5.5h",
        "relativeOffset UTC -> India = +5.5h"
    )
}
