import Foundation

public enum TimeZonerDeepLink: Equatable {
    case open
    case setTime(hour: Int, minute: Int, zoneID: String, label: String?)

    public static func parse(_ url: URL) -> TimeZonerDeepLink? {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "timezoner" else {
            return nil
        }

        switch components.host {
        case "open":
            return .open
        case "set":
            return parseSetTime(components)
        default:
            return nil
        }
    }

    private static func parseSetTime(_ components: URLComponents) -> TimeZonerDeepLink? {
        let items = components.queryItems ?? []
        guard let hourString = items.first(where: { $0.name == "hour" })?.value,
              let minuteString = items.first(where: { $0.name == "minute" })?.value,
              let zoneID = items.first(where: { $0.name == "zone" })?.value,
              let hour = Int(hourString),
              let minute = Int(minuteString),
              (0...23).contains(hour),
              (0...59).contains(minute),
              TimeZone(identifier: zoneID) != nil else {
            return nil
        }

        let label = items.first(where: { $0.name == "label" })?.value
        return .setTime(hour: hour, minute: minute, zoneID: zoneID, label: label?.isEmpty == true ? nil : label)
    }
}

extension Notification.Name {
    public static let timeZonerDeepLink = Notification.Name("timeZonerDeepLink")
}
