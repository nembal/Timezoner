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
        "11:30 am",
        "formatTime Bangkok 11:30 am"
    )

    // SF (PDT, UTC-7): UTC 04:30 - 7 = 21:30 previous day = 9:30 PM
    expectEqual(
        TimeFormatter.formatTime(fixedDate, in: sf),
        "9:30 pm",
        "formatTime SF 9:30 pm"
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

    // Quarter-hour zones must retain their actual offset, including DST in Chatham.
    let kathmandu = TimeZone(identifier: "Asia/Kathmandu")!
    let eucla = TimeZone(identifier: "Australia/Eucla")!
    let chatham = TimeZone(identifier: "Pacific/Chatham")!
    let winterDate = Date(timeIntervalSince1970: 1_767_268_800) // 2026-01-01 UTC
    expectEqual(TimeFormatter.gmtOffset(for: kathmandu, at: fixedDate), "GMT+5:45", "Kathmandu GMT offset retains 45 minutes")
    expectEqual(TimeFormatter.gmtOffset(for: eucla, at: fixedDate), "GMT+8:45", "Eucla GMT offset retains 45 minutes")
    expectEqual(TimeFormatter.gmtOffset(for: chatham, at: fixedDate), "GMT+12:45", "Chatham standard GMT offset retains 45 minutes")
    expectEqual(TimeFormatter.gmtOffset(for: chatham, at: winterDate), "GMT+13:45", "Chatham daylight GMT offset retains 45 minutes")
    expectEqual(TimeFormatter.relativeOffset(from: utc, to: kathmandu, at: fixedDate), "+5.75h", "UTC to Kathmandu retains quarter hour")
    expectEqual(TimeFormatter.relativeOffset(from: eucla, to: utc, at: fixedDate), "-8.75h", "Eucla to UTC retains quarter hour")
    expectEqual(TimeFormatter.relativeOffset(from: utc, to: chatham, at: fixedDate), "+12.75h", "UTC to Chatham standard retains quarter hour")
    expectEqual(TimeFormatter.relativeOffset(from: utc, to: chatham, at: winterDate), "+13.75h", "UTC to Chatham daylight retains quarter hour")

    let twentyMinutes = TimeZone(secondsFromGMT: 20 * 60)!
    expectEqual(TimeFormatter.gmtOffset(for: twentyMinutes, at: fixedDate), "GMT+0:20", "GMT offset retains non-quarter minute values")
    expectEqual(TimeFormatter.relativeOffset(from: utc, to: twentyMinutes, at: fixedDate), "+0h20m", "relative offset retains non-quarter minute values")
}
