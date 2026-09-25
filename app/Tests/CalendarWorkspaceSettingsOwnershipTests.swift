import Foundation
import TimeZonerLib

@MainActor
func runCalendarWorkspaceSettingsOwnershipTests() {
    print("Running CalendarWorkspaceSettingsOwnershipTests...")

    let suiteName = "CalendarWorkspaceSettingsOwnershipTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defaults.removePersistentDomain(forName: suiteName)
    defer { defaults.removePersistentDomain(forName: suiteName) }

    let settings = SettingsStore(userDefaults: defaults)
    let presentation = CalendarPresentationState(
        settings: settings,
        defaults: defaults,
        mapExpandedKey: "CalendarWorkspaceSettingsOwnershipTests.mapExpanded"
    )
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = TimeZone(secondsFromGMT: 0)!
    presentation.enterCalendar(now: Date(timeIntervalSinceReferenceDate: 0), calendar: calendar)

    workspaceExpect(presentation.focusedPanel == nil, "panel focus remains unset until native lifecycle establishes it")

    var owned = false
    CalendarSettingsOwnership.setPresented(true, owner: .calendar,
        presentation: presentation, onOwnedPopoverChanged: { owned = $0 })
    workspaceExpect(owned && CalendarSettingsOwnership.isPresented(owner: .calendar, presentation: presentation),
                    "calendar settings retains the pair")
    workspaceExpect(!CalendarSettingsOwnership.isPresented(owner: .timezoner, presentation: presentation),
                    "only one settings anchor can present")
    CalendarSettingsOwnership.setPresented(false, owner: .timezoner,
        presentation: presentation, onOwnedPopoverChanged: { owned = $0 })
    workspaceExpect(presentation.isSettingsPresented && owned,
                    "stale inactive anchor cannot close the active settings popover")
    CalendarSettingsOwnership.setPresented(false, owner: .calendar,
        presentation: presentation, onOwnedPopoverChanged: { owned = $0 })
    workspaceExpect(!presentation.isSettingsPresented && !owned, "active owner releases popover protection")
}
