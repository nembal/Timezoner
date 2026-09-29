import AppKit
import Foundation

/// Wall-clock signals used by calendar presentation and alerts. This deliberately does not read
/// `TimeState.referenceDate`, which may be pinned to an event in the past or future.
public final class CalendarClock {
    public let now: () -> Date
    public var calendar: Calendar { calendarProvider() }

    public let minuteTicks: AsyncStream<Void>
    public let midnightTicks: AsyncStream<Void>
    public let hourTicks: AsyncStream<Void>
    public let wakeEvents: AsyncStream<Void>
    public let activationEvents: AsyncStream<Void>
    public let reopenEvents: AsyncStream<Void>
    public let timeZoneChanges: AsyncStream<Void>
    public let systemClockChanges: AsyncStream<Void>

    private let calendarProvider: () -> Calendar
    private var continuations: [AsyncStream<Void>.Continuation] = []
    private var observerTokens: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var timers: [(timer: DispatchSourceTimer, components: DateComponents)] = []
    private let scheduleTimer: (DispatchSourceTimer, TimeInterval) -> Void
    private var reopenContinuation: AsyncStream<Void>.Continuation?

    public init(
        now: @escaping () -> Date = { .now },
        calendar: @escaping () -> Calendar = { .autoupdatingCurrent },
        minuteTicks: AsyncStream<Void>? = nil,
        midnightTicks: AsyncStream<Void>? = nil,
        hourTicks: AsyncStream<Void>? = nil,
        wakeEvents: AsyncStream<Void>? = nil,
        activationEvents: AsyncStream<Void>? = nil,
        reopenEvents: AsyncStream<Void>? = nil,
        timeZoneChanges: AsyncStream<Void>? = nil,
        systemClockChanges: AsyncStream<Void>? = nil,
        wakeNotificationCenter: NotificationCenter = NSWorkspace.shared.notificationCenter,
        scheduleTimer: @escaping (DispatchSourceTimer, TimeInterval) -> Void = { timer, delay in
            timer.schedule(deadline: .now() + delay, repeating: .never)
        }
    ) {
        self.now = now
        calendarProvider = calendar
        self.scheduleTimer = scheduleTimer
        var minuteContinuation: AsyncStream<Void>.Continuation?
        var midnightContinuation: AsyncStream<Void>.Continuation?
        var hourContinuation: AsyncStream<Void>.Continuation?
        var wakeContinuation: AsyncStream<Void>.Continuation?
        var activationContinuation: AsyncStream<Void>.Continuation?
        var timeZoneContinuation: AsyncStream<Void>.Continuation?
        var systemClockContinuation: AsyncStream<Void>.Continuation?

        if let minuteTicks {
            self.minuteTicks = minuteTicks
        } else {
            let stream = Self.makeStream()
            self.minuteTicks = stream.stream
            continuations.append(stream.continuation)
            minuteContinuation = stream.continuation
        }

        if let midnightTicks {
            self.midnightTicks = midnightTicks
        } else {
            let stream = Self.makeStream()
            self.midnightTicks = stream.stream
            continuations.append(stream.continuation)
            midnightContinuation = stream.continuation
        }

        if let hourTicks {
            self.hourTicks = hourTicks
        } else {
            let stream = Self.makeStream()
            self.hourTicks = stream.stream
            continuations.append(stream.continuation)
            hourContinuation = stream.continuation
        }

        if let wakeEvents {
            self.wakeEvents = wakeEvents
        } else {
            let stream = Self.makeStream()
            self.wakeEvents = stream.stream
            continuations.append(stream.continuation)
            wakeContinuation = stream.continuation
        }

        if let activationEvents {
            self.activationEvents = activationEvents
        } else {
            let stream = Self.makeStream()
            self.activationEvents = stream.stream
            continuations.append(stream.continuation)
            activationContinuation = stream.continuation
        }

        if let reopenEvents {
            self.reopenEvents = reopenEvents
        } else {
            let stream = Self.makeStream()
            self.reopenEvents = stream.stream
            reopenContinuation = stream.continuation
            continuations.append(stream.continuation)
        }

        if let timeZoneChanges {
            self.timeZoneChanges = timeZoneChanges
        } else {
            let stream = Self.makeStream()
            self.timeZoneChanges = stream.stream
            continuations.append(stream.continuation)
            timeZoneContinuation = stream.continuation
        }

        if let systemClockChanges {
            self.systemClockChanges = systemClockChanges
        } else {
            let stream = Self.makeStream()
            self.systemClockChanges = stream.stream
            continuations.append(stream.continuation)
            systemClockContinuation = stream.continuation
        }

        if let minuteContinuation {
            scheduleWallClockTimer(minuteContinuation, matching: DateComponents(second: 0))
        }
        if let midnightContinuation {
            scheduleWallClockTimer(
                midnightContinuation,
                matching: DateComponents(hour: 0, minute: 0, second: 0)
            )
            observe(
                NotificationCenter.default,
                name: .NSCalendarDayChanged,
                continuation: midnightContinuation
            )
        }
        if let hourContinuation {
            scheduleWallClockTimer(hourContinuation, matching: DateComponents(minute: 0, second: 0))
        }
        if let wakeContinuation {
            observe(
                wakeNotificationCenter,
                name: NSWorkspace.didWakeNotification,
                continuation: wakeContinuation
            )
        }
        if let activationContinuation {
            observe(
                NotificationCenter.default,
                name: NSApplication.didBecomeActiveNotification,
                continuation: activationContinuation
            )
        }
        let timeZoneToken = NotificationCenter.default.addObserver(
            forName: .NSSystemTimeZoneDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rescheduleWallClockTimers()
            timeZoneContinuation?.yield(())
        }
        observerTokens.append((NotificationCenter.default, timeZoneToken))
        let systemClockToken = NotificationCenter.default.addObserver(
            forName: .NSSystemClockDidChange,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.rescheduleWallClockTimers()
            systemClockContinuation?.yield(())
        }
        observerTokens.append((NotificationCenter.default, systemClockToken))
    }

