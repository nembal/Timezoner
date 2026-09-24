import AppKit
import Foundation

@Observable
public final class SettingsStore {
    public enum AppearancePref: String, Codable, CaseIterable {
        case system, light, dark
    }

    public struct Shortcut: Codable, Equatable {
        public var keyCode: UInt32
        public var modifiers: UInt32
        public var display: String

        public init(keyCode: UInt32, modifiers: UInt32, display: String) {
            self.keyCode = keyCode
            self.modifiers = modifiers
            self.display = display
        }
    }

    public static let shared = SettingsStore()

    public static let defaultHotkey = Shortcut(
        keyCode: 0x11,        // kVK_ANSI_T
        modifiers: 0x0900,    // cmdKey (0x0100) | optionKey (0x0800)
        display: "⌘⌥T"
    )

    public var appearance: AppearancePref {
        didSet { persist(); applyAppearance() }
    }
    public var launchAtLogin: Bool {
        didSet { persist(); onLaunchAtLoginChange?(launchAtLogin) }
    }
    public var hotkey: Shortcut? {
        didSet { persist(); onHotkeyChange?(hotkey) }
    }
    public var showAgendaWing: Bool {
        didSet { persist() }
    }
    public var alertsEnabled: Bool {
        didSet { persist() }
    }
    public private(set) var notificationLeadMinutes: [Int]

    public var onHotkeyChange: ((Shortcut?) -> Void)?
    public var onLaunchAtLoginChange: ((Bool) -> Void)?

    private let userDefaults: UserDefaults
    private let keys: Keys

    public struct Keys {
        public let appearance: String
        public let launchAtLogin: String
        public let hotkey: String
        public let showAgendaWing: String
        public let alertsEnabled: String
        public let notificationLeadMinutes: String

        public init(
            appearance: String,
            launchAtLogin: String,
            hotkey: String,
            showAgendaWing: String,
            alertsEnabled: String = "settings.alertsEnabled",
            notificationLeadMinutes: String = "settings.notificationLeadMinutes"
        ) {
            self.appearance = appearance
            self.launchAtLogin = launchAtLogin
            self.hotkey = hotkey
            self.showAgendaWing = showAgendaWing
            self.alertsEnabled = alertsEnabled
            self.notificationLeadMinutes = notificationLeadMinutes
        }

        public static let `default` = Keys(
            appearance: "settings.appearance",
            launchAtLogin: "settings.launchAtLogin",
            hotkey: "settings.hotkey",
            showAgendaWing: "settings.showAgendaWing",
            alertsEnabled: "settings.alertsEnabled",
            notificationLeadMinutes: "settings.notificationLeadMinutes"
        )
    }

    public init(userDefaults: UserDefaults = .standard, keys: Keys = .default) {
        self.userDefaults = userDefaults
        self.keys = keys

        if let raw = userDefaults.string(forKey: keys.appearance),
           let pref = AppearancePref(rawValue: raw) {
            self.appearance = pref
        } else {
            self.appearance = .system
        }

        if userDefaults.object(forKey: keys.launchAtLogin) != nil {
            self.launchAtLogin = userDefaults.bool(forKey: keys.launchAtLogin)
        } else {
            self.launchAtLogin = false
        }

        if let data = userDefaults.data(forKey: keys.hotkey) {
            if data.isEmpty {
                self.hotkey = nil
            } else if let decoded = try? JSONDecoder().decode(Shortcut.self, from: data) {
                self.hotkey = decoded
            } else {
                self.hotkey = Self.defaultHotkey
            }
        } else {
            self.hotkey = Self.defaultHotkey
        }

        if userDefaults.object(forKey: keys.showAgendaWing) != nil {
            self.showAgendaWing = userDefaults.bool(forKey: keys.showAgendaWing)
        } else {
            self.showAgendaWing = false
        }

        if userDefaults.object(forKey: keys.alertsEnabled) != nil {
            self.alertsEnabled = userDefaults.bool(forKey: keys.alertsEnabled)
        } else {
            self.alertsEnabled = false
        }

        if let data = userDefaults.data(forKey: keys.notificationLeadMinutes),
           let decoded = try? JSONDecoder().decode([Int].self, from: data) {
            self.notificationLeadMinutes = Self.normalizedNotificationLeadMinutes(decoded.map(Optional.some))
        } else {
            self.notificationLeadMinutes = [30, 10]
        }
    }

    public static func normalizedNotificationLeadMinutes(_ values: [Int?]) -> [Int] {
        Array(Set(values.compactMap { value in
            guard let value, (0...1_440).contains(value) else { return nil }
            return value
        })).sorted(by: >)
    }

    public func setNotificationLeadMinutes(_ values: [Int?]) {
        notificationLeadMinutes = Self.normalizedNotificationLeadMinutes(values)
        persist()
    }

    public func applyAppearance() {
        let target: NSAppearance?
        switch appearance {
        case .system: target = nil
        case .light:  target = NSAppearance(named: .aqua)
        case .dark:   target = NSAppearance(named: .darkAqua)
        }
        NSApp?.appearance = target
    }

    private func persist() {
        userDefaults.set(appearance.rawValue, forKey: keys.appearance)
        userDefaults.set(launchAtLogin, forKey: keys.launchAtLogin)
        if let hotkey, let data = try? JSONEncoder().encode(hotkey) {
            userDefaults.set(data, forKey: keys.hotkey)
        } else {
            userDefaults.set(Data(), forKey: keys.hotkey)
        }
        userDefaults.set(showAgendaWing, forKey: keys.showAgendaWing)
        userDefaults.set(alertsEnabled, forKey: keys.alertsEnabled)
        if let data = try? JSONEncoder().encode(notificationLeadMinutes) {
            userDefaults.set(data, forKey: keys.notificationLeadMinutes)
        }
    }
}
