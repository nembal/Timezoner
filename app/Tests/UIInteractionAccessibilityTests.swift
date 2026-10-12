import AppKit
import Foundation
import TimeZonerLib

private actor ControlledHighlightSleeper {
    private var pending: [CheckedContinuation<Void, Never>] = []
    private var waiters: [(Int, CheckedContinuation<Void, Never>)] = []

    func sleep() async {
        await withCheckedContinuation { continuation in
            pending.append(continuation)
            let ready = waiters.filter { pending.count >= $0.0 }
            waiters.removeAll { pending.count >= $0.0 }
            ready.forEach { $0.1.resume() }
        }
    }

    func waitForPending(_ count: Int) async {
        guard pending.count < count else { return }
        await withCheckedContinuation { waiters.append((count, $0)) }
    }

    func releaseFirst() {
        pending.removeFirst().resume()
    }
}

@MainActor
func runUIInteractionAccessibilityTests() async {
    print("Running UIInteractionAccessibilityTests...")

    var measurement = ZoneCardDragMeasurement()
    measurement.update(CGSize(width: 180, height: 120))
    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 0, translation: 80,
                                     slotExtent: measurement.slotExtent(for: .vertical), count: 3) == 2,
        "a measured 120-point card permits a drag beyond its half-slot threshold"
    )
    measurement.update(CGSize(width: 180, height: 180))
    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 0, translation: 80,
                                     slotExtent: measurement.slotExtent(for: .vertical), count: 3) == nil,
        "the current measured card height determines the vertical drag threshold"
    )

    let first = UUID()
    let second = UUID()
    let sleeper = ControlledHighlightSleeper()
    let highlights = ZoneHighlightCoordinator(sleep: { _ in await sleeper.sleep() })
    let oldClear = highlights.show([first])
    await sleeper.waitForPending(1)
    let newestClear = highlights.show([second])
    await sleeper.waitForPending(2)
    await sleeper.releaseFirst()
    await oldClear.value
    workspaceExpect(highlights.ids == [second], "an older clear cannot erase the newer highlighted zone")
    await sleeper.releaseFirst()
    await newestClear.value
    workspaceExpect(highlights.ids.isEmpty, "the newest highlight clears after its own delay")

    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let day = calendar.date(from: DateComponents(year: 2024, month: 5, day: 15))!
    let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
    let interval = DateInterval(start: day, end: calendar.date(byAdding: .day, value: 3, to: day)!)
    func event(on date: Date) -> CalendarEventSnapshot {
        CalendarEventSnapshot(id: UUID().uuidString, calendarID: "work", calendarTitle: "Work",
                              title: "Standup", startDate: calendar.date(byAdding: .hour, value: 9, to: date)!,
                              endDate: calendar.date(byAdding: .hour, value: 10, to: date)!,
                              isAllDay: false, attendeeNames: [], availability: .busy,
                              participationStatus: .accepted)
    }
    let firstSegment = CalendarLayoutEngine.timedSegments(events: [event(on: day)], interval: interval, calendar: calendar).first
    let secondSegment = CalendarLayoutEngine.timedSegments(events: [event(on: nextDay)], interval: interval, calendar: calendar).first
    let firstLabel = firstSegment.map { CalendarGridAccessibility.timedSegmentLabel($0, calendar: calendar) } ?? ""
    let secondLabel = secondSegment.map { CalendarGridAccessibility.timedSegmentLabel($0, calendar: calendar) } ?? ""
    workspaceExpect(firstLabel.contains("May 15") && secondLabel.contains("May 16") && firstLabel != secondLabel,
                    "same-titled calendar events on different dates have distinguishable labels")
    let allDayEvent = CalendarEventSnapshot(
        id: "all-day", calendarID: "work", calendarTitle: "Work", title: "Holiday",
        startDate: day, endDate: nextDay, isAllDay: true, attendeeNames: [],
        availability: .busy, participationStatus: .accepted
    )
    let allDaySpan = CalendarLayoutEngine.allDaySpans(events: [allDayEvent], interval: interval, calendar: calendar).first
    workspaceExpect(allDaySpan.map { CalendarGridAccessibility.allDaySpanLabel($0, calendar: calendar).contains("May 15") } == true,
                    "all-day event labels include their calendar date")

    let overnightEvent = CalendarEventSnapshot(
        id: "overnight", calendarID: "work", calendarTitle: "Work", title: "On call",
        startDate: calendar.date(byAdding: .hour, value: 23, to: day)!,
        endDate: calendar.date(byAdding: .hour, value: 25, to: day)!, isAllDay: false,
        attendeeNames: [], availability: .busy, participationStatus: .accepted
    )
    let overnightSegments = CalendarLayoutEngine.timedSegments(events: [overnightEvent], interval: interval, calendar: calendar)
    workspaceExpect(overnightSegments.count == 2, "the overnight event renders in two day columns")
    if overnightSegments.count == 2 {
        let earlier = CalendarGridAccessibility.timedSegmentLabel(overnightSegments[0], calendar: calendar)
        let later = CalendarGridAccessibility.timedSegmentLabel(overnightSegments[1], calendar: calendar)
        workspaceExpect(earlier.contains("May 15") && later.contains("May 16") && earlier != later,
                        "each overnight segment announces its own visible date")
        workspaceExpect(earlier.contains("May 15 to Thu, May 16") && later.contains("May 15 to Thu, May 16"),
                        "both overnight segments announce the event's full end-date range")
        let menuTitle = CalendarGridAccessibility.timedSegmentMenuTitle(overnightSegments[1], calendar: calendar)
        workspaceExpect(menuTitle.contains("May 16") && menuTitle.contains("May 15 to Thu, May 16"),
                        "the native overlap menu title retains the visible date and full event range")
    }

    let multiDayEvent = CalendarEventSnapshot(
        id: "retreat", calendarID: "work", calendarTitle: "Work", title: "Retreat",
        startDate: day, endDate: calendar.date(byAdding: .day, value: 3, to: day)!,
        isAllDay: true, attendeeNames: [], availability: .busy, participationStatus: .accepted
    )
    let multiDaySpans = CalendarLayoutEngine.allDaySpans(events: [multiDayEvent], interval: interval, calendar: calendar)
    workspaceExpect(multiDaySpans.count == 1, "the three-day event renders as one all-day span")
    if let span = multiDaySpans.first {
        let label = CalendarGridAccessibility.allDaySpanLabel(span, calendar: calendar)
        workspaceExpect(label.contains("May 15 to Fri, May 17") && !label.contains("May 18"),
                        "all-day span announces the visible inclusive end date")
    }

    workspaceExpect(TimezoneMapAccessibility.toggleValue(isExpanded: true) == "Expanded" &&
                    TimezoneMapAccessibility.toggleValue(isExpanded: false) == "Collapsed",
                    "the map toggle announces its expansion state")
    workspaceExpect(AppearanceAccessibility.value(for: .dark) == "Dark",
                    "the appearance picker announces the selected option")

    let recorder = HotkeyRecorderField.RecorderView(frame: .zero)
    recorder.render(nil)
    workspaceExpect(recorder.accessibilityLabel() == "Global hotkey" &&
                    recorder.accessibilityValue() as? String == "Not set" &&
                    recorder.accessibilityHelp()?.contains("record") == true,
                    "the shortcut recorder announces its purpose, empty state, and action")
    recorder.render(SettingsStore.defaultHotkey)
    workspaceExpect(recorder.accessibilityValue() as? String == SettingsStore.defaultHotkey.display,
                    "the shortcut recorder announces the recorded shortcut")
}
