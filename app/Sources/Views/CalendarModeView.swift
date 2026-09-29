import SwiftUI

/// The full calendar companion. Its state is intentionally limited to visible controls; range
/// ownership, selection, and panel transitions stay in the shared presentation/controller graph.
public struct CalendarModeView: View {
    public let calendarStore: CalendarStore
    public let referenceMoment: ReferenceMomentController
    public let presentation: CalendarPresentationState
    public let settingsButton: CalendarSettingsButton<SettingsPopover>
    public let onOpenPrivacySettings: () -> Void
    public let onOwnedPopoverChanged: (Bool) -> Void

    public init(
        calendarStore: CalendarStore,
        referenceMoment: ReferenceMomentController,
        presentation: CalendarPresentationState,
        settingsButton: CalendarSettingsButton<SettingsPopover>,
        onOpenPrivacySettings: @escaping () -> Void,
        onOwnedPopoverChanged: @escaping (Bool) -> Void
    ) {
        self.calendarStore = calendarStore
        self.referenceMoment = referenceMoment
        self.presentation = presentation
        self.settingsButton = settingsButton
        self.onOpenPrivacySettings = onOpenPrivacySettings
        self.onOwnedPopoverChanged = onOwnedPopoverChanged
    }

    private var calendar: Calendar { calendarStore.localCalendar }
    private var activeInterval: DateInterval { presentation.activeInterval(calendar: calendar) }

    public var body: some View {
        CalendarPanelChrome(
            isHugging: presentation.agendaPanelHugsMenuBar,
            isFocused: presentation.focusedPanel == .calendar,
            contentOpacity: presentation.workspaceContentOpacity,
            contentOffset: presentation.workspaceContentOffset,
            interactionEnabled: !presentation.isWorkspaceTransitioning
        ) {
            CalendarWorkspaceToolbar(
                calendarStore: calendarStore,
                presentation: presentation,
                settingsButton: settingsButton
            )
        } content: {
            content
        }
    }

    private var minimumGridWidth: CGFloat {
        switch presentation.range {
        case .today: 0
        case .threeDays: 420
        case .week: 700
        }
    }

    @ViewBuilder
    private var content: some View {
        switch calendarStore.authorizationStatus {
        case .fullAccess:
            if calendarStore.hasSnapshot(for: activeInterval) {
                VStack(alignment: .leading, spacing: 6) {
                    Text(calendarSubtitle)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)

                    GeometryReader { proxy in
                        ScrollView(.horizontal) {
                            calendarGrid.frame(
                                width: max(proxy.size.width, minimumGridWidth),
                                height: proxy.size.height
                            )
                        }
                    }
                }
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

    private var calendarGrid: some View {
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
    }

    public func selectTimedEvent(_ event: CalendarEventSnapshot) {
        // The timed event updates the shared reference moment; returning to TimeZoner remains
        // an explicit rail action so the selected event keeps the calendar workspace visible.
        referenceMoment.selectEvent(event, sourceZone: .current)
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

    private var visibleDateRange: String {
        CalendarRangeHeaderPresentation.visibleDateRange(
            for: activeInterval,
            calendar: calendar
        )
    }

    private var calendarSubtitle: String {
        let abbreviation = calendar.timeZone.abbreviation(for: calendarStore.currentDate)
            ?? calendar.timeZone.identifier
        return "\(visibleDateRange) · \(abbreviation)"
    }
}
