import SwiftUI

public struct CalendarAccessView: View {
    public let status: CalendarAuthorizationStatus
    public let onEnable: () -> Void
    public let onOpenPrivacySettings: () -> Void

    public init(
        status: CalendarAuthorizationStatus,
        onEnable: @escaping () -> Void,
        onOpenPrivacySettings: @escaping () -> Void
    ) {
        self.status = status
        self.onEnable = onEnable
        self.onOpenPrivacySettings = onOpenPrivacySettings
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Image(systemName: status == .notDetermined ? "calendar.badge.plus" : "calendar.badge.exclamationmark")
                .font(.system(size: 21, weight: .medium))
                .foregroundStyle(Theme.accent)

            Text(title)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Theme.textPrimary)

            Text(message)
                .font(.system(size: 12, design: .rounded))
                .foregroundStyle(Theme.textSecondary)
                .fixedSize(horizontal: false, vertical: true)

            if status == .notDetermined {
                Button("Enable Calendar Access", action: onEnable)
                    .buttonStyle(.borderedProminent)
                    .tint(Theme.accent)
            } else {
                Button("Open Calendar Privacy Settings", action: onOpenPrivacySettings)
                    .buttonStyle(.bordered)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var title: String {
        status == .notDetermined ? "See today at a glance" : "Calendar access is unavailable"
    }

    private var message: String {
        switch status {
        case .notDetermined:
            return "TimeZoner only reads the calendars you choose after you enable access. Nothing is requested until you choose Enable Calendar Access."
        case .writeOnly:
            return "TimeZoner needs full calendar access to show your agenda."
        case .denied, .restricted:
            return "Allow Calendar access in System Settings, then return to TimeZoner."
        case .fullAccess:
            return "Calendar access is ready."
        }
    }
}
