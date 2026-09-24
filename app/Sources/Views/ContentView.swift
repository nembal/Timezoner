import SwiftUI

public struct ContentView: View {
    @State private var referenceMoment: ReferenceMomentController
    @State private var presentation: CalendarPresentationState
    @State private var zoneStore: ZoneStore
    @State private var calendarStore: CalendarStore
    @State private var editingZoneId: UUID? = nil
    @State private var highlightedZoneIds: Set<UUID> = []
    @State private var highlightClearToken = UUID()
    private let settings: SettingsStore
    private let panelController: (any CalendarPanelControlling)?
    private let deepLinkRouter = DeepLinkRouter.shared

    public init(
        referenceMoment: ReferenceMomentController,
        presentation: CalendarPresentationState,
        zoneStore: ZoneStore,
        calendarStore: CalendarStore,
        settings: SettingsStore,
        panelController: (any CalendarPanelControlling)?
    ) {
        _referenceMoment = State(initialValue: referenceMoment)
        _presentation = State(initialValue: presentation)
        _zoneStore = State(initialValue: zoneStore)
        _calendarStore = State(initialValue: calendarStore)
        self.settings = settings
        self.panelController = panelController
    }

    private var timeState: TimeState {
        referenceMoment.timeState
    }

    private var idealWidth: CGFloat {
        let cardWidth: CGFloat = 155
        let diffLabelWidth: CGFloat = 36
        let padding: CGFloat = 40
        let count = CGFloat(max(zoneStore.zones.count, 2))
        let diffs = max(count - 1, 0) * diffLabelWidth
        return count * cardWidth + diffs + padding
    }

    private var isTimeAdjusted: Bool {
        !timeState.isLive
    }

    private var settingsPopoverBinding: Binding<Bool> {
        Binding(
            get: { presentation.isSettingsPresented },
            set: setSettingsPresented
        )
    }

    private var normalContent: some View {
        VStack(spacing: 0) {
            // Drag handle
            DragHandle(showPill: true, isHugging: presentation.mainPanelHugsMenuBar)

            VStack(spacing: 14) {
                // Chat field + Now + Help
                HStack(spacing: 8) {
                    ChatField(referenceMoment: referenceMoment, zoneStore: zoneStore, editingZoneId: $editingZoneId, highlightedZoneIds: $highlightedZoneIds)

                    Button(action: {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            referenceMoment.goLive()
                            editingZoneId = nil
                        }
                    }) {
                        Text("Now")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(isTimeAdjusted ? Theme.accent : Theme.textTertiary)
                            .padding(.horizontal, 14)
                            .frame(maxHeight: .infinity)
                            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .strokeBorder(Theme.border, lineWidth: 1)
                            )
                        }
                    .buttonStyle(.plain)

                    Button(action: activateCalendar) {
                        Image(systemName: "calendar")
                            .font(.system(size: 14))
                            .foregroundStyle(presentation.showAgendaWing ? Theme.accent : Theme.textTertiary)
                    }
                    .buttonStyle(.plain)
                    .help("Calendar agenda")

                    Button(action: { setSettingsPresented(!presentation.isSettingsPresented) }) {
                        Image(systemName: "gearshape")
                            .font(.system(size: 15))
                            .foregroundStyle(presentation.isSettingsPresented ? Theme.accent : Theme.textTertiary)
                            .rotationEffect(.degrees(presentation.isSettingsPresented ? 22 : 0))
                            .animation(.spring(response: 0.35, dampingFraction: 0.7), value: presentation.isSettingsPresented)
                        }
                    .buttonStyle(.plain)
                    .help("Settings (⌘,)")
                    .popover(isPresented: settingsPopoverBinding, arrowEdge: .bottom) {
                        SettingsPopover(settings: settings)
                    }
                }

                if let selectedEvent = referenceMoment.selectedEvent {
                    selectedEventContextRow(selectedEvent)
                }

                // Zone cards with time difference annotations
                ZoneCardRow(zones: zoneStore.zones, referenceMoment: referenceMoment, editingZoneId: $editingZoneId, highlightedZoneIds: highlightedZoneIds, onRemove: { id in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        zoneStore.remove(id: id)
                    }
                }, onMove: { source, destination in
                    zoneStore.move(from: source, to: destination)
                })

