import SwiftUI

/// Textual metadata for a selectable agenda event. Kept value-only so the row's local-time
/// contract remains testable without rendering SwiftUI.
public struct AgendaTimedEventPresentation: Equatable, Sendable {
    public let timeRange: String
    public let calendarTitle: String
    public let metadata: String

    public init(event: CalendarEventSnapshot, timeZone: TimeZone, locale: Locale = .current) {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.timeZone = timeZone
        formatter.dateFormat = "h:mm a"

        let zoneFormatter = DateFormatter()
        zoneFormatter.locale = locale
        zoneFormatter.timeZone = timeZone
        zoneFormatter.dateFormat = "z"

        timeRange = "\(formatter.string(from: event.startDate)) – \(formatter.string(from: event.endDate)) \(zoneFormatter.string(from: event.startDate))"
        calendarTitle = event.calendarTitle
        metadata = "\(timeRange) · \(calendarTitle)"
    }
}

public enum AgendaDay: String, CaseIterable, Equatable, Sendable {
    case today
    case tomorrow

    public var title: String {
        switch self {
        case .today: "Today"
        case .tomorrow: "Tomorrow"
        }
    }

    public var emptyMessage: String {
        switch self {
        case .today: "Nothing scheduled today"
        case .tomorrow: "Nothing scheduled tomorrow"
        }
    }
}

/// Value-only agenda grouping. It deliberately derives both days from one injected Calendar and
/// snapshot, keeping range ownership in CalendarStore rather than creating another state graph.
public struct AgendaDayPresentation: Equatable, Sendable {
    public let day: AgendaDay
    public let allDayEvents: [CalendarEventSnapshot]
    public let earlierTimedEvents: [CalendarEventSnapshot]
    public let timedEvents: [CalendarEventSnapshot]

    public var isEmpty: Bool {
        allDayEvents.isEmpty && earlierTimedEvents.isEmpty && timedEvents.isEmpty
    }

    public var emptyMessage: String { day.emptyMessage }

    public static func sections(
        events: [CalendarEventSnapshot],
        now: Date,
        calendar: Calendar
    ) -> [AgendaDayPresentation] {
        AgendaDay.allCases.map { day in
            let date = day == .today
                ? now
                : calendar.date(byAdding: .day, value: 1, to: now) ?? now
            let dayEvents = eventsForDay(date, from: events, calendar: calendar)
            let allDayEvents = dayEvents.filter(\.isAllDay)
            let timed = dayEvents.filter { !$0.isAllDay }
            let earlierTimedEvents = day == .today
                ? timed.filter { $0.endDate <= now }
                : []
            let timedEvents = day == .today
                ? timed.filter { $0.endDate > now }
                : timed
            return AgendaDayPresentation(
                day: day,
                allDayEvents: allDayEvents,
                earlierTimedEvents: earlierTimedEvents,
                timedEvents: timedEvents
            )
        }
    }

    private static func eventsForDay(_ day: Date, from events: [CalendarEventSnapshot], calendar: Calendar) -> [CalendarEventSnapshot] {
        guard let interval = calendar.dateInterval(of: .day, for: day) else { return [] }
        return events
            .filter { $0.startDate < interval.end && $0.endDate > interval.start }
            .sorted { left, right in
                if left.isAllDay != right.isAllDay { return left.isAllDay }
                if left.startDate != right.startDate { return left.startDate < right.startDate }
                return left.id < right.id
            }
    }
}

public enum AgendaParticipantPresentation {
    public static func summary(for names: [String], maximumVisibleNames: Int = 2) -> String? {
        guard !names.isEmpty else { return nil }
        let visible = names.prefix(maximumVisibleNames).joined(separator: ", ")
        let remaining = names.count - min(names.count, maximumVisibleNames)
        return remaining > 0 ? "\(visible) + \(remaining)" : visible
    }
}

/// The read-only information shown by every all-day detail popover. It makes the useful
/// no-attendee case explicit and remains independent of EventKit and SwiftUI.
public struct CalendarEventDetailsPresentation: Equatable, Sendable {
    public let title: String
    public let metadata: String
    public let participantNames: [String]
    public let participantSummary: String

    public init(event: CalendarEventSnapshot, timeZone: TimeZone, locale: Locale = .current) {
        title = event.title
        metadata = event.isAllDay
            ? "All-day · \(event.calendarTitle)"
            : AgendaTimedEventPresentation(event: event, timeZone: timeZone, locale: locale).metadata
        participantNames = event.attendeeNames
        participantSummary = AgendaParticipantPresentation.summary(for: event.attendeeNames) ?? "No other participants"
    }
}

public struct CalendarEventDetailsPopover: View {
    public let event: CalendarEventSnapshot
    public let timeZone: TimeZone
    public let locale: Locale

    public init(event: CalendarEventSnapshot, timeZone: TimeZone, locale: Locale = .current) {
        self.event = event
        self.timeZone = timeZone
        self.locale = locale
    }

