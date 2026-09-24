import SwiftUI

/// The full calendar companion. Its state is intentionally limited to visible controls; range
/// ownership, selection, and panel transitions stay in the shared presentation/controller graph.
public struct CalendarModeView: View {
    public let calendarStore: CalendarStore
    public let referenceMoment: ReferenceMomentController
    public let presentation: CalendarPresentationState
    public let onReturnToTimeZoner: () -> Void
    public let onOpenPrivacySettings: () -> Void

    public init(
        calendarStore: CalendarStore,
        referenceMoment: ReferenceMomentController,
        presentation: CalendarPresentationState,
        onReturnToTimeZoner: @escaping () -> Void,
        onOpenPrivacySettings: @escaping () -> Void
    ) {
        self.calendarStore = calendarStore
        self.referenceMoment = referenceMoment
        self.presentation = presentation
        self.onReturnToTimeZoner = onReturnToTimeZoner
        self.onOpenPrivacySettings = onOpenPrivacySettings
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
                Button("Previous \(presentation.range.accessibilityName)") {
                    presentation.move(.previous, calendar: calendar)
                    refreshActiveInterval()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, design: .rounded))
                .help("Previous \(presentation.range.accessibilityName)")

                Button("Next \(presentation.range.accessibilityName)") {
                    presentation.move(.next, calendar: calendar)
                    refreshActiveInterval()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, design: .rounded))
                .help("Next \(presentation.range.accessibilityName)")

                Button("Today") {
                    presentation.goToday(now: calendarStore.currentDate, calendar: calendar)
                    refreshActiveInterval()
                }
                .buttonStyle(.borderless)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.accent)

                Spacer(minLength: 0)

                Text(intervalFormatter.string(from: activeInterval.start))
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
                    onSelectTimedEvent: selectTimedEvent
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

    private var intervalFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = presentation.range == .week ? "MMM d" : "EEEE, MMM d"
        return formatter
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