                // Timezone map
                TimezoneMapView(
                    zones: zoneStore.zones,
                    timeState: timeState,
                    highlightedZoneIds: highlightedZoneIds,
                    mapPresentation: presentation,
                    onManualMapToggle: {
                        referenceMoment.didManuallyToggleMap()
                    },
                    onAddZone: { label, ianaId in
                        withAnimation(.easeInOut(duration: 0.3)) {
                            zoneStore.add(label: label, timezoneId: ianaId)
                        }
                    }
                )
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 8)
            .padding(.top, 6)
        }
        .frame(width: idealWidth)
        .fixedSize(horizontal: true, vertical: true)
    }

    public var body: some View {
        Group {
            if presentation.destination == .calendar {
                CalendarModeView(
                    calendarStore: calendarStore,
                    referenceMoment: referenceMoment,
                    presentation: presentation,
                    onReturnToTimeZoner: returnFromCalendarMode
                )
            } else {
                normalContent
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingZoneId = nil
        }
        .background(Theme.background)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: presentation.mainPanelHugsMenuBar ? 0 : 12,
            bottomLeadingRadius: 12,
            bottomTrailingRadius: 12,
            topTrailingRadius: presentation.mainPanelHugsMenuBar ? 0 : 12,
            style: .continuous
        ))
        .onAppear {
            ensureDefaultSource()
            consumePendingDeepLink()
        }
        .onChange(of: deepLinkRouter.pendingCommand) {
            consumePendingDeepLink()
        }
        .animation(.easeInOut(duration: 0.25), value: zoneStore.zones.count)
        .animation(.easeInOut(duration: 0.25), value: isTimeAdjusted)
        .onKeyPress(.escape) {
            panelController?.handleEscape()
            return .handled
        }
        .background {
            Button("") {
                NotificationCenter.default.post(name: .focusChatField, object: nil)
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()
        }
        .background {
            Button("") { setSettingsPresented(!presentation.isSettingsPresented) }
                .keyboardShortcut(",", modifiers: .command)
                .hidden()
        }
        .onChange(of: zoneStore.zones.count) {
            guard presentation.destination == .timezoner else { return }
            DispatchQueue.main.async {
                panelController?.resizeMain(to: CGSize(width: idealWidth, height: 580))
            }
        }
    }

    private func ensureDefaultSource() {
        if let first = zoneStore.zones.first,
           !zoneStore.zones.contains(where: { $0.timeZoneId == timeState.sourceZoneId }) {
            referenceMoment.setSourceZone(first.timeZone)
        }
    }

    private func activateCalendar() {
        switch calendarStore.authorizationStatus {
        case .fullAccess:
            presentation.showAgendaWing.toggle()
            if presentation.showAgendaWing {
                calendarStore.refresh(interval: CalendarStore.agendaInterval(
                    for: calendarStore.currentDate,
                    calendar: calendarStore.localCalendar
                ))
            }
            panelController?.syncAgendaVisibility()
        case .notDetermined:
            presentation.showAgendaWing = true
            presentation.presentAccessExplanation()
            panelController?.syncAgendaVisibility()
        case .denied, .restricted, .writeOnly:
            presentation.showAgendaWing = true
            presentation.presentRecovery()
            panelController?.syncAgendaVisibility()
        }
    }

    private func returnFromCalendarMode() {
        presentation.returnToTimeZoner()
        if presentation.showAgendaWing,
           calendarStore.authorizationStatus == .fullAccess {
            calendarStore.refreshPresentationInterval()
        }
        panelController?.returnToTimeZoner()
    }

    private func setSettingsPresented(_ isPresented: Bool) {
        presentation.isSettingsPresented = isPresented
        panelController?.setOwnedPopoverPresented(presentation.hasOwnedPopover)
    }

    private func consumePendingDeepLink() {
        guard let deepLink = deepLinkRouter.pendingCommand else { return }
        deepLinkRouter.pendingCommand = nil
        handleDeepLink(deepLink)
    }

    private func handleDeepLink(_ deepLink: TimeZonerDeepLink) {
        editingZoneId = nil

        switch deepLink {
        case .open:
            focusChatField()
        case .setTime(let hour, let minute, let zoneID, let label):
            guard let timeZone = TimeZone(identifier: zoneID) else { return }
            ensureZoneExists(zoneID: zoneID, label: label)
            referenceMoment.setTime(hour: hour, minute: minute, in: timeZone)
            highlightZones(matchingZoneID: zoneID)
            focusChatField()
        }
    }

    private func ensureZoneExists(zoneID: String, label: String?) {
        guard !zoneStore.zones.contains(where: { $0.timeZoneId == zoneID }) else { return }
        let fallbackLabel = zoneID.components(separatedBy: "/").last?.replacingOccurrences(of: "_", with: " ") ?? zoneID
        withAnimation(.easeInOut(duration: 0.3)) {
            zoneStore.add(label: label ?? fallbackLabel, timezoneId: zoneID)
        }
    }

    private func highlightZones(matchingZoneID zoneID: String) {
        let ids = Set(zoneStore.zones.filter { $0.timeZoneId == zoneID }.map(\.id))
        let token = UUID()
        highlightClearToken = token
        withAnimation(.easeInOut(duration: 0.2)) {
            highlightedZoneIds = ids
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
            guard highlightClearToken == token else { return }
            withAnimation(.easeInOut(duration: 0.5)) {
                highlightedZoneIds = []
            }
        }
    }

    private func focusChatField() {
        NotificationCenter.default.post(name: .focusChatField, object: nil)
    }

    private func selectedEventContextRow(_ event: SelectedEventContext) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "calendar")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Theme.accent)

            Text(event.title)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textPrimary)
                .lineLimit(1)

            Spacer(minLength: 8)

            Text(formattedEventStart(event.startDate))
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Theme.accent.opacity(0.08), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }

    private func formattedEventStart(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.locale = .current
        formatter.timeZone = .current
        formatter.dateFormat = "MMM d · h:mm a z"
        return formatter.string(from: date)
    }
}

extension Notification.Name {
    public static let focusChatField = Notification.Name("focusChatField")
}
