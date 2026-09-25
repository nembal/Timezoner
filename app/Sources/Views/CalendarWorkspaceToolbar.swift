import SwiftUI

public struct CalendarWorkspaceToolbar: View {
    public let calendarStore: CalendarStore
    public let presentation: CalendarPresentationState
    public let settingsButton: CalendarSettingsButton<SettingsPopover>

    public init(
        calendarStore: CalendarStore,
        presentation: CalendarPresentationState,
        settingsButton: CalendarSettingsButton<SettingsPopover>
    ) {
        self.calendarStore = calendarStore
        self.presentation = presentation
        self.settingsButton = settingsButton
    }

    public var body: some View {
        GeometryReader { proxy in
            let compact = proxy.size.width + 2 * CalendarPanelMetrics.horizontalInset
                < CalendarPanelMetrics.compactToolbarThreshold

            HStack(spacing: compact ? 4 : 8) {
                if compact {
                    Picker("Calendar range", selection: selection) {
                        rangeOptions
                    }
                    .pickerStyle(.menu)
                    .frame(width: 76, height: 28)
                } else {
                    Picker("Calendar range", selection: selection) {
                        rangeOptions
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 184, height: 28)
                }

                CalendarToolbarIcon(
                    systemName: "chevron.left",
                    label: "Previous \(rangeName)",
                    hint: "Moves to the previous calendar range.",
                    action: { move(.previous) }
                )

                Text(compact ? compactTitle : title)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .frame(minWidth: compact ? 45 : 66)
                    .accessibilityLabel(title)

                CalendarToolbarIcon(
                    systemName: "chevron.right",
                    label: "Next \(rangeName)",
                    hint: "Moves to the next calendar range.",
                    action: { move(.next) }
                )

                Button("Today") {
                    presentation.goToday(now: calendarStore.currentDate, calendar: calendarStore.localCalendar)
                    refresh()
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.accent)
                .frame(minWidth: 36, minHeight: 28)
                .accessibilityLabel("Jump to today")

                Spacer(minLength: 0)
                settingsButton
            }
            .controlSize(.small)
            .font(.system(size: 11, weight: .medium, design: .rounded))
            .frame(height: CalendarPanelMetrics.navHeight)
        }
        .frame(height: CalendarPanelMetrics.navHeight)
    }

    private var selection: Binding<CalendarRangeSelection> {
        Binding(
            get: { presentation.range },
            set: {
                presentation.setRange($0)
                refresh()
            }
        )
    }

    private var rangeOptions: some View {
        Group {
            Text("Today")
                .tag(CalendarRangeSelection.today)
                .accessibilityLabel("Day view")
            Text("3 Day")
                .tag(CalendarRangeSelection.threeDays)
                .accessibilityLabel("Three day view")
            Text("Week")
                .tag(CalendarRangeSelection.week)
                .accessibilityLabel("Week view")
        }
    }

    private var rangeName: String {
        switch presentation.range {
        case .today: "day"
        case .threeDays: "three days"
        case .week: "week"
        }
    }

    private var title: String {
        CalendarRangeHeaderPresentation.title(
            for: presentation.range,
            interval: presentation.activeInterval(calendar: calendarStore.localCalendar),
            currentDate: calendarStore.currentDate,
            calendar: calendarStore.localCalendar
        )
    }

    private var compactTitle: String {
        guard presentation.range != .week else { return title }
        let formatter = DateFormatter()
        formatter.locale = calendarStore.localCalendar.locale ?? .current
        formatter.timeZone = calendarStore.localCalendar.timeZone
        formatter.setLocalizedDateFormatFromTemplate("MMMd")
        return formatter.string(from: presentation.activeInterval(calendar: calendarStore.localCalendar).start)
    }

    private func move(_ direction: CalendarRangeNavigationDirection) {
        presentation.move(direction, calendar: calendarStore.localCalendar)
        refresh()
    }

    private func refresh() {
        guard calendarStore.authorizationStatus == .fullAccess else { return }
        calendarStore.refreshPresentationInterval()
    }
}
