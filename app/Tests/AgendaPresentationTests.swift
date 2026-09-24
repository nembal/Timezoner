import Foundation
import TimeZonerLib

private func expectAgendaPresentation(_ condition: Bool, _ label: String, line: Int = #line) {
    if condition {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label)")
    }
}

func runAgendaPresentationTests() {
    print("Running AgendaPresentationTests...")

    expectAgendaPresentation(
        AgendaContentState.resolve(events: [], isLoading: false, errorMessage: "Calendar fetch failed")
            == .errorWithoutEvents("Calendar fetch failed"),
        "an empty failed fetch has an error state rather than a clear-day state"
    )
    expectAgendaPresentation(
        AgendaContentState.resolve(events: [], isLoading: true, errorMessage: nil) == .loading,
        "an empty in-flight fetch remains loading"
    )
    expectAgendaPresentation(
        AgendaContentState.resolve(events: [], isLoading: false, errorMessage: nil) == .agenda,
        "an empty successful fetch can show the clear-day state"
    )
}
