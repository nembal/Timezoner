import AppKit
import Foundation
import TimeZonerLib

private final class CalendarClockNotificationCenterProbe: NotificationCenter, @unchecked Sendable {
    private(set) var removedCount = 0

    override func removeObserver(_ observer: Any) {
        removedCount += 1
        super.removeObserver(observer)
    }
}

private final class CalendarClockTestSignals {
    let minuteTicks: AsyncStream<Void>
    let midnightTicks: AsyncStream<Void>
    let hourTicks: AsyncStream<Void>
    let wakeEvents: AsyncStream<Void>
    let activationEvents: AsyncStream<Void>
    let reopenEvents: AsyncStream<Void>
    let timeZoneChanges: AsyncStream<Void>

    private let minuteContinuation: AsyncStream<Void>.Continuation
    private let midnightContinuation: AsyncStream<Void>.Continuation
    private let hourContinuation: AsyncStream<Void>.Continuation
    private let wakeContinuation: AsyncStream<Void>.Continuation
    private let activationContinuation: AsyncStream<Void>.Continuation
    private let reopenContinuation: AsyncStream<Void>.Continuation
    private let timeZoneContinuation: AsyncStream<Void>.Continuation

    init() {
        let minute = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        minuteTicks = minute.stream
        minuteContinuation = minute.continuation
        let midnight = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        midnightTicks = midnight.stream
        midnightContinuation = midnight.continuation
        let hour = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        hourTicks = hour.stream
        hourContinuation = hour.continuation
        let wake = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        wakeEvents = wake.stream
        wakeContinuation = wake.continuation
        let activation = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        activationEvents = activation.stream
        activationContinuation = activation.continuation
        let reopen = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        reopenEvents = reopen.stream
        reopenContinuation = reopen.continuation
        let timeZone = AsyncStream<Void>.makeStream(bufferingPolicy: .bufferingNewest(1))
        timeZoneChanges = timeZone.stream
        timeZoneContinuation = timeZone.continuation
    }

    deinit {
        [
            minuteContinuation,
            midnightContinuation,
            hourContinuation,
            wakeContinuation,
            activationContinuation,
            reopenContinuation,
            timeZoneContinuation,
        ].forEach { $0.finish() }
    }

    func emitMinute() { minuteContinuation.yield(()) }
    func emitMidnight() { midnightContinuation.yield(()) }
    func emitHour() { hourContinuation.yield(()) }
    func emitWake() { wakeContinuation.yield(()) }
    func emitActivation() { activationContinuation.yield(()) }
    func emitReopen() { reopenContinuation.yield(()) }
    func emitTimeZoneChange() { timeZoneContinuation.yield(()) }
}

private func expectCalendarClock<T: Equatable>(
    _ actual: T,
    _ expected: T,
    _ label: String,
    line: Int = #line
) {
    if actual == expected {
        testsPassed += 1
    } else {
        testsFailed += 1
        print("  FAIL [line \(line)] \(label): expected \(expected), got \(actual)")
    }
}

@MainActor
private func awaitCalendarClockEvent(
    _ stream: AsyncStream<Void>,
    emit: @escaping () -> Void
) async -> Bool {
    var received = false
    let waiter = Task {
        for await _ in stream {
            received = true
            return
        }
    }
    await Task.yield()
    emit()
    for _ in 0 ..< 200 {
        if received {
            waiter.cancel()
            return true
        }
        await Task.yield()
    }
    waiter.cancel()
    return received
}

