import Foundation

public struct MapHourScaleLabel: Equatable, Sendable {
    public let xFraction: Double
    public let longitude: Double
    public let hour: Int
    public let text: String
}

public enum MapHourScale {
    public static func labels(at referenceDate: Date) -> [MapHourScaleLabel] {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let utcHour = calendar.component(.hour, from: referenceDate)
        return (-12...11).enumerated().map { index, offset in
            let hour = (utcHour + offset + 24) % 24
            return MapHourScaleLabel(
                xFraction: Double(index) / 24.0,
                longitude: -180.0 + Double(index) * 15.0,
                hour: hour,
                text: String(format: "%02d", hour)
            )
        }
    }
}
