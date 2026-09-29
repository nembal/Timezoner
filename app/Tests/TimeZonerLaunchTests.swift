import Foundation
import TimeZonerLib

func runTimeZonerLaunchTests() {
    print("Running TimeZonerLaunchTests...")

    let ownProcess = TimeZonerRunningInstance(processID: 400, launchDate: Date(timeIntervalSince1970: 200))
    let olderProcess = TimeZonerRunningInstance(processID: 300, launchDate: Date(timeIntervalSince1970: 100))
    let newerProcess = TimeZonerRunningInstance(processID: 500, launchDate: Date(timeIntervalSince1970: 300))
    let incumbent = TimeZonerLaunchCoordinator.incumbent(
        currentProcessID: 400,
        candidates: [ownProcess, newerProcess, olderProcess]
    )
    if incumbent?.processID == 300 {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL: duplicate launch must choose the oldest other TimeZoner process")
    }
    if TimeZonerLaunchCoordinator.incumbent(currentProcessID: 400, candidates: [ownProcess]) == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL: the current process must not count as a duplicate")
    }

    var actions: [String] = []
    let router = TimeZonerDuplicateLaunchRouter(
        activateIncumbent: { actions.append("activate") },
        forwardURL: { actions.append($0.absoluteString) }
    )
    router.didLaunch()
    router.open(urls: [
        URL(string: "timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF")!,
        URL(string: "https://example.com/irrelevant")!,
        URL(string: "timezoner://open")!
    ])
    if actions == [
        "activate",
        "timezoner://set?hour=15&minute=30&zone=America%2FLos_Angeles&label=SF",
        "timezoner://open"
    ] {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL: duplicate launch must activate incumbent and forward valid deep links, got \(actions)")
    }
}
