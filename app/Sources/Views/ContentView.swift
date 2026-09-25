import SwiftUI

public struct ContentView: View {
    @State private var referenceMoment: ReferenceMomentController
    @State private var presentation: CalendarPresentationState
    @State private var zoneStore: ZoneStore
    @State private var calendarStore: CalendarStore
    @State private var editingZoneId: UUID? = nil
    @State private var highlightedZoneIds: Set<UUID> = []
    @State private var highlightClearToken = UUID()
    @AccessibilityFocusState private var selectedEventContextFocused: Bool
    private let settings: SettingsStore
    private let calendarPreferences: CalendarPreferenceStore
    private let calendarAlertLifecycle: CalendarAlertLifecycleCoordinator
    private let panelController: (any CalendarPanelControlling)?
    private let setAgendaWingRequested: (Bool) -> Void
    private let openCalendarPrivacySettings: () -> Void
    private let openNotificationSettings: () -> Void
    private let deepLinkRouter = DeepLinkRouter.shared

    public init(
        referenceMoment: ReferenceMomentController,
        presentation: CalendarPresentationState,
        zoneStore: ZoneStore,
        calendarStore: CalendarStore,
        settings: SettingsStore,
        calendarPreferences: CalendarPreferenceStore,
        calendarAlertLifecycle: CalendarAlertLifecycleCoordinator,
        panelController: (any CalendarPanelControlling)?,
        setAgendaWingRequested: @escaping (Bool) -> Void,
        openCalendarPrivacySettings: @escaping () -> Void,
        openNotificationSettings: @escaping () -> Void
    ) {
        _referenceMoment = State(initialValue: referenceMoment)
        _presentation = State(initialValue: presentation)
        _zoneStore = State(initialValue: zoneStore)
        _calendarStore = State(initialValue: calendarStore)
        self.settings = settings
        self.calendarPreferences = calendarPreferences
        self.calendarAlertLifecycle = calendarAlertLifecycle
        self.panelController = panelController
        self.setAgendaWingRequested = setAgendaWingRequested
        self.openCalendarPrivacySettings = openCalendarPrivacySettings
        self.openNotificationSettings = openNotificationSettings
    }

    private var timeState: TimeState {
        referenceMoment.timeState
    }

    private var idealWidth: CGFloat {
        CalendarPanelMetrics.normalWidth(cityCount: zoneStore.zones.count)
    }

    private var isTimeAdjusted: Bool {
        !timeState.isLive
    }

    private var normalContent: some View {
        CalendarPanelChrome(
            isHugging: presentation.mainPanelHugsMenuBar,
            isFocused: presentation.focusedPanel == .timezoner
        ) {
            normalHeader
        } content: {
            normalBody
        }
    }

