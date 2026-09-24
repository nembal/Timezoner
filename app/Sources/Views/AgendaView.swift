import SwiftUI

public struct AgendaView: View {
    public let calendarStore: CalendarStore
    public let referenceMoment: ReferenceMomentController
    public let presentation: CalendarPresentationState
    public let onRequestAccess: () -> Void
    public let onOpenPrivacySettings: () -> Void
    public let onOpenWeek: () -> Void
    public let onOwnedPopoverChanged: (Bool) -> Void
    public let onEscape: () -> Void

    @State private var showEarlier = false

    public init(
        calendarStore: CalendarStore,
        referenceMoment: ReferenceMomentController,
        presentation: CalendarPresentationState,
        onRequestAccess: @escaping () -> Void,
        onOpenPrivacySettings: @escaping () -> Void,
        onOpenWeek: @escaping () -> Void,
        onOwnedPopoverChanged: @escaping (Bool) -> Void,
        onEscape: @escaping () -> Void
    ) {
        self.calendarStore = calendarStore
        self.referenceMoment = referenceMoment
        self.presentation = presentation
        self.onRequestAccess = onRequestAccess
        self.onOpenPrivacySettings = onOpenPrivacySettings
        self.onOpenWeek = onOpenWeek
        self.onOwnedPopoverChanged = onOwnedPopoverChanged
        self.onEscape = onEscape
    }

    public var body: some View {
        VStack(spacing: 0) {
            DragHandle(showPill: false, isHugging: presentation.agendaPanelHugsMenuBar)

            VStack(alignment: .leading, spacing: 12) {
                header
                Divider()
                content
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 14)
            .padding(.top, 4)
        }
        .frame(width: AgendaPlacementCalculator.wingWidth)
        .frame(minHeight: 260, maxHeight: .infinity, alignment: .top)
        .background(Theme.background)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: presentation.agendaPanelHugsMenuBar ? 0 : 12,
            bottomLeadingRadius: 12,
            bottomTrailingRadius: 12,
            topTrailingRadius: presentation.agendaPanelHugsMenuBar ? 0 : 12,
            style: .continuous
        ))
        .onChange(of: presentation.attendeePopoverEventID) {
            onOwnedPopoverChanged(presentation.hasOwnedPopover)
        }
        .onKeyPress(.escape) {
            onEscape()
            return .handled
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Agenda")
                    .font(.system(size: 14, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                Text(dayFormatter.string(from: calendarStore.currentDate))
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Spacer()
            Button("Open week", action: onOpenWeek)
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.accent)
        }
    }

    @ViewBuilder
    private var content: some View {
        switch calendarStore.authorizationStatus {
        case .fullAccess:
            agendaContent
        case .notDetermined, .denied, .restricted, .writeOnly:
            CalendarAccessView(
                status: calendarStore.authorizationStatus,
                onEnable: onRequestAccess,
                onOpenPrivacySettings: onOpenPrivacySettings
            )
        }
    }

    private var agendaContent: some View {
        let events = calendarStore.events(on: calendarStore.currentDate)
        let allDayEvents = events.filter(\.isAllDay)
        let earlierEvents = events.filter { !$0.isAllDay && $0.endDate <= calendarStore.currentDate }
        let remainingEvents = events.filter { !$0.isAllDay && $0.endDate > calendarStore.currentDate }
        let contentState = AgendaContentState.resolve(
            events: events,
            isLoading: calendarStore.isLoading,
            errorMessage: calendarStore.errorMessage
        )

        return VStack(alignment: .leading, spacing: 10) {
            switch contentState {
            case .loading:
                HStack(spacing: 8) {
                    ProgressView().controlSize(.small)
                    Text("Loading calendar…")
                        .font(.system(size: 12, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 12)
            case .errorWithoutEvents(let error):
                failedEmptyState(error)
            case .agenda:
                ForEach(allDayEvents) { event in
                    eventRow(event, selectable: false)
                }

                if !earlierEvents.isEmpty {
                    DisclosureGroup("Earlier today", isExpanded: $showEarlier) {
                        VStack(spacing: 7) {
                            ForEach(earlierEvents) { event in
                                eventRow(event, selectable: true)
                            }
                        }
                        .padding(.top, 7)
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                }

                ForEach(remainingEvents) { event in
                    eventRow(event, selectable: true)
                }

                if allDayEvents.isEmpty && remainingEvents.isEmpty {
                    emptyState
                }
            }

            if calendarStore.isStale && !events.isEmpty {
                Label("Showing the last available calendar snapshot.", systemImage: "arrow.clockwise")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            if case .agenda = contentState, let error = calendarStore.errorMessage {
                Text(error)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func failedEmptyState(_ error: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Calendar unavailable")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
            Text(error)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(.red)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    @ViewBuilder
    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Clear for the rest of today")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            if let tomorrow = nextVisibleEventTomorrow {
                Text("Tomorrow · \(timeFormatter.string(from: tomorrow.startDate)) · \(tomorrow.title)")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
    }

    private func eventRow(_ event: CalendarEventSnapshot, selectable: Bool) -> some View {
        let selected = referenceMoment.selectedEvent?.id == event.id
        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline, spacing: 7) {
                Text(event.isAllDay ? "All-day" : timeFormatter.string(from: event.startDate))
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .frame(width: 46, alignment: .leading)
                Text(event.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }

            HStack(spacing: 5) {
                Text(event.calendarTitle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)

                if !event.attendeeNames.isEmpty {
                    Text("·")
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                    Button(attendeeSummary(for: event)) {
                        presentation.attendeePopoverEventID = event.id
                    }
                    .buttonStyle(.borderless)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
                    .popover(isPresented: attendeePopoverBinding(for: event), arrowEdge: .bottom) {
                        attendeePopover(for: event)
                    }
                }
                Spacer(minLength: 0)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(selected ? Theme.accent.opacity(0.12) : Theme.cardBg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .strokeBorder(selected ? Theme.accent.opacity(0.45) : Theme.border, lineWidth: 1)
        )
        .contentShape(Rectangle())
        .onTapGesture {
            guard selectable else { return }
            referenceMoment.selectEvent(event, sourceZone: .current)
        }
    }

    private func attendeePopoverBinding(for event: CalendarEventSnapshot) -> Binding<Bool> {
        Binding(
            get: { presentation.attendeePopoverEventID == event.id },
            set: { isPresented in
                presentation.attendeePopoverEventID = isPresented ? event.id : nil
                onOwnedPopoverChanged(presentation.hasOwnedPopover)
            }
        )
    }

    private func attendeePopover(for event: CalendarEventSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Attendees")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            ForEach(event.attendeeNames, id: \.self) { name in
                Text(name)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
        .padding(12)
        .frame(minWidth: 170, alignment: .leading)
    }

    private func attendeeSummary(for event: CalendarEventSnapshot) -> String {
        let names = event.attendeeNames
        let visible = names.prefix(2).joined(separator: ", ")
        let remaining = names.count - min(names.count, 2)
        return remaining > 0 ? "\(visible) + \(remaining)" : visible
    }

    private var nextVisibleEventTomorrow: CalendarEventSnapshot? {
        let calendar = Calendar.autoupdatingCurrent
        guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: calendarStore.currentDate),
              let activeInterval = calendarStore.activeInterval,
              activeInterval.contains(tomorrow) else {
            return nil
        }
        return calendarStore.events(on: tomorrow).first
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateFormat = "h:mm a"
        return formatter
    }
}
