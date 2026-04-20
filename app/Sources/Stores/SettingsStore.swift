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

    public var onHotkeyChange: ((Shortcut?) -> Void)?
    public var onLaunchAtLoginChange: ((Bool) -> Void)?

    private let userDefaults: UserDefaults
    private let keys: Keys

    public struct Keys {
        public let appearance: String
        public let launchAtLogin: String
        public let hotkey: String

        public init(appearance: String, launchAtLogin: String, hotkey: String) {
            self.appearance = appearance
            self.launchAtLogin = launchAtLogin
            self.hotkey = hotkey
        }

        public static let `default` = Keys(
            appearance: "settings.appearance",
            launchAtLogin: "settings.launchAtLogin",
            hotkey: "settings.hotkey"
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
    }
}
