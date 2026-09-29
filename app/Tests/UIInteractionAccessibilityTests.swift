import AppKit
import Foundation
import TimeZonerLib

@MainActor
func runUIInteractionAccessibilityTests() async {
    print("Running UIInteractionAccessibilityTests...")

    var measurement = ZoneCardDragMeasurement()
    measurement.update(CGSize(width: 180, height: 120))
    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 0, translation: 80,
                                     slotExtent: measurement.slotExtent(for: .vertical), count: 3) == 2,
        "the original compact card height permits a drag beyond its half-slot threshold"
    )
    measurement.update(CGSize(width: 180, height: 180))
    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 0, translation: 80,
                                     slotExtent: measurement.slotExtent(for: .vertical), count: 3) == nil,
        "a grown action row raises the vertical drag threshold using its current measured height"
    )

    let first = UUID()
    let second = UUID()
    let highlights = ZoneHighlightCoordinator()
    highlights.show([first], clearAfter: .milliseconds(40))
    try? await Task.sleep(for: .milliseconds(15))
    highlights.show([second], clearAfter: .milliseconds(100))
    try? await Task.sleep(for: .milliseconds(50))
    workspaceExpect(highlights.ids == [second], "an older clear cannot erase the newer highlighted zone")
    try? await Task.sleep(for: .milliseconds(80))
    workspaceExpect(highlights.ids.isEmpty, "the newest highlight clears after its own delay")

    var calendar = Calendar(identifier: .gregorian)
    calendar.locale = Locale(identifier: "en_US_POSIX")
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let day = calendar.date(from: DateComponents(year: 2024, month: 5, day: 15))!
    let nextDay = calendar.date(byAdding: .day, value: 1, to: day)!
    func event(on date: Date) -> CalendarEventSnapshot {
        CalendarEventSnapshot(id: UUID().uuidString, calendarID: "work", calendarTitle: "Work",
                              title: "Standup", startDate: calendar.date(byAdding: .hour, value: 9, to: date)!,
                              endDate: calendar.date(byAdding: .hour, value: 10, to: date)!,
                              isAllDay: false, attendeeNames: [], availability: .busy,
                              participationStatus: .accepted)
    }
    let firstLabel = CalendarGridAccessibility.eventLabel(event(on: day), calendar: calendar)
    let secondLabel = CalendarGridAccessibility.eventLabel(event(on: nextDay), calendar: calendar)
    workspaceExpect(firstLabel.contains("May 15") && secondLabel.contains("May 16") && firstLabel != secondLabel,
                    "same-titled calendar events on different dates have distinguishable labels")
    let allDayEvent = CalendarEventSnapshot(
        id: "all-day", calendarID: "work", calendarTitle: "Work", title: "Holiday",
        startDate: day, endDate: nextDay, isAllDay: true, attendeeNames: [],
        availability: .busy, participationStatus: .accepted
    )
    workspaceExpect(CalendarGridAccessibility.allDayLabel(allDayEvent, calendar: calendar).contains("May 15"),
                    "all-day event labels include their calendar date")

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
