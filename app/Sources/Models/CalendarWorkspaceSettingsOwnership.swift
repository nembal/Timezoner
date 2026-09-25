import Foundation

/// Ensures the shared settings popover has one anchor at a time while preserving panel-pair
/// popover protection for the panel that owns the active destination.
@MainActor
public enum CalendarSettingsOwnership {
    public static func isPresented(
        owner: CalendarPanelIdentity,
        presentation: CalendarPresentationState
    ) -> Bool {
        CalendarWorkspacePolicy.settingsOwner(destination: presentation.destination) == owner
            && presentation.isSettingsPresented
    }

    public static func setPresented(
        _ value: Bool,
        owner: CalendarPanelIdentity,
        presentation: CalendarPresentationState,
        onOwnedPopoverChanged: (Bool) -> Void
    ) {
        guard CalendarWorkspacePolicy.settingsOwner(destination: presentation.destination) == owner else {
            return
        }
        presentation.isSettingsPresented = value
        onOwnedPopoverChanged(presentation.hasOwnedPopover)
    }
}
