import Foundation

/// Rebuilds the next seven days of TimeZoner-owned local notifications from calendar snapshots.
public final class CalendarNotificationScheduler {
    public static let defaultLeadMinutes = [30, 10]
    public static let requestIdentifierPrefix = "timezoner.event."

    private let eventReader: any CalendarEventReading
    private let preferenceStore: CalendarPreferenceStore
    private let notificationCenter: any CalendarNotificationCenter
    private let leadMinutes: [Int]

    public init(
        eventReader: any CalendarEventReading,
        preferenceStore: CalendarPreferenceStore,
        notificationCenter: any CalendarNotificationCenter,
        leadMinutes: [Int] = CalendarNotificationScheduler.defaultLeadMinutes
    ) {
        self.eventReader = eventReader
        self.preferenceStore = preferenceStore
        self.notificationCenter = notificationCenter
        self.leadMinutes = Array(Set(leadMinutes.filter { (0...1_440).contains($0) })).sorted(by: >)
    }

    /// Fetches and reconciles a scheduler-owned, half-open seven-day horizon from `now`.
    public func reconcile(now: Date, timeZone: TimeZone) async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        let end = calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 24 * 60 * 60)

        let calendars = try await eventReader.calendars()
        let alertEnabledCalendarIDs = Set(calendars.compactMap { descriptor in
            preferenceStore.preference(for: descriptor.id).alertsEnabled ? descriptor.id : nil
        })
        let events = try await eventReader.events(
            from: now,
            to: end,
            calendarIDs: alertEnabledCalendarIDs
        )
        let desired = desiredRequests(for: events, now: now, timeZone: timeZone)
        let pending = await notificationCenter.pendingRequests()
        let staleIdentifiers = pending.compactMap { request in
            request.identifier.hasPrefix(Self.requestIdentifierPrefix) && desired[request.identifier] == nil
                ? request.identifier
                : nil
        }

        if !staleIdentifiers.isEmpty {
            await notificationCenter.removePendingRequests(withIdentifiers: staleIdentifiers)
        }
        for identifier in desired.keys.sorted() {
            guard let request = desired[identifier] else { continue }
            try await notificationCenter.addOrReplace(request)
        }
    }

    private func desiredRequests(
        for events: [CalendarEventSnapshot],
        now: Date,
        timeZone: TimeZone
    ) -> [String: CalendarNotificationRequest] {
        var desired: [String: CalendarNotificationRequest] = [:]

        for event in events where isEligible(event, now: now) {
            for leadMinutes in leadMinutes {
                let fireDate = event.startDate.addingTimeInterval(TimeInterval(-leadMinutes * 60))
                guard fireDate > now else { continue }

                let identifier = "\(Self.requestIdentifierPrefix)\(event.id).\(leadMinutes)"
                desired[identifier] = CalendarNotificationRequest(
                    identifier: identifier,
                    title: event.title,
                    body: "Starts in \(leadMinutes) min · \(formattedStart(event.startDate, timeZone: timeZone))",
                    fireDate: fireDate,
                    userInfo: CalendarNotificationUserInfo(
                        occurrenceID: event.id,
                        title: event.title,
                        startTimestamp: event.startDate.timeIntervalSince1970
                    )
                )
            }
        }

        return desired
    }

    private func isEligible(_ event: CalendarEventSnapshot, now: Date) -> Bool {
        preferenceStore.preference(for: event.calendarID).alertsEnabled
            && !event.isAllDay
            && event.participationStatus != .declined
            && event.endDate > now
    }

    private func formattedStart(_ date: Date, timeZone: TimeZone) -> String {
        "\(TimeFormatter.formatTimeEditable(date, in: timeZone)) \(timeZoneLabel(for: timeZone))"
    }

    private func timeZoneLabel(for timeZone: TimeZone) -> String {
        // DateFormatter exposes Bangkok as "GMT+7" on macOS, while the product's compact
        // time input and notification copy use the familiar BKK label.
        if timeZone.identifier == "Asia/Bangkok" {
            return "BKK"
        }
        return timeZone.abbreviation() ?? timeZone.identifier
    }
}
