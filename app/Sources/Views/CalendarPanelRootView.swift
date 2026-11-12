import SwiftUI

/// Keeps both agenda and full-calendar roots constructed while presentation state selects the
/// visible companion surface.
public struct CalendarPanelRootView: View {
    public let presentation: CalendarPresentationState
    public let agenda: AgendaView
    public let calendar: CalendarModeView
    public let onToggleSettings: () -> Void
    public let onFocusCalendar: () -> Void

    public init(
        presentation: CalendarPresentationState,
        agenda: AgendaView,
        calendar: CalendarModeView,
        onToggleSettings: @escaping () -> Void,
        onFocusCalendar: @escaping () -> Void
    ) {
        self.presentation = presentation
        self.agenda = agenda
        self.calendar = calendar
        self.onToggleSettings = onToggleSettings
        self.onFocusCalendar = onFocusCalendar
    }

    public var body: some View {
        Group {
            if presentation.destination == .calendar {
                calendar
            } else {
                agenda
            }
        }
        .background {
            Button("") { onToggleSettings() }
                .keyboardShortcut(",", modifiers: .command)
                .hidden()
        }
        .background {
            Button("") { onFocusCalendar() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
                .hidden()
        }
    }
}
