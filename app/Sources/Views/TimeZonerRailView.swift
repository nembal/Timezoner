import SwiftUI

public struct TimeZonerRailView: View {
    public let zones: [ZoneInfo]
    public let referenceMoment: ReferenceMomentController
    public let presentation: CalendarPresentationState
    public let onExpand: () -> Void

    @AccessibilityFocusState private var contextFocused: Bool

    public init(
        zones: [ZoneInfo],
        referenceMoment: ReferenceMomentController,
        presentation: CalendarPresentationState,
        onExpand: @escaping () -> Void
    ) {
        self.zones = zones
        self.referenceMoment = referenceMoment
        self.presentation = presentation
        self.onExpand = onExpand
    }

    public var body: some View {
        CalendarPanelChrome(
            isHugging: presentation.mainPanelHugsMenuBar,
            isFocused: presentation.focusedPanel == .timezoner,
            contentOpacity: presentation.workspaceContentOpacity,
            contentOffset: presentation.workspaceContentOffset,
            interactionEnabled: !presentation.isWorkspaceTransitioning
        ) {
            HStack(spacing: 8) {
                Button("Now") { referenceMoment.goLive() }
                    .buttonStyle(.plain)
                    .font(.system(size: 13, weight: .medium, design: .rounded))
                    .frame(width: 54, height: 40)
                    .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 10))
                    .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.border, lineWidth: 1))
                    .foregroundStyle(referenceMoment.timeState.isLive ? Theme.textTertiary : Theme.accent)
                Spacer(minLength: 0)
                CalendarToolbarIcon(
                    systemName: CalendarNavigationIconControl.expandTimeZoner.systemImageName,
                    label: CalendarNavigationIconControl.expandTimeZoner.accessibilityLabel,
                    hint: CalendarNavigationIconControl.expandTimeZoner.accessibilityHint,
                    action: onExpand
                )
            }
        } content: {
            VStack(alignment: .leading, spacing: 10) {
                context.frame(height: 44, alignment: .topLeading)
                ScrollView(.vertical) {
                    LazyVStack(spacing: 10) {
                        if zones.isEmpty {
                            Text("No saved cities\nExpand TimeZoner to add a city.")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                        }
                        ForEach(zones) { zone in
                            card(CalendarRailCardPresentation(zone: zone, date: referenceMoment.timeState.referenceDate))
                        }
                    }
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSelectedEventContext)) { _ in
            guard presentation.destination == .calendar, referenceMoment.selectedEvent != nil else { return }
            DispatchQueue.main.async { contextFocused = true }
        }
    }

    private var context: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(referenceMoment.selectedEvent?.title ?? "Current time")
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(2)
            Text(contextTime)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .lineLimit(1)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(referenceMoment.selectedEvent?.title ?? "Current time"), \(contextTime)")
        .accessibilityFocused($contextFocused)
        .help(referenceMoment.selectedEvent?.title ?? "Current time")
    }

    private var contextTime: String {
        let date = referenceMoment.timeState.referenceDate
        return "\(TimeFormatter.formatDate(date, in: .current)) · \(TimeFormatter.formatTime(date, in: .current)) \(TimeZone.current.abbreviation(for: date) ?? TimeZone.current.identifier)"
    }

    private func card(_ value: CalendarRailCardPresentation) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Text(value.title)
                    .font(.system(size: 14, weight: .medium, design: .rounded))
                    .lineLimit(1)
                Spacer(minLength: 4)
                Text(value.offset)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }
            Text(value.time)
                .font(.system(size: 28, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            Text(value.date)
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
        }
        .foregroundStyle(Theme.textPrimary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.border, lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(value.accessibilityLabel)
    }
}
