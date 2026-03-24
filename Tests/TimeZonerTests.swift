import Foundation

@main
struct TestRunner {
    static func main() {
        runTimezoneAliasTests()
        runTimeStateTests()

        print("\nResults: \(testsPassed) passed, \(testsFailed) failed out of \(testsPassed + testsFailed) tests")
        if testsFailed > 0 {
            exit(1)
        } else {
            print("All tests passed!")
        }
    }
}
