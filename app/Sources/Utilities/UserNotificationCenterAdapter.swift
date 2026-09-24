import Foundation
import UserNotifications

/// UserNotifications implementation that exposes only TimeZoner notification value types.
public final class UserNotificationCenterAdapter: CalendarNotificationCenter {
    private let center: UNUserNotificationCenter

    public init(center: UNUserNotificationCenter = .current()) {
        self.center = center
    }

    /// This is the only method that can present the system notification authorization prompt.
    public func requestAuthorization() async throws -> Bool {
        try await center.requestAuthorization(options: [.alert, .sound])
    }

    public func pendingRequests() async -> [CalendarNotificationRequest] {
        let requests = await center.pendingNotificationRequests()
        return requests.map(snapshot(from:))
    }

    public func addOrReplace(_ request: CalendarNotificationRequest) async throws {
        let content = UNMutableNotificationContent()
        content.title = request.title
        content.body = request.body
        content.sound = .default
        content.userInfo = [
            "occurrenceID": request.userInfo.occurrenceID,
            "title": request.userInfo.title,
            "startTimestamp": request.userInfo.startTimestamp
        ]

        var calendar = Calendar.autoupdatingCurrent
        calendar.timeZone = .autoupdatingCurrent
        let components = calendar.dateComponents(
            [.calendar, .timeZone, .year, .month, .day, .hour, .minute, .second],
            from: request.fireDate
        )
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        try await center.add(UNNotificationRequest(identifier: request.identifier, content: content, trigger: trigger))
    }

    public func removePendingRequests(withIdentifiers identifiers: [String]) async {
        center.removePendingNotificationRequests(withIdentifiers: identifiers)
    }

    private func snapshot(from request: UNNotificationRequest) -> CalendarNotificationRequest {
        let startTimestamp = (request.content.userInfo["startTimestamp"] as? NSNumber)?.doubleValue ?? 0
        let occurrenceID = request.content.userInfo["occurrenceID"] as? String ?? ""
        let title = request.content.userInfo["title"] as? String ?? request.content.title
        return CalendarNotificationRequest(
            identifier: request.identifier,
            title: request.content.title,
            body: request.content.body,
            fireDate: (request.trigger as? UNCalendarNotificationTrigger)?.nextTriggerDate() ?? .distantFuture,
            userInfo: CalendarNotificationUserInfo(
                occurrenceID: occurrenceID,
                title: title,
                startTimestamp: startTimestamp
            )
        )
    }
}
