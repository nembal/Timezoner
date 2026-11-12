import Foundation

/// Stable identifiers, payload fields, and lead times for TimeZoner calendar alerts.
public enum CalendarNotificationContract {
    public static let requestIdentifierPrefix = "timezoner.event."
    public static let defaultLeadMinutes = [30, 10]

    public enum PayloadKey {
        public static let occurrenceID = "occurrenceID"
        public static let title = "title"
        public static let startTimestamp = "startTimestamp"
    }

    public static func owns(requestIdentifier: String) -> Bool {
        requestIdentifier.hasPrefix(requestIdentifierPrefix)
    }

    public static func requestIdentifier(occurrenceID: String, leadMinutes: Int) -> String {
        "\(requestIdentifierPrefix)\(occurrenceID).\(leadMinutes)"
    }

    public static func normalizedLeadMinutes(_ values: [Int?]) -> [Int] {
        Array(Set(values.compactMap { value in
            guard let value, (0...1_440).contains(value) else { return nil }
            return value
        })).sorted(by: >)
    }

    public static func payload(for info: CalendarNotificationUserInfo) -> [AnyHashable: Any] {
        [
            PayloadKey.occurrenceID: info.occurrenceID,
            PayloadKey.title: info.title,
            PayloadKey.startTimestamp: info.startTimestamp
        ]
    }
}
