import Foundation
import TimeZonerLib
import UserNotifications

/// AppKit/UserNotifications edge adapter. Parsing and routing policy stay in TimeZonerLib.
final class CalendarNotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    private let enqueue: @MainActor (PendingCalendarCommand) -> Void

    init(enqueue: @escaping @MainActor (PendingCalendarCommand) -> Void) {
        self.enqueue = enqueue
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        guard let command = PendingCalendarCommand.notificationCommand(
            requestIdentifier: response.notification.request.identifier,
            userInfo: response.notification.request.content.userInfo
        ) else {
            completionHandler()
            return
        }

        Task { @MainActor [enqueue] in
            enqueue(command)
            completionHandler()
        }
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        switch CalendarNotificationForegroundPolicy.presentation(
            requestIdentifier: notification.request.identifier,
            userInfo: notification.request.content.userInfo
        ) {
        case .none:
            completionHandler([])
        case .bannerAndSound:
            completionHandler([.banner, .sound])
        }
    }
}
