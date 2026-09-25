import SwiftUI

public struct TimeZonerRailView: View {
    public let zones: [ZoneInfo]
    public let referenceMoment: ReferenceMomentController
    public let presentation: CalendarPresentationState
    @Binding public var editingZoneId: UUID?
    public let highlightedZoneIds: Set<UUID>
    public let onRemove: (UUID) -> Void
    public let onMove: (IndexSet, Int) -> Void
    public let onExpand: () -> Void

    @AccessibilityFocusState private var contextFocused: Bool

    public init(
        zones: [ZoneInfo],
        referenceMoment: ReferenceMomentController,
        presentation: CalendarPresentationState,
        editingZoneId: Binding<UUID?>,
        highlightedZoneIds: Set<UUID> = [],
        onRemove: @escaping (UUID) -> Void,
        onMove: @escaping (IndexSet, Int) -> Void = { _, _ in },
        onExpand: @escaping () -> Void
    ) {
        self.zones = zones
        self.referenceMoment = referenceMoment
        self.presentation = presentation
        self._editingZoneId = editingZoneId
        self.highlightedZoneIds = highlightedZoneIds
        self.onRemove = onRemove
        self.onMove = onMove
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
                    if zones.isEmpty {
                        Text("No saved cities\nExpand TimeZoner to add a city.")
                            .font(.system(size: 12, design: .rounded))
                            .foregroundStyle(Theme.textSecondary)
                    } else {
                        ZoneCardCollection(
                            axis: .vertical,
                            zones: zones,
                            referenceMoment: referenceMoment,
                            editingZoneId: $editingZoneId,
                            highlightedZoneIds: highlightedZoneIds,
                            onRemove: onRemove,
                            onMove: onMove
                        )
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

}