func runCalendarClockTests() async {
    print("Running CalendarClockTests...")

    var boundaryNow = ISO8601DateFormatter().date(from: "2024-01-01T12:34:30Z")!
    var boundaryCalendar = Calendar(identifier: .gregorian)
    boundaryCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
    var scheduledDelays: [TimeInterval] = []
    let boundaryClock = CalendarClock(
        now: { boundaryNow },
        calendar: { boundaryCalendar },
        scheduleTimer: { _, delay in scheduledDelays.append(delay) }
    )
    expectCalendarClock(scheduledDelays, [30, 41_130, 1_530], "initial minute, midnight, and hour deadlines")

    scheduledDelays.removeAll()
    boundaryCalendar.timeZone = TimeZone(secondsFromGMT: 7 * 3_600)!
    NotificationCenter.default.post(name: .NSSystemTimeZoneDidChange, object: nil)
    expectCalendarClock(scheduledDelays, [30, 15_930, 1_530], "timezone changes recalculate every wall-clock deadline")

    scheduledDelays.removeAll()
    boundaryNow = ISO8601DateFormatter().date(from: "2024-01-01T12:50:40Z")!
    NotificationCenter.default.post(name: .NSSystemClockDidChange, object: nil)
    expectCalendarClock(scheduledDelays, [20, 14_960, 560], "system-clock changes recalculate every wall-clock deadline")
    withExtendedLifetime(boundaryClock) {}

    let fixedNow = Date(timeIntervalSince1970: 1_725_000_000)
    var utcCalendar = Calendar(identifier: .gregorian)
    utcCalendar.locale = Locale(identifier: "en_US_POSIX")
    utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!
    let signals = CalendarClockTestSignals()
    let clock = CalendarClock(
        now: { fixedNow },
        calendar: { utcCalendar },
        minuteTicks: signals.minuteTicks,
        midnightTicks: signals.midnightTicks,
        hourTicks: signals.hourTicks,
        wakeEvents: signals.wakeEvents,
        activationEvents: signals.activationEvents,
        reopenEvents: signals.reopenEvents,
        timeZoneChanges: signals.timeZoneChanges
    )

    expectCalendarClock(clock.now(), fixedNow, "the clock exposes the injected wall-clock now")
    expectCalendarClock(clock.calendar.timeZone, utcCalendar.timeZone, "the clock exposes the injected wall-clock calendar")
    expectCalendarClock(
        await awaitCalendarClockEvent(clock.minuteTicks, emit: signals.emitMinute),
        true,
        "the clock forwards injected minute-boundary ticks"
    )
    expectCalendarClock(
        await awaitCalendarClockEvent(clock.midnightTicks, emit: signals.emitMidnight),
        true,
        "the clock forwards injected midnight-boundary ticks"
    )
    expectCalendarClock(
        await awaitCalendarClockEvent(clock.hourTicks, emit: signals.emitHour),
        true,
        "the clock forwards injected hourly-boundary ticks"
    )
    expectCalendarClock(
        await awaitCalendarClockEvent(clock.wakeEvents, emit: signals.emitWake),
        true,
        "the clock forwards injected wake events"
    )
    expectCalendarClock(
        await awaitCalendarClockEvent(clock.activationEvents, emit: signals.emitActivation),
        true,
        "the clock forwards injected activation events"
    )
    expectCalendarClock(
        await awaitCalendarClockEvent(clock.reopenEvents, emit: signals.emitReopen),
        true,
        "the clock forwards injected reopen events"
    )
    expectCalendarClock(
        await awaitCalendarClockEvent(clock.timeZoneChanges, emit: signals.emitTimeZoneChange),
        true,
        "the clock forwards injected timezone-change events"
    )

    let productionDayChangeClock = CalendarClock(
        now: { fixedNow },
        calendar: { utcCalendar },
        minuteTicks: signals.minuteTicks,
        hourTicks: signals.hourTicks,
        wakeEvents: signals.wakeEvents,
        activationEvents: signals.activationEvents,
        reopenEvents: signals.reopenEvents,
        timeZoneChanges: signals.timeZoneChanges
    )
    expectCalendarClock(
        await awaitCalendarClockEvent(productionDayChangeClock.midnightTicks) {
            NotificationCenter.default.post(name: .NSCalendarDayChanged, object: nil)
        },
        true,
        "the production clock maps NSCalendarDayChanged to a range-rebuilding midnight tick"
    )

    let productionReopenClock = CalendarClock(
        now: { fixedNow },
        calendar: { utcCalendar },
        minuteTicks: signals.minuteTicks,
        midnightTicks: signals.midnightTicks,
        hourTicks: signals.hourTicks,
        wakeEvents: signals.wakeEvents,
        activationEvents: signals.activationEvents,
        timeZoneChanges: signals.timeZoneChanges
    )
    expectCalendarClock(
        await awaitCalendarClockEvent(productionReopenClock.reopenEvents, emit: productionReopenClock.reopen),
        true,
        "the production clock exposes an AppDelegate-driven reopen signal"
    )

    let wakeCenter = CalendarClockNotificationCenterProbe()
    var cleanupClock: CalendarClock? = CalendarClock(
        now: { fixedNow },
        calendar: { utcCalendar },
        minuteTicks: signals.minuteTicks,
        midnightTicks: signals.midnightTicks,
        hourTicks: signals.hourTicks,
        activationEvents: signals.activationEvents,
        reopenEvents: signals.reopenEvents,
        timeZoneChanges: signals.timeZoneChanges,
        wakeNotificationCenter: wakeCenter
    )
    expectCalendarClock(
        await awaitCalendarClockEvent(cleanupClock!.wakeEvents) {
            wakeCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        },
        true,
        "the clock receives wake notifications from its registered center"
    )
    cleanupClock = nil
    expectCalendarClock(
        wakeCenter.removedCount,
        1,
        "clock deinit removes wake observer through its registration center"
    )
}