    deinit {
        observerTokens.forEach { $0.center.removeObserver($0.token) }
        timers.forEach { $0.timer.cancel() }
        continuations.forEach { $0.finish() }
    }

    /// AppDelegate calls this when macOS asks the already-running app to reopen its UI.
    public func reopen() {
        reopenContinuation?.yield(())
    }

    private static func makeStream() -> (
        stream: AsyncStream<Void>,
        continuation: AsyncStream<Void>.Continuation
    ) {
        AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
    }

    private func observe(
        _ center: NotificationCenter,
        name: Notification.Name,
        continuation: AsyncStream<Void>.Continuation
    ) {
        let token = center.addObserver(forName: name, object: nil, queue: .main) { _ in
            continuation.yield(())
        }
        observerTokens.append((center, token))
    }

    private func scheduleWallClockTimer(
        _ continuation: AsyncStream<Void>.Continuation,
        matching components: DateComponents
    ) {
        let timer = DispatchSource.makeTimerSource(queue: .main)
        timer.setEventHandler { [weak self] in
            continuation.yield(())
            self?.scheduleNextWallClockBoundary(timer, matching: components)
        }
        timers.append((timer, components))
        scheduleNextWallClockBoundary(timer, matching: components)
        timer.resume()
    }

    private func scheduleNextWallClockBoundary(
        _ timer: DispatchSourceTimer,
        matching components: DateComponents
    ) {
        let current = now()
        let next = calendar.nextDate(
            after: current,
            matching: components,
            matchingPolicy: .nextTime
        ) ?? current.addingTimeInterval(60)
        scheduleTimer(timer, max(next.timeIntervalSince(current), 0.001))
    }

    private func rescheduleWallClockTimers() {
        for (timer, components) in timers {
            scheduleNextWallClockBoundary(timer, matching: components)
        }
    }
}
