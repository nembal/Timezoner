import Foundation

public struct TimeFormatter {
    /// "11:30 AM" -- for zone cards
    public static func formatTime(_ date: Date, in zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "AM"
        formatter.pmSymbol = "PM"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// "11:30" -- for editable text field (24h format)
    public static func formatTimeEditable(_ date: Date, in zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "HH:mm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// "Mon, Mar 24" -- for date display
    public static func formatDate(_ date: Date, in zone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = zone
        formatter.dateFormat = "EEE, MMM d"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date)
    }

    /// "+7h" or "-14h" -- relative offset from one zone to another
    public static func relativeOffset(from: TimeZone, to: TimeZone, at date: Date) -> String {
        let fromSeconds = from.secondsFromGMT(for: date)
        let toSeconds = to.secondsFromGMT(for: date)
        let diffSeconds = toSeconds - fromSeconds
        let diffHours = Double(diffSeconds) / 3600.0

        // Check if this is a whole-hour offset
        if diffHours == diffHours.rounded(.towardZero) && diffHours.truncatingRemainder(dividingBy: 1) == 0 {
            let intHours = Int(diffHours)
            if intHours >= 0 {
                return "+\(intHours)h"
            } else {
                return "\(intHours)h"
            }
        } else {
            // Half-hour (or other fractional) offset
            if diffHours >= 0 {
                return "+\(formatFractionalHours(diffHours))h"
            } else {
                return "-\(formatFractionalHours(abs(diffHours)))h"
            }
        }
    }

    private static func formatFractionalHours(_ hours: Double) -> String {
        // Remove trailing zeros but keep necessary decimal places
        let formatted = String(format: "%.1f", hours)
        // Remove trailing zero after decimal if it's .0
        if formatted.hasSuffix(".0") {
            return String(formatted.dropLast(2))
        }
        return formatted
    }
}
