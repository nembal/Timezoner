import SwiftUI

/// Keeps both agenda and full-calendar roots constructed while presentation state selects the
/// visible companion surface.
public struct CalendarPanelRootView: View {
    public let presentation: CalendarPresentationState
    public let agenda: AgendaView
    public let calendar: CalendarModeView

    public init(
        presentation: CalendarPresentationState,
        agenda: AgendaView,
        calendar: CalendarModeView
    ) {
        self.presentation = presentation
        self.agenda = agenda
        self.calendar = calendar
    }

    public var body: some View {
        Group {
            if presentation.destination == .calendar {
                calendar
            } else {
                agenda
            }
        }
    }
}
