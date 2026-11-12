import Foundation

/// Rebuilds the next seven days of TimeZoner-owned local notifications from calendar snapshots.
@MainActor
public final class CalendarNotificationScheduler {
    public nonisolated static let defaultLeadMinutes = CalendarNotificationContract.defaultLeadMinutes
    public nonisolated static let requestIdentifierPrefix = CalendarNotificationContract.requestIdentifierPrefix

    private let eventReader: any CalendarEventReading
    private let preferenceStore: CalendarPreferenceStore
    private let notificationCenter: any CalendarNotificationCenter
    private let leadMinutesProvider: () -> [Int]

    public init(
        eventReader: any CalendarEventReading,
        preferenceStore: CalendarPreferenceStore,
        notificationCenter: any CalendarNotificationCenter,
        leadMinutes: [Int] = CalendarNotificationScheduler.defaultLeadMinutes
    ) {
        self.eventReader = eventReader
        self.preferenceStore = preferenceStore
        self.notificationCenter = notificationCenter
        leadMinutesProvider = { CalendarNotificationContract.normalizedLeadMinutes(leadMinutes.map(Optional.some)) }
    }

    /// Uses current settings when lead-time changes should reconcile without replacing scheduler ownership.
    public init(
        eventReader: any CalendarEventReading,
        preferenceStore: CalendarPreferenceStore,
        notificationCenter: any CalendarNotificationCenter,
        leadMinutes: @escaping () -> [Int]
    ) {
        self.eventReader = eventReader
        self.preferenceStore = preferenceStore
        self.notificationCenter = notificationCenter
        leadMinutesProvider = { CalendarNotificationContract.normalizedLeadMinutes(leadMinutes().map(Optional.some)) }
    }

    /// Fetches and reconciles a scheduler-owned, half-open seven-day horizon from `now`.
    ///
    /// The lifecycle owner supplies an eligibility check so an already-running reconciliation can
    /// stop at every asynchronous boundary when Calendar access or TimeZoner alerts are revoked.
    /// A `false` result means no later mutation should be assumed; the serialized lifecycle owner
    /// follows it with its owned-request cleanup after any in-flight add has drained.
    @discardableResult
    public func reconcile(
        now: Date,
        timeZone: TimeZone,
        shouldContinue: @escaping () async -> Bool = { true }
    ) async throws -> Bool {
        guard await shouldContinue() else { return false }
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = timeZone
        let end = calendar.date(byAdding: .day, value: 7, to: now) ?? now.addingTimeInterval(7 * 24 * 60 * 60)

        let calendars = try await eventReader.calendars()
        guard await shouldContinue() else { return false }
        let alertEnabledCalendarIDs = Set(calendars.compactMap { descriptor in
            preferenceStore.preference(for: descriptor.id).alertsEnabled ? descriptor.id : nil
        })
        let events = try await eventReader.events(
            from: now,
            to: end,
            calendarIDs: alertEnabledCalendarIDs
        )
        guard await shouldContinue() else { return false }
        let desired = desiredRequests(for: events, now: now, timeZone: timeZone)
        let pending = await notificationCenter.pendingRequests()
        guard await shouldContinue() else { return false }
        let staleIdentifiers = pending.compactMap { request in
            CalendarNotificationContract.owns(requestIdentifier: request.identifier) && desired[request.identifier] == nil
                ? request.identifier
                : nil
        }

        if !staleIdentifiers.isEmpty {
            await notificationCenter.removePendingRequests(withIdentifiers: staleIdentifiers)
            guard await shouldContinue() else { return false }
        }
        for identifier in desired.keys.sorted() {
            guard await shouldContinue() else { return false }
            guard let request = desired[identifier] else { continue }
            try await notificationCenter.addOrReplace(request)
            guard await shouldContinue() else { return false }
        }
        return true
    }

    private func desiredRequests(
        for events: [CalendarEventSnapshot],
        now: Date,
        timeZone: TimeZone
    ) -> [String: CalendarNotificationRequest] {
        var desired: [String: CalendarNotificationRequest] = [:]
        let leadMinutes = leadMinutesProvider()

        for event in events where isEligible(event, now: now) {
            for leadMinutes in leadMinutes {
                let fireDate = event.startDate.addingTimeInterval(TimeInterval(-leadMinutes * 60))
                guard fireDate > now else { continue }

                let identifier = CalendarNotificationContract.requestIdentifier(
                    occurrenceID: event.id,
                    leadMinutes: leadMinutes
                )
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
        "\(TimeFormatter.formatTimeEditable(date, in: timeZone)) \(timeZoneLabel(for: timeZone, at: date))"
    }

    private func timeZoneLabel(for timeZone: TimeZone, at date: Date) -> String {
        // DateFormatter exposes Bangkok as "GMT+7" on macOS, while the product's compact
        // time input and notification copy use the familiar BKK label.
        if timeZone.identifier == "Asia/Bangkok" {
            return "BKK"
        }
        return timeZone.abbreviation(for: date) ?? timeZone.identifier
    }
}
