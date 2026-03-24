import Foundation

public struct TimeFormatter {

    // MARK: - Cached DateFormatters

    private static let cache = FormatterCache()

    private class FormatterCache {
        // Keyed by "format|timezoneId"
        private var formatters: [String: DateFormatter] = [:]
        private let lock = NSLock()

        func formatter(format: String, zone: TimeZone, amSymbol: String? = nil, pmSymbol: String? = nil) -> DateFormatter {
            let key = "\(format)|\(zone.identifier)|\(amSymbol ?? "")|\(pmSymbol ?? "")"
            lock.lock()
            defer { lock.unlock() }

            if let cached = formatters[key] {
                return cached
            }

            let f = DateFormatter()
            f.timeZone = zone
            f.dateFormat = format
            f.locale = Locale(identifier: "en_US_POSIX")
            if let am = amSymbol { f.amSymbol = am }
            if let pm = pmSymbol { f.pmSymbol = pm }
            formatters[key] = f
            return f
        }
    }

    // MARK: - Public API

    /// "11:30 am" -- full time with am/pm
    public static func formatTime(_ date: Date, in zone: TimeZone) -> String {
        cache.formatter(format: "h:mm a", zone: zone, amSymbol: "am", pmSymbol: "pm")
            .string(from: date)
    }

    /// "11:30" -- just the time digits without am/pm
    public static func formatTimeDigits(_ date: Date, in zone: TimeZone) -> String {
        cache.formatter(format: "h:mm", zone: zone)
            .string(from: date)
    }

    /// "am" or "pm"
    public static func formatAmPm(_ date: Date, in zone: TimeZone) -> String {
        cache.formatter(format: "a", zone: zone, amSymbol: "am", pmSymbol: "pm")
            .string(from: date)
    }

    /// "GMT+7" or "GMT-8" -- timezone offset label
    public static func gmtOffset(for zone: TimeZone, at date: Date) -> String {
        let seconds = zone.secondsFromGMT(for: date)
        let hours = Double(seconds) / 3600.0
        if hours == hours.rounded() {
            let h = Int(hours)
            return h >= 0 ? "GMT+\(h)" : "GMT\(h)"
        } else {
            return hours >= 0
                ? String(format: "GMT+%.1f", hours)
                : String(format: "GMT%.1f", hours)
        }
    }

    /// "11:30" -- for editable text field (24h format)
    public static func formatTimeEditable(_ date: Date, in zone: TimeZone) -> String {
        cache.formatter(format: "HH:mm", zone: zone)
            .string(from: date)
    }

    /// "Mon, Mar 24" -- for date display
    public static func formatDate(_ date: Date, in zone: TimeZone) -> String {
        cache.formatter(format: "EEE, MMM d", zone: zone)
            .string(from: date)
    }

    /// "+7h" or "-14h" -- relative offset from one zone to another
    public static func relativeOffset(from: TimeZone, to: TimeZone, at date: Date) -> String {
        let fromSeconds = from.secondsFromGMT(for: date)
        let toSeconds = to.secondsFromGMT(for: date)
        let diffSeconds = toSeconds - fromSeconds
        let diffHours = Double(diffSeconds) / 3600.0

        if diffHours.truncatingRemainder(dividingBy: 1) == 0 {
            let intHours = Int(diffHours)
            return intHours >= 0 ? "+\(intHours)h" : "\(intHours)h"
        } else {
            let formatted = formatFractionalHours(abs(diffHours))
            return diffHours >= 0 ? "+\(formatted)h" : "-\(formatted)h"
        }
    }

    private static func formatFractionalHours(_ hours: Double) -> String {
        let formatted = String(format: "%.1f", hours)
        if formatted.hasSuffix(".0") {
            return String(formatted.dropLast(2))
        }
        return formatted
    }
}
