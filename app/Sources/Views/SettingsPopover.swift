import AppKit
import SwiftUI

public struct SettingsPopover: View {
    @Bindable var settings: SettingsStore
    @State private var loginError: String? = nil

    public init(settings: SettingsStore) {
        self.settings = settings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            appearanceSection
            Divider()
            shortcutsAndBehaviorSection
            Divider()
            helpSection
            Divider()
            footerSection
        }
        .padding(16)
        .frame(width: 320)
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
