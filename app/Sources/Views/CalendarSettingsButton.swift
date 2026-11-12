import SwiftUI

/// The single settings anchor for one member of the floating-panel pair.
/// Its binding ignores lifecycle callbacks from the inactive panel so they cannot dismiss
/// the owner panel's popover.
public struct CalendarSettingsButton<Content: View>: View {
    let owner: CalendarPanelIdentity
    let presentation: CalendarPresentationState
    let onActivate: () -> Void
    let onOwnedPopoverChanged: (Bool) -> Void
    let content: Content

    public init(
        owner: CalendarPanelIdentity,
        presentation: CalendarPresentationState,
        onActivate: @escaping () -> Void,
        onOwnedPopoverChanged: @escaping (Bool) -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.owner = owner
        self.presentation = presentation
        self.onActivate = onActivate
        self.onOwnedPopoverChanged = onOwnedPopoverChanged
        self.content = content()
    }

    public var body: some View {
        CalendarToolbarIcon(systemName: "gearshape", label: "Settings (⌘,)", hint: "Opens TimeZoner settings.", action: onActivate)
        .popover(isPresented: Binding(
            get: { CalendarSettingsOwnership.isPresented(owner: owner, presentation: presentation) },
            set: { CalendarSettingsOwnership.setPresented(
                $0,
                owner: owner,
                presentation: presentation,
                onOwnedPopoverChanged: onOwnedPopoverChanged
            ) }
        ), arrowEdge: .bottom) {
            content
        }
    }
}
