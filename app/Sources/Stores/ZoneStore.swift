import Foundation

@Observable
public class ZoneStore {
    public var zones: [ZoneInfo]

    private let userDefaults: UserDefaults
    private let storageKey: String

    public static let defaults: [ZoneInfo] = [
        ZoneInfo(label: "Bangkok", timeZoneId: "Asia/Bangkok"),
        ZoneInfo(label: "SF", timeZoneId: "America/Los_Angeles"),
        ZoneInfo(label: "New York", timeZoneId: "America/New_York"),
        ZoneInfo(label: "Europe", timeZoneId: "Europe/Paris"),
    ]

    public init(userDefaults: UserDefaults = .standard, storageKey: String = "zones") {
        self.userDefaults = userDefaults
        self.storageKey = storageKey
        if let data = userDefaults.data(forKey: storageKey),
           let saved = try? JSONDecoder().decode([ZoneInfo].self, from: data) {
            self.zones = saved
        } else {
            self.zones = Self.defaults
        }
    }

    public func add(label: String, timezoneId: String) {
        let zone = ZoneInfo(label: label, timeZoneId: timezoneId)
        zones.append(zone)
        save()
    }

    public func remove(id: UUID) {
        zones.removeAll { $0.id == id }
        save()
    }

    public func move(from source: IndexSet, to destination: Int) {
        zones.move(fromOffsets: source, toOffset: destination)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(zones) {
            userDefaults.set(data, forKey: storageKey)
        }
    }
}
