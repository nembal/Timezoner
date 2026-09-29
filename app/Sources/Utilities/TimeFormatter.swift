import Foundation

public struct TimeFormatter {

    // MARK: - Cached DateFormatters

    private static let cache = FormatterCache()

    private class FormatterCache {
        private var formatters: [String: DateFormatter] = [:]
        private let lock = NSLock()

        /// Format a date inside the lock — DateFormatter is not thread-safe
        func format(date: Date, format: String, zone: TimeZone, amSymbol: String? = nil, pmSymbol: String? = nil) -> String {
            let key = "\(format)|\(zone.identifier)|\(amSymbol ?? "")|\(pmSymbol ?? "")"
            lock.lock()
            defer { lock.unlock() }

            let f: DateFormatter
            if let cached = formatters[key] {
                f = cached
            } else {
                f = DateFormatter()
                f.timeZone = zone
                f.dateFormat = format
                f.locale = Locale(identifier: "en_US_POSIX")
                if let am = amSymbol { f.amSymbol = am }
                if let pm = pmSymbol { f.pmSymbol = pm }
                formatters[key] = f
            }
            return f.string(from: date)
        }
    }

    // MARK: - Public API

    /// "11:30 am" -- full time with am/pm
    public static func formatTime(_ date: Date, in zone: TimeZone) -> String {
        cache.format(date: date, format: "h:mm a", zone: zone, amSymbol: "am", pmSymbol: "pm")
    }

    /// "11:30" -- just the time digits without am/pm
    public static func formatTimeDigits(_ date: Date, in zone: TimeZone) -> String {
        cache.format(date: date, format: "h:mm", zone: zone)
    }

    /// "am" or "pm"
    public static func formatAmPm(_ date: Date, in zone: TimeZone) -> String {
        cache.format(date: date, format: "a", zone: zone, amSymbol: "am", pmSymbol: "pm")
    }

    /// "GMT+7" or "GMT-8" -- timezone offset label
    public static func gmtOffset(for zone: TimeZone, at date: Date) -> String {
        let totalMinutes = zone.secondsFromGMT(for: date) / 60
        let absoluteMinutes = abs(totalMinutes)
        let sign = totalMinutes < 0 ? "-" : "+"
        let hours = absoluteMinutes / 60
        let minutes = absoluteMinutes % 60
        return minutes == 0
            ? "GMT\(sign)\(hours)"
            : String(format: "GMT%@%d:%02d", sign, hours, minutes)
    }

    /// "11:30" -- for editable text field (24h format)
    public static func formatTimeEditable(_ date: Date, in zone: TimeZone) -> String {
        cache.format(date: date, format: "HH:mm", zone: zone)
    }

    /// "Mon, Mar 24" -- for date display
    public static func formatDate(_ date: Date, in zone: TimeZone) -> String {
        cache.format(date: date, format: "EEE, MMM d", zone: zone)
    }

    /// "+7h" or "-14h" -- relative offset from one zone to another
    public static func relativeOffset(from: TimeZone, to: TimeZone, at date: Date) -> String {
        let fromSeconds = from.secondsFromGMT(for: date)
        let toSeconds = to.secondsFromGMT(for: date)
        let diffMinutes = (toSeconds - fromSeconds) / 60
        let absoluteMinutes = abs(diffMinutes)
        let sign = diffMinutes < 0 ? "-" : "+"

        if absoluteMinutes % 60 == 0 {
            return "\(sign)\(absoluteMinutes / 60)h"
        }
        if absoluteMinutes % 15 == 0 {
            return "\(sign)\(formatFractionalHours(absoluteMinutes))h"
        } else {
            return "\(sign)\(absoluteMinutes / 60)h\(absoluteMinutes % 60)m"
        }
    }

    private static func formatFractionalHours(_ minutes: Int) -> String {
        let formatted = String(format: "%.2f", Double(minutes) / 60.0)
        return formatted.hasSuffix("0") ? String(formatted.dropLast()) : formatted
    }
}
