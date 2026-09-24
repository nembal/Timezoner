import SwiftUI

/// The full calendar companion. Its state is intentionally limited to visible controls; range
/// ownership, selection, and panel transitions stay in the shared presentation/controller graph.
public struct CalendarModeView: View {
    public let calendarStore: CalendarStore
    public let referenceMoment: ReferenceMomentController
    public let presentation: CalendarPresentationState
    public let onReturnToTimeZoner: () -> Void
    public let onOpenPrivacySettings: () -> Void
    public let onOwnedPopoverChanged: (Bool) -> Void

    public init(
        calendarStore: CalendarStore,
        referenceMoment: ReferenceMomentController,
        presentation: CalendarPresentationState,
        onReturnToTimeZoner: @escaping () -> Void,
        onOpenPrivacySettings: @escaping () -> Void,
        onOwnedPopoverChanged: @escaping (Bool) -> Void
    ) {
        self.calendarStore = calendarStore
        self.referenceMoment = referenceMoment
        self.presentation = presentation
        self.onReturnToTimeZoner = onReturnToTimeZoner
        self.onOpenPrivacySettings = onOpenPrivacySettings
        self.onOwnedPopoverChanged = onOwnedPopoverChanged
    }

    private var calendar: Calendar { calendarStore.localCalendar }
    private var activeInterval: DateInterval { presentation.activeInterval(calendar: calendar) }

    public var body: some View {
        VStack(spacing: 0) {
            DragHandle(showPill: true, isHugging: presentation.mainPanelHugsMenuBar)

            VStack(spacing: 10) {
                header
                Divider()
                content
            }
            .padding(.horizontal, 14)
            .padding(.bottom, 12)
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear(perform: refreshActiveInterval)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Picker("Calendar range", selection: Binding(
                    get: { presentation.range },
                    set: { range in
                        presentation.setRange(range)
                        refreshActiveInterval()
                    }
                )) {
                    Text("Today").tag(CalendarRangeSelection.today)
                    Text("3 Days").tag(CalendarRangeSelection.threeDays)
                    Text("Week").tag(CalendarRangeSelection.week)
                }
                .pickerStyle(.segmented)

                Button("Back to TimeZoner", action: onReturnToTimeZoner)
                    .buttonStyle(.borderless)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.accent)
            }

            HStack(spacing: 8) {
                Button {
                    presentation.move(.previous, calendar: calendar)
                    refreshActiveInterval()
                } label: {
                    Text("‹")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .accessibilityLabel("Previous \(presentation.range.accessibilityName)")
                .help("Previous \(presentation.range.accessibilityName)")

                Text(headerTitle)
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)

                Button {
                    presentation.move(.next, calendar: calendar)
                    refreshActiveInterval()
                } label: {
                    Text("›")
                }
                .buttonStyle(.borderless)
                .font(.system(size: 16, weight: .medium, design: .rounded))
                .accessibilityLabel("Next \(presentation.range.accessibilityName)")
                .help("Next \(presentation.range.accessibilityName)")

                Button("Today") {
                    presentation.goToday(now: calendarStore.currentDate, calendar: calendar)
                    refreshActiveInterval()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.accent)

                Spacer(minLength: 0)

                Text(visibleDateRange)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch calendarStore.authorizationStatus {
        case .fullAccess:
            if calendarStore.hasSnapshot(for: activeInterval) {
                CalendarTimeGrid(
                    interval: activeInterval,
                    events: calendarStore.events,
                    currentDate: calendarStore.currentDate,
                    descriptorColors: Dictionary(
                        uniqueKeysWithValues: calendarStore.descriptors.map { ($0.id, $0.color) }
                    ),
                    calendar: calendar,
                    onSelectTimedEvent: selectTimedEvent,
                    eventDetailPopoverTarget: eventDetailPopoverTarget,
                    onShowEventDetails: showEventDetails,
                    onEventDetailPopoverChanged: updateEventDetailPopover
                )
            } else if calendarStore.isLoading {
                ProgressView("Loading calendar…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let error = calendarStore.errorMessage {
                VStack(spacing: 7) {
                    Text("Calendar unavailable")
                        .font(.system(size: 13, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                    Text(error)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(.red)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ProgressView("Loading calendar…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        case .notDetermined, .denied, .restricted, .writeOnly:
            CalendarAccessView(
                status: calendarStore.authorizationStatus,
                onEnable: { calendarStore.requestAccess() },
                onOpenPrivacySettings: onOpenPrivacySettings
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
    }

    private func refreshActiveInterval() {
        guard presentation.destination == .calendar,
              calendarStore.authorizationStatus == .fullAccess else {
            return
        }
        calendarStore.refresh(interval: activeInterval)
    }

    private func selectTimedEvent(_ event: CalendarEventSnapshot) {
        referenceMoment.selectEvent(event, sourceZone: .current)
        onReturnToTimeZoner()
    }

    private func showEventDetails(_ event: CalendarEventSnapshot) {
        guard CalendarEventActivationPolicy.action(for: event) == .showDetails else { return }
        updateEventDetailPopover(gridDetailPopoverTarget(for: event))
    }

    private func updateEventDetailPopover(_ target: CalendarEventDetailPopoverTarget?) {
        CalendarEventDetailPopoverOwnership.update(
            target: target,
            presentation: presentation,
            onOwnedPopoverChanged: onOwnedPopoverChanged
        )
    }

    private var eventDetailPopoverTarget: Binding<CalendarEventDetailPopoverTarget?> {
        Binding(
            get: { presentation.eventDetailPopoverTarget },
            set: { updateEventDetailPopover($0) }
        )
    }

    private func gridDetailPopoverTarget(for event: CalendarEventSnapshot) -> CalendarEventDetailPopoverTarget {
        CalendarEventDetailPopoverTarget(eventID: event.id, presenterID: "calendar-grid:\(event.id)")
    }

    private var headerTitle: String {
        CalendarRangeHeaderPresentation.title(
            for: presentation.range,
            interval: activeInterval,
            calendar: calendar
        )
    }

    private var visibleDateRange: String {
        CalendarRangeHeaderPresentation.visibleDateRange(
            for: activeInterval,
            calendar: calendar
        )
    }
}

private extension CalendarRangeSelection {
    var accessibilityName: String {
        switch self {
        case .today: "day"
        case .threeDays: "three days"
        case .week: "week"
        }
    }
}
