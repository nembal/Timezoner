import Foundation
import TimeZonerLib

private final class TimeZonerLaunchLifetimeProbe {}

func runTimeZonerLaunchTests() {
    print("Running TimeZonerLaunchTests...")

    weak var retainedDelegate: TimeZonerLaunchLifetimeProbe?
    func makeDelegate() -> TimeZonerLaunchLifetimeProbe {
        let delegate = TimeZonerLaunchLifetimeProbe()
        retainedDelegate = delegate
        return delegate
    }
    TimeZonerApplicationLifetime(retaining: makeDelegate()).run {
        if retainedDelegate != nil {
            testsPassed += 1
        } else {
            testsFailed += 1
            print("  FAIL: the application delegate must survive for the whole run loop")
        }
    }
    if retainedDelegate == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL: the delegate owner must release after the run loop returns")
    }

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

    let oldestCurrent = TimeZonerRunningInstance(processID: 200, launchDate: Date(timeIntervalSince1970: 50))
    if TimeZonerLaunchCoordinator.incumbent(
        currentProcessID: 200,
        candidates: [newerProcess, oldestCurrent, olderProcess]
    ) == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL: the oldest process must continue rather than forward to a newer launch")
    }

    let sameMomentHigherPID = TimeZonerRunningInstance(processID: 600, launchDate: ownProcess.launchDate)
    if TimeZonerLaunchCoordinator.incumbent(
        currentProcessID: 400,
        candidates: [sameMomentHigherPID, ownProcess]
    ) == nil {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL: equal launch dates must retain the lower PID")
    }
    let sameMomentLowerPID = TimeZonerRunningInstance(processID: 200, launchDate: ownProcess.launchDate)
    if TimeZonerLaunchCoordinator.incumbent(
        currentProcessID: 400,
        candidates: [ownProcess, sameMomentLowerPID]
    )?.processID == 200 {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL: equal launch dates must select the lower PID as incumbent")
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