    private var normalHeader: some View {
        HStack(spacing: 8) {
            ChatField(
                referenceMoment: referenceMoment,
                zoneStore: zoneStore,
                editingZoneId: $editingZoneId,
                highlightedZoneIds: $highlightedZoneIds
            )
            .frame(maxWidth: .infinity)
            .layoutPriority(1)

            Button("Now") {
                withAnimation(.easeInOut(duration: 0.2)) {
                    referenceMoment.goLive()
                    editingZoneId = nil
                }
            }
            .buttonStyle(.plain)
            .font(.system(size: 13, weight: .medium, design: .rounded))
            .frame(width: 54, height: 40)
            .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .strokeBorder(Theme.border, lineWidth: 1)
            )
            .foregroundStyle(isTimeAdjusted ? Theme.accent : Theme.textTertiary)

            CalendarToolbarIcon(
                systemName: "calendar",
                label: "Calendar agenda",
                hint: "Shows or hides the compact calendar agenda. Command Shift A focuses it when shown.",
                action: activateCalendar
            )

            normalSettingsButton
        }
    }

    private var normalBody: some View {
        VStack(spacing: 14) {
            if let selectedEvent = referenceMoment.selectedEvent {
                selectedEventContextRow(selectedEvent)
            }

            ZoneCardRow(
                zones: zoneStore.zones,
                referenceMoment: referenceMoment,
                editingZoneId: $editingZoneId,
                highlightedZoneIds: highlightedZoneIds,
                onRemove: { id in
                    withAnimation(.easeInOut(duration: 0.3)) {
                        zoneStore.remove(id: id)
                    }
                },
                onMove: { source, destination in
                    zoneStore.move(from: source, to: destination)
                }
            )

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
    }

    private var normalSettingsButton: CalendarSettingsButton<SettingsPopover> {
        CalendarSettingsButton(
            owner: .timezoner,
            presentation: presentation,
            onActivate: { panelController?.toggleSettings() },
            onOwnedPopoverChanged: { isPresented in
                panelController?.setOwnedPopoverPresented(isPresented)
            }
        ) {
            SettingsPopover(
                settings: settings,
                calendarStore: calendarStore,
                calendarPreferences: calendarPreferences,
                calendarAlertLifecycle: calendarAlertLifecycle,
                setAgendaWingRequested: setAgendaWingRequested,
                openCalendarPrivacySettings: openCalendarPrivacySettings,
                openNotificationSettings: openNotificationSettings
            )
        }
    }

    public var body: some View {
        Group {
            if presentation.destination == .calendar {
                TimeZonerRailView(
                    zones: zoneStore.zones,
                    referenceMoment: referenceMoment,
                    presentation: presentation,
                    onExpand: returnFromCalendarMode
                )
            } else {
                normalContent
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            editingZoneId = nil
        }
        .onAppear {
            ensureDefaultSource()
            if presentation.destination == .timezoner {
                panelController?.resizeMain(to: CGSize(
                    width: idealWidth,
                    height: CalendarPanelMetrics.preferredHeight
                ))
            }
            consumePendingDeepLink()
        }
        .onChange(of: deepLinkRouter.pendingCommand) {
            consumePendingDeepLink()
        }
        .onChange(of: calendarStore.authorizationStatus) {
            resolveCalendarAccessDestination()
        }
        .onReceive(NotificationCenter.default.publisher(for: .focusSelectedEventContext)) { _ in
            guard presentation.destination == .timezoner,
                  referenceMoment.selectedEvent != nil else { return }
            DispatchQueue.main.async {
                selectedEventContextFocused = true
            }
        }
        .animation(.easeInOut(duration: 0.25), value: zoneStore.zones.count)
        .animation(.easeInOut(duration: 0.25), value: isTimeAdjusted)
        .onKeyPress(.escape) {
            panelController?.handleEscape()
            return .handled
        }
        .background {
            Button("") {
                guard presentation.destination == .timezoner else { return }
                focusChatField()
            }
            .keyboardShortcut("n", modifiers: .command)
            .hidden()
        }
        .background {
            Button("") {
                guard CalendarWorkspacePolicy.settingsOwner(destination: presentation.destination) == .timezoner else {
                    return
                }
                panelController?.toggleSettings()
            }
                .keyboardShortcut(",", modifiers: .command)
                .hidden()
        }
        .background {
            Button("") { focusAgendaFromKeyboard() }
                .keyboardShortcut("a", modifiers: [.command, .shift])
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
        setAgendaWingRequested(!presentation.showAgendaWing)
    }

    private func resolveCalendarAccessDestination() {
        switch CalendarAccessFlow.resolution(
            authorizationStatus: calendarStore.authorizationStatus,
            accessDestination: presentation.accessDestination
        ) {
        case .showAgenda:
            presentation.dismissAccessDestination()
            setAgendaWingRequested(true)
        case .showRecovery:
            presentation.presentRecovery()
        case .none, .waitForUserAction:
            break
        }
    }

    private func focusAgendaFromKeyboard() {
        guard CalendarWorkspacePolicy.calendarVisible(
            destination: presentation.destination,
            showAgenda: presentation.showAgendaWing
        ) else { return }
        panelController?.focusAgenda()
    }

    private func returnFromCalendarMode() {
        panelController?.returnToTimeZoner()
    }

    private func finalizeTimeZonerSurfaceRestoration() {
        panelController?.restoreTimeZonerImmediately()
    }

    private func consumePendingDeepLink() {
        guard let deepLink = deepLinkRouter.pendingCommand else { return }
        deepLinkRouter.pendingCommand = nil
        handleDeepLink(deepLink)
    }

    private func handleDeepLink(_ deepLink: TimeZonerDeepLink) {
        editingZoneId = nil

        TimeZonerDeepLinkPresentationRouter.route(
            deepLink,
            presentation: presentation,
            restoreTimeZonerPanel: finalizeTimeZonerSurfaceRestoration,
            apply: applyDeepLink
        )
    }

    private func applyDeepLink(_ deepLink: TimeZonerDeepLink) {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Selected event \(event.title), \(formattedEventStart(event.startDate))")
        .accessibilityFocused($selectedEventContextFocused)
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
    public static let focusSelectedEventContext = Notification.Name("focusSelectedEventContext")
}
