import Foundation

@main
struct TestRunner {
    static func main() async {
        runTimezoneAliasTests()
        runTimeStateTests()
        runZoneStoreTests()
        runInputParserTests()
        runTimeZonerDeepLinkTests()
        runTimeFormatterTests()
        runTimezoneMapTests()
        runSettingsStoreTests()
        runCalendarProviderTests()
        runCalendarRangeTests()
        runCalendarLayoutTests()
        runCalendarAccessibilityTests()
        runCalendarPresentationStateTests()
        runCalendarWorkspaceContractsTests()
        runAgendaPresentationTests()
        runCalendarPanelCoordinatorTests()
        runCalendarPreferenceStoreTests()
        runReferenceMomentControllerTests()
        await runPendingCalendarCommandTests()
        await runCalendarClockTests()
        await runCalendarStoreTests()
        await runCalendarNotificationTests()

        print("\nResults: \(testsPassed) passed, \(testsFailed) failed out of \(testsPassed + testsFailed) tests")
        if testsFailed > 0 {
            exit(1)
        } else {
            print("All tests passed!")
        }
    }
}