    private var details: CalendarEventDetailsPresentation {
        CalendarEventDetailsPresentation(event: event, timeZone: timeZone, locale: locale)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            Text(details.title)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
            Text(details.metadata)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            Text("Participants")
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .padding(.top, 3)
            if details.participantNames.isEmpty {
                Text(details.participantSummary)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            } else {
                ScrollView(.vertical) {
                    LazyVStack(alignment: .leading, spacing: 7) {
                        ForEach(details.participantNames, id: \.self) { name in
                            Text(name)
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                    }
                }
                .frame(maxHeight: 220)
                .accessibilityLabel("Participant list")
            }
        }
        .padding(12)
        .frame(minWidth: 190, alignment: .leading)
    }
}

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
                ScrollView(.vertical) {
                    content
                }
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
        .onChange(of: presentation.eventDetailPopoverEventID) {
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
        let sections = AgendaDayPresentation.sections(
            events: calendarStore.events,
            now: calendarStore.currentDate,
            calendar: calendarStore.localCalendar
        )
        let contentState = AgendaContentState.resolve(
            events: calendarStore.events,
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
                ForEach(sections, id: \.day) { section in
                    agendaDaySection(section)
                }
            }

            if calendarStore.isStale && !calendarStore.events.isEmpty {
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
    private func agendaDaySection(_ section: AgendaDayPresentation) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(section.day.title)
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textSecondary)

            if section.isEmpty {
                Text(section.emptyMessage)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .padding(.vertical, 7)
            } else {
                ForEach(section.allDayEvents) { event in
                    eventRow(event)
                }

                if section.day == .today, !section.earlierTimedEvents.isEmpty {
                    DisclosureGroup("Earlier today", isExpanded: $showEarlier) {
                        VStack(spacing: 7) {
                            ForEach(section.earlierTimedEvents) { event in
                                eventRow(event)
                            }
                        }
                        .padding(.top, 7)
                    }
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                }

                ForEach(section.timedEvents) { event in
                    eventRow(event)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func eventRow(_ event: CalendarEventSnapshot) -> some View {
        let selected = referenceMoment.selectedEvent?.id == event.id
        let color = calendarColor(for: event)
        HStack(alignment: .top, spacing: 7) {
            Rectangle()
                .fill(color)
                .frame(width: CalendarGridColor.leadingIndicatorWidth)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 3) {
                switch CalendarEventActivationPolicy.action(for: event) {
                case .selectReferenceMoment:
                    Button {
                        referenceMoment.selectEvent(event, sourceZone: .current)
                    } label: {
                        eventTextContent(event)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(eventAccessibilityLabel(event))
                    .accessibilityHint("Sets TimeZoner to this event start")
                case .showDetails:
                    Button {
                        presentation.eventDetailPopoverEventID = event.id
                        onOwnedPopoverChanged(presentation.hasOwnedPopover)
                    } label: {
                        eventTextContent(event)
                    }
                    .buttonStyle(.borderless)
                    .accessibilityLabel(eventAccessibilityLabel(event))
                    .accessibilityHint("Opens event details. Does not set a time.")
                    .popover(isPresented: eventDetailPopoverBinding(for: event), arrowEdge: .bottom) {
                        CalendarEventDetailsPopover(
                            event: event,
                            timeZone: calendarStore.localCalendar.timeZone
                        )
                    }
                }
            }
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 7)
        .background(selected ? Theme.accent.opacity(0.08) : .clear)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Theme.border.opacity(0.55))
                .frame(height: 1)
        }
        .opacity(CalendarEventPresentationStyle.opacity(for: event))
    }

    private func eventTextContent(_ event: CalendarEventSnapshot) -> some View {
        let timedDetails = AgendaTimedEventPresentation(
            event: event,
            timeZone: calendarStore.localCalendar.timeZone
        )
        let metadata = event.isAllDay ? "All-day · \(event.calendarTitle)" : timedDetails.metadata
        return VStack(alignment: .leading, spacing: 3) {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(event.title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(2)
                Spacer(minLength: 0)
            }

            Text(metadata)
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)

            if let participantSummary = AgendaParticipantPresentation.summary(for: event.attendeeNames) {
                Text(participantSummary)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }
        }
    }

    private func eventDetailPopoverBinding(for event: CalendarEventSnapshot) -> Binding<Bool> {
        Binding(
            get: { presentation.eventDetailPopoverEventID == event.id },
            set: { isPresented in
                if isPresented {
                    presentation.eventDetailPopoverEventID = event.id
                } else if presentation.eventDetailPopoverEventID == event.id {
                    presentation.eventDetailPopoverEventID = nil
                }
                onOwnedPopoverChanged(presentation.hasOwnedPopover)
            }
        )
    }

    private func calendarColor(for event: CalendarEventSnapshot) -> Color {
        guard let rawColor = calendarStore.descriptors.first(where: { $0.id == event.calendarID })?.color else {
            return Theme.border
        }
        let color = CalendarGridColor.displayColor(from: rawColor)
        return Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }

    private func eventAccessibilityLabel(_ event: CalendarEventSnapshot) -> String {
        let details = CalendarEventDetailsPresentation(
            event: event,
            timeZone: calendarStore.localCalendar.timeZone
        )
        return "\(details.title), \(details.metadata)"
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendarStore.localCalendar
        formatter.locale = .current
        formatter.timeZone = calendarStore.localCalendar.timeZone
        formatter.dateFormat = "EEEE, MMM d"
        return formatter
    }
}
