import Foundation

/// A TimeZoner-owned local notification request expressed without UserNotifications types.
public struct CalendarNotificationRequest: Equatable, Sendable {
    public let identifier: String
    public let title: String
    public let body: String
    public let fireDate: Date
    public let userInfo: CalendarNotificationUserInfo

    public init(
        identifier: String,
        title: String,
        body: String,
        fireDate: Date,
        userInfo: CalendarNotificationUserInfo
    ) {
        self.identifier = identifier
        self.title = title
        self.body = body
        self.fireDate = fireDate
        self.userInfo = userInfo
    }
}

/// Values needed to select an event after a notification response, without retaining EventKit data.
public struct CalendarNotificationUserInfo: Equatable, Sendable {
    public let occurrenceID: String
    public let title: String
    public let startTimestamp: TimeInterval

    public init(occurrenceID: String, title: String, startTimestamp: TimeInterval) {
        self.occurrenceID = occurrenceID
        self.title = title
        self.startTimestamp = startTimestamp
    }
}

/// The testable boundary around UserNotifications. Authorization is deliberately explicit.
public protocol CalendarNotificationCenter: AnyObject {
    func requestAuthorization() async throws -> Bool
    func pendingRequests() async -> [CalendarNotificationRequest]
    func addOrReplace(_ request: CalendarNotificationRequest) async throws
    func removePendingRequests(withIdentifiers identifiers: [String]) async
}
