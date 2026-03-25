import Foundation

@Observable
public class TimeState {
    public var referenceDate: Date = Date()
    public var sourceZoneId: String = TimeZone.current.identifier
    public var isLive: Bool = true

    private var timer: Timer?

    public init() {
        startTimer()
    }

    deinit {
        timer?.invalidate()
    }

    public func setTime(hour: Int, minute: Int, in zone: TimeZone) {
        var calendar = Calendar.current
        calendar.timeZone = zone
        let components = calendar.dateComponents([.year, .month, .day], from: referenceDate)
        var newComponents = DateComponents()
        newComponents.year = components.year
        newComponents.month = components.month
        newComponents.day = components.day
        newComponents.hour = hour
        newComponents.minute = minute
        if let newDate = calendar.date(from: newComponents) {
            referenceDate = newDate
            sourceZoneId = zone.identifier
            isLive = false
        }
    }

    public func goLive() {
        referenceDate = Date()
        isLive = true
    }

    private func startTimer() {
        // Fire at the next minute boundary, then every 60s
        let now = Date()
        let calendar = Calendar.current
        let seconds = calendar.component(.second, from: now)
        let delay = Double(60 - seconds)

        timer = Timer.scheduledTimer(withTimeInterval: delay, repeats: false) { [weak self] _ in
            guard let self = self else { return }
            self.tick()
            self.timer = Timer.scheduledTimer(withTimeInterval: 60, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }
    }

    private func tick() {
        if isLive {
            referenceDate = Date()
        }
    }
}
