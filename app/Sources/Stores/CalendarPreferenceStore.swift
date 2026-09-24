import Foundation

public struct CalendarPreference: Codable, Equatable, Sendable {
    public var isVisible: Bool
    public var alertsEnabled: Bool

    public init(isVisible: Bool, alertsEnabled: Bool) {
        self.isVisible = isVisible
        self.alertsEnabled = alertsEnabled
    }

    public static let `default` = CalendarPreference(isVisible: true, alertsEnabled: true)
}

@Observable
public final class CalendarPreferenceStore {
    private let userDefaults: UserDefaults
    private let storageKey: String
    private var preferences: [String: CalendarPreference]

    public init(userDefaults: UserDefaults = .standard, storageKey: String = "calendar.preferences") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        if let data = userDefaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([String: CalendarPreference].self, from: data) {
            self.preferences = saved
        } else {
            self.preferences = [:]
        }
    }

    public func preference(for calendarID: String) -> CalendarPreference {
        preferences[calendarID] ?? .default
    }

    public func setVisible(_ isVisible: Bool, calendarID: String) {
        var preference = preference(for: calendarID)
        preference.isVisible = isVisible
        preferences[calendarID] = preference
        persist()
    }

    public func setAlertsEnabled(_ alertsEnabled: Bool, calendarID: String) {
        var preference = preference(for: calendarID)
        preference.alertsEnabled = alertsEnabled
        preferences[calendarID] = preference
        persist()
    }

    private func persist() {
        guard let data = try? JSONEncoder().encode(preferences) else { return }
        userDefaults.set(data, forKey: storageKey)
    }
}
