import Foundation

public struct ZoneInfo: Identifiable, Codable, Equatable {
    public let id: UUID
    public var label: String        // Display name: "Bangkok", "SF", "New York"
    public var timeZoneId: String   // IANA: "Asia/Bangkok"

    public var timeZone: TimeZone {
        TimeZone(identifier: timeZoneId) ?? .current
    }

    public init(id: UUID = UUID(), label: String, timeZoneId: String) {
        self.id = id
        self.label = label
        self.timeZoneId = timeZoneId
    }
}
