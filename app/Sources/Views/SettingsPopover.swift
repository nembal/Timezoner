import AppKit
import SwiftUI

public struct SettingsPopover: View {
    @Bindable var settings: SettingsStore
    public let calendarStore: CalendarStore
    public let calendarPreferences: CalendarPreferenceStore
    public let calendarAlertLifecycle: CalendarAlertLifecycleCoordinator
    public let setAgendaWingRequested: (Bool) -> Void
    public let openCalendarPrivacySettings: () -> Void
    public let openNotificationSettings: () -> Void
    @State private var loginError: String? = nil
    @State private var notificationLeadDrafts: CalendarNotificationLeadDrafts
    @FocusState private var focusedLeadField: Int?
    @State private var previouslyFocusedLeadField: Int?

    public init(
        settings: SettingsStore,
        calendarStore: CalendarStore,
        calendarPreferences: CalendarPreferenceStore,
        calendarAlertLifecycle: CalendarAlertLifecycleCoordinator,
        setAgendaWingRequested: @escaping (Bool) -> Void,
        openCalendarPrivacySettings: @escaping () -> Void,
        openNotificationSettings: @escaping () -> Void
    ) {
        self.settings = settings
        self.calendarStore = calendarStore
        self.calendarPreferences = calendarPreferences
        self.calendarAlertLifecycle = calendarAlertLifecycle
        self.setAgendaWingRequested = setAgendaWingRequested
        self.openCalendarPrivacySettings = openCalendarPrivacySettings
        self.openNotificationSettings = openNotificationSettings
        _notificationLeadDrafts = State(
            initialValue: CalendarNotificationLeadDrafts(
                committedLeadMinutes: settings.notificationLeadMinutes
            )
        )
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            appearanceSection
            Divider()
            calendarSection
            Divider()
            shortcutsAndBehaviorSection
            Divider()
            helpSection
            Divider()
            footerSection
        }
        .padding(16)
        .frame(width: 320)
        .onChange(of: focusedLeadField) {
            if let previouslyFocusedLeadField {
                commitNotificationLead(at: previouslyFocusedLeadField)
            }
            previouslyFocusedLeadField = focusedLeadField
        }
    }

    // MARK: - Sections

    private var appearanceSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Appearance")
            Picker("", selection: $settings.appearance) {
                Text("System").tag(SettingsStore.AppearancePref.system)
                Text("Light").tag(SettingsStore.AppearancePref.light)
                Text("Dark").tag(SettingsStore.AppearancePref.dark)
            }
            .pickerStyle(.segmented)
            .labelsHidden()
        }
    }

    private var shortcutsAndBehaviorSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 8) {
                Text("Global hotkey")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                Spacer()
                HotkeyRecorderField(shortcut: $settings.hotkey)
                    .frame(width: 130, height: 28)
                Button("Clear") { settings.hotkey = nil }
                    .buttonStyle(.borderless)
                    .foregroundStyle(Theme.textTertiary)
                    .disabled(settings.hotkey == nil)
            }

            Toggle(isOn: Binding(
                get: { settings.launchAtLogin },
                set: { newValue in
                    let result = LaunchAtLogin.set(newValue)
                    switch result {
                    case .ok:
                        settings.launchAtLogin = newValue
                        loginError = nil
                    case .failed(let msg):
                        loginError = msg
                        settings.launchAtLogin = LaunchAtLogin.isEnabled
                    }
                }
            )) {
                Text("Launch at login")
                    .foregroundStyle(Theme.textPrimary)
            }
            .toggleStyle(.checkbox)

            if let loginError {
                Text(loginError)
                    .font(.system(size: 11))
                    .foregroundStyle(.red)
            }
        }
    }

    private var calendarSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionTitle("Calendar")

            Toggle("Show agenda", isOn: Binding(
                get: { settings.showAgendaWing },
                set: setAgendaWingRequested
            ))
            .toggleStyle(.checkbox)

            if calendarStore.authorizationStatus == .fullAccess {
                if calendarStore.descriptors.isEmpty {
                    Text("Calendars appear here after the agenda loads.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                } else {
                    ScrollView(.vertical) {
                        LazyVStack(alignment: .leading, spacing: 8) {
                            ForEach(calendarStore.descriptors) { descriptor in
                                calendarPreferenceRow(for: descriptor)
                            }
                        }
                    }
                    .frame(maxHeight: 156)
                    .accessibilityLabel("Calendar visibility and alert controls")
                }
            } else {
                HStack(spacing: 8) {
                    Text(calendarAccessMessage)
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer(minLength: 4)
                    if calendarStore.authorizationStatus == .notDetermined {
                        Button("Enable Calendar Access") {
                            calendarStore.requestAccess()
                        }
                        .buttonStyle(.borderless)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.accent)
                    } else {
                        Button("Privacy Settings", action: openCalendarPrivacySettings)
                            .buttonStyle(.borderless)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .foregroundStyle(Theme.accent)
                    }
                }
            }

            Toggle("Calendar alerts", isOn: Binding(
                get: { settings.alertsEnabled },
                set: { requested in
                    Task { @MainActor in
                        await calendarAlertLifecycle.setGlobalAlertsEnabled(requested)
                    }
                }
            ))
                .toggleStyle(.checkbox)

            if calendarAlertLifecycle.showsNotificationSettingsRecovery {
                HStack(spacing: 8) {
                    Text("Notifications are off in System Settings.")
                        .font(.system(size: 11, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                    Spacer(minLength: 4)
                    Button("Open Notification Settings", action: openNotificationSettings)
                        .buttonStyle(.borderless)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.accent)
                }
            }

            HStack(spacing: 7) {
                Text("Lead times")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)
                TextField("First reminder minutes", text: notificationLeadBinding(at: 0))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .focused($focusedLeadField, equals: 0)
                    .onSubmit { commitNotificationLead(at: 0) }
                    .accessibilityLabel("First calendar alert lead time in minutes")
                TextField("Second reminder minutes", text: notificationLeadBinding(at: 1))
                    .textFieldStyle(.roundedBorder)
                    .multilineTextAlignment(.trailing)
                    .frame(width: 50)
                    .focused($focusedLeadField, equals: 1)
                    .onSubmit { commitNotificationLead(at: 1) }
                    .accessibilityLabel("Second calendar alert lead time in minutes")
                Text("min")
                    .font(.system(size: 11, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            Text("TimeZoner schedules up to 7 days ahead while the app is running or when it next opens.")
                .font(.system(size: 11, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func calendarPreferenceRow(for descriptor: CalendarDescriptor) -> some View {
        HStack(alignment: .top, spacing: 7) {
            Circle()
                .fill(calendarColor(for: descriptor))
                .frame(width: 8, height: 8)
                .padding(.top, 4)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 1) {
                Text(descriptor.title)
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                Text(descriptor.sourceTitle)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
                    .lineLimit(1)
            }

            Spacer(minLength: 4)

            Toggle("Show", isOn: Binding(
                get: { calendarPreferences.preference(for: descriptor.id).isVisible },
                set: { calendarStore.setVisible($0, calendarID: descriptor.id) }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 10, design: .rounded))
            .accessibilityLabel(CalendarAccessibilityLabels.showCalendar(for: descriptor))

            Toggle("Alerts", isOn: Binding(
                get: { calendarPreferences.preference(for: descriptor.id).alertsEnabled },
                set: { calendarStore.setAlertsEnabled($0, calendarID: descriptor.id) }
            ))
            .toggleStyle(.checkbox)
            .font(.system(size: 10, design: .rounded))
            .accessibilityLabel(CalendarAccessibilityLabels.alertsCalendar(for: descriptor))
        }
    }

    private var calendarAccessMessage: String {
        switch calendarStore.authorizationStatus {
        case .notDetermined:
            return "Calendar access has not been granted."
        case .denied, .restricted, .writeOnly:
            return "Calendar events are unavailable."
        case .fullAccess:
            return ""
        }
    }

    private func calendarColor(for descriptor: CalendarDescriptor) -> Color {
        Color(
            red: descriptor.color.red,
            green: descriptor.color.green,
            blue: descriptor.color.blue,
            opacity: descriptor.color.alpha * 0.65
        )
    }

    private func notificationLeadBinding(at index: Int) -> Binding<String> {
        Binding(
            get: { notificationLeadDrafts.value(at: index) },
            set: { notificationLeadDrafts.edit($0, at: index) }
        )
    }

    private func commitNotificationLead(at index: Int) {
        _ = notificationLeadDrafts.commit(at: index, settings: settings)
    }

    private var helpSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Input formats")
            VStack(alignment: .leading, spacing: 6) {
                formatRow("Set time", ["11:30am SF", "3pm bangkok", "noon NYC"])
                formatRow("Compare zones", ["1130am BKK in SF"])
                formatRow("Bare time", ["11:30", "3pm", "15"])
                formatRow("Add / remove", ["+Tokyo", "add Hong Kong", "-SF"])
            }
        }
    }

    private var footerSection: some View {
        HStack {
            Text("TimeZoner")
                .font(.system(size: 11))
                .foregroundStyle(Theme.textTertiary)
            Spacer()
            Button("Quit") { NSApp.terminate(nil) }
                .buttonStyle(.borderless)
                .foregroundStyle(Theme.textSecondary)
        }
    }

    // MARK: - Helpers

    private func sectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .semibold, design: .rounded))
            .foregroundStyle(Theme.textSecondary)
    }

    private func formatRow(_ label: String, _ examples: [String]) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(label)
                .font(.system(size: 11, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
            HStack(spacing: 6) {
                ForEach(examples, id: \.self) { ex in
                    Text(ex)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(Theme.textPrimary)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            RoundedRectangle(cornerRadius: 4, style: .continuous)
                                .fill(Color.primary.opacity(0.06))
                        )
                }
            }
        }
    }
}
