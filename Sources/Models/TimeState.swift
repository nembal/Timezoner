import Foundation

@Observable
public class TimeState {
    public var referenceDate: Date = Date()
    public var sourceZoneId: String = TimeZone.current.identifier

    public init() {}

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
        }
    }
}
