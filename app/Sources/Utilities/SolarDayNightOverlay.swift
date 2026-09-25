import Foundation

public struct SolarSubsolarPoint: Equatable, Sendable {
    public let longitude: Double
    public let latitude: Double
}

public struct SolarLongitudeSpan: Equatable, Sendable {
    public let minimum: Double
    public let maximum: Double

    public init(minimum: Double, maximum: Double) {
        self.minimum = minimum
        self.maximum = maximum
    }
}

public struct SolarNightBand: Equatable, Sendable {
    public let minimumLatitude: Double
    public let maximumLatitude: Double
    public let spans: [SolarLongitudeSpan]
}

public enum SolarDayNightOverlay {
    public static func subsolarPoint(at date: Date) -> SolarSubsolarPoint {
        let julian = date.timeIntervalSince1970 / 86_400 + 2_440_587.5
        let days = julian - 2_451_545.0
        let meanLongitude = normalized360(280.460 + 0.9856474 * days)
        let anomaly = radians(normalized360(357.528 + 0.9856003 * days))
        let ecliptic = radians(meanLongitude + 1.915 * sin(anomaly) + 0.020 * sin(2 * anomaly))
        let obliquity = radians(23.439 - 0.0000004 * days)
        let declination = asin(sin(obliquity) * sin(ecliptic))
        let rightAscension = atan2(cos(obliquity) * sin(ecliptic), cos(ecliptic)) * 180 / .pi
        let sidereal = normalized360(280.46061837 + 360.98564736629 * days)
        return SolarSubsolarPoint(
            longitude: normalized180(rightAscension - sidereal),
            latitude: declination * 180 / .pi
        )
    }

    public static func isNight(longitude: Double, latitude: Double, at date: Date) -> Bool {
        let sun = subsolarPoint(at: date)
        return isNight(longitude: longitude, latitude: latitude, sun: sun)
    }

    private static func isNight(longitude: Double,
                                latitude: Double,
                                sun: SolarSubsolarPoint) -> Bool {
        let lat = radians(latitude)
        let declination = radians(sun.latitude)
        let hourAngle = radians(longitude - sun.longitude)
        let altitudeSine = sin(lat) * sin(declination)
            + cos(lat) * cos(declination) * cos(hourAngle)
        return altitudeSine < 0
    }

    public static func nightBands(at date: Date,
                                  latitudeRange: ClosedRange<Double> = -70...70,
                                  bandCount: Int = 70) -> [SolarNightBand] {
        precondition(bandCount > 0)
        let sun = subsolarPoint(at: date)
        let latitudeStep = (latitudeRange.upperBound - latitudeRange.lowerBound)
            / Double(bandCount)
        return (0..<bandCount).map { index in
            let minimum = latitudeRange.lowerBound + Double(index) * latitudeStep
            let maximum = minimum + latitudeStep
            let center = (minimum + maximum) / 2
            var spans: [SolarLongitudeSpan] = []
            var start: Double?
            for longitude in stride(from: -180.0, through: 180.0, by: 1.0) {
                if isNight(longitude: longitude, latitude: center, sun: sun) {
                    start = start ?? longitude
                } else if let current = start {
                    spans.append(SolarLongitudeSpan(minimum: current, maximum: longitude))
                    start = nil
                }
            }
            if let current = start {
                spans.append(SolarLongitudeSpan(minimum: current, maximum: 180))
            }
            return SolarNightBand(minimumLatitude: minimum,
                                  maximumLatitude: maximum,
                                  spans: spans)
        }
    }

    private static func radians(_ degrees: Double) -> Double { degrees * .pi / 180 }

    private static func normalized360(_ degrees: Double) -> Double {
        let value = degrees.truncatingRemainder(dividingBy: 360)
        return value < 0 ? value + 360 : value
    }

    private static func normalized180(_ degrees: Double) -> Double {
        let value = normalized360(degrees + 180) - 180
        return value == -180 && degrees > 0 ? 180 : value
    }
}
