import Foundation

public enum ZoneVisualState: Equatable {
    case defaultLand
    case userBand
    case userZone
    case highlightBand
    case highlighted
}

public struct MapColorLogic {
    /// Determine visual state using a pre-computed offset lookup (avoids TimeZone allocation per call)
    public static func visualState(
        for featureTzid: String,
        userZoneIds: Set<String>,
        highlightedZoneIds: Set<String>,
        highlightedOffsetSeconds: Set<Int>,
        userOffsetSeconds: Set<Int>,
        offsetLookup: [String: Int]
    ) -> ZoneVisualState {
        if highlightedZoneIds.contains(featureTzid) { return .highlighted }

        if let featureOffset = offsetLookup[featureTzid] {
            if !highlightedOffsetSeconds.isEmpty && highlightedOffsetSeconds.contains(featureOffset) {
                return .highlightBand
            }

            if userZoneIds.contains(featureTzid) { return .userZone }

            if !userOffsetSeconds.isEmpty && userOffsetSeconds.contains(featureOffset) {
                return .userBand
            }
        } else {
            if userZoneIds.contains(featureTzid) { return .userZone }
        }

        return .defaultLand
    }

    public static func offsetSeconds(for ianaIds: Set<String>, at date: Date) -> Set<Int> {
        Set(ianaIds.compactMap { TimeZone(identifier: $0)?.secondsFromGMT(for: date) })
    }

    /// Build a tzid→offsetSeconds lookup for all features (called once per render, not per feature)
    public static func buildOffsetLookup(for features: [GeoJSONFeature], at date: Date) -> [String: Int] {
        var lookup: [String: Int] = [:]
        lookup.reserveCapacity(features.count)
        for feature in features {
            let tzid = feature.properties.tzid
            if let tz = TimeZone(identifier: tzid) {
                lookup[tzid] = tz.secondsFromGMT(for: date)
            }
        }
        return lookup
    }

    public static func utcOffsetHour(for ianaId: String, at date: Date) -> Int {
        guard let tz = TimeZone(identifier: ianaId) else { return 0 }
        let seconds = tz.secondsFromGMT(for: date)
        // Use floor division for correct negative half-hour handling
        // e.g. UTC-3:30 → -12600s → floor(-3.5) = -4, not -3
        return Int(floor(Double(seconds) / 3600.0))
    }
}
