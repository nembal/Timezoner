import Foundation

// MARK: - Parse Result

public enum ParseResult {
    case timeConversion(hour: Int, minute: Int, zone: TimeZone)
    case addZone(label: String, zone: TimeZone)
    case removeZone(label: String)
}

// MARK: - Input Parser

public struct InputParser {

    /// Parses free-form user input into a structured ParseResult.
    ///
    /// Supports:
    /// - Add commands: `+Tokyo`, `add HK`, `add hong kong`
    /// - Remove commands: `-SF`, `remove NYC`, `remove new york`
    /// - Special words: `noon NYC`, `midnight CET`
    /// - Time formats: `11:30am PT`, `1130 am PT`, `15:00 BKK`, `3pm bangkok`, etc.
    public static func parse(_ input: String) -> ParseResult? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return nil }

        // 1. Check add/remove commands first
        if let result = parseCommand(trimmed) {
            return result
        }

        // 2. Normalize for time parsing
        let normalized = trimmed.lowercased().trimmingCharacters(in: .whitespaces)

        // 3. Handle special words
        if let result = parseSpecialWord(normalized) {
            return result
        }

        // 4. Parse time expression
        if let result = parseTime(normalized) {
            return result
        }

        return nil
    }

    // MARK: - Command Parsing

    private static func parseCommand(_ input: String) -> ParseResult? {
        let trimmed = input.trimmingCharacters(in: .whitespaces)

        // +Zone syntax
        if trimmed.hasPrefix("+") {
            let label = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty else { return nil }
            if let zone = resolveTimezone(label) {
                return .addZone(label: label, zone: zone)
            }
            return nil
        }

        // -Zone syntax
        if trimmed.hasPrefix("-") {
            let label = String(trimmed.dropFirst()).trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty else { return nil }
            return .removeZone(label: label)
        }

        // "add ..." syntax (case-insensitive)
        let lower = trimmed.lowercased()
        if lower.hasPrefix("add ") {
            let label = String(trimmed.dropFirst(4)).trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty else { return nil }
            if let zone = resolveTimezone(label) {
                return .addZone(label: label, zone: zone)
            }
            return nil
        }

        // "remove ..." syntax (case-insensitive)
        if lower.hasPrefix("remove ") {
            let label = String(trimmed.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            guard !label.isEmpty else { return nil }
            return .removeZone(label: label)
        }

        return nil
    }

    // MARK: - Special Word Parsing

    private static func parseSpecialWord(_ normalized: String) -> ParseResult? {
        // "noon <zone>" or "midnight <zone>"
        let parts = normalized.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard parts.count == 2 else { return nil }

        let word = String(parts[0])
        let zoneStr = String(parts[1]).trimmingCharacters(in: .whitespaces)

        let hour: Int
        switch word {
        case "noon":
            hour = 12
        case "midnight":
            hour = 0
        default:
            return nil
        }

        guard let zone = resolveTimezone(zoneStr) else { return nil }
        return .timeConversion(hour: hour, minute: 0, zone: zone)
    }

    // MARK: - Time Parsing

    private static func parseTime(_ normalized: String) -> ParseResult? {
        // Strategy: use a regex to extract time components, then the remainder is the zone.
        //
        // Patterns to match (all case-insensitive, input already lowercased):
        //   HH:MM am/pm ZONE   — "11:30am pt", "11:30 am pt", "11:30 a.m. nyc"
        //   HHMM am/pm ZONE    — "1130am pt", "1130 am pt"
        //   H am/pm ZONE       — "3pm bangkok", "3 p sf"
        //   HH:MM ZONE         — "15:00 bkk" (24h)
        //   HHMM ZONE          — "1500 bkk" (24h, 4 digits)
        //
        // AM/PM indicators: am, a.m., a, pm, p.m., p

        // The regex approach:
        // Group 1: hour (1-2 digits)
        // Group 2: optional separator (:) + minute (2 digits)  OR  minute stuck to hour (2 digits when no colon)
        // Group 3: optional am/pm indicator
        // Group 4: zone string (rest)

        // We'll try several patterns in order.

        // Pattern A: HH:MM with optional am/pm
        // (\d{1,2}):(\d{2})\s*(am|a\.m\.|a|pm|p\.m\.|p)?\s+(.+)
        let patternA = #"^(\d{1,2}):(\d{2})\s*(a\.m\.|p\.m\.|am|pm|a|p)?\s+(.+)$"#

        // Pattern B: HHMM (4 digits) with optional am/pm
        // (\d{2})(\d{2})\s*(am|a\.m\.|a|pm|p\.m\.|p)?\s+(.+)
        let patternB = #"^(\d{2})(\d{2})\s*(a\.m\.|p\.m\.|am|pm|a|p)?\s+(.+)$"#

        // Pattern C: H or HH with am/pm (no minutes) — "3pm bangkok", "3 p sf"
        // (\d{1,2})\s*(am|a\.m\.|a|pm|p\.m\.|p)\s+(.+)
        let patternC = #"^(\d{1,2})\s*(a\.m\.|p\.m\.|am|pm|a|p)\s+(.+)$"#

        // Try Pattern A first
        if let match = try? regexMatch(normalized, pattern: patternA) {
            let hourStr = match[1]
            let minStr = match[2]
            let ampmStr = match[3]
            let zoneStr = match[4]

            guard let hour = Int(hourStr), let minute = Int(minStr) else { return nil }
            let finalHour = adjustHourForAmPm(hour: hour, ampm: ampmStr)
            guard finalHour >= 0 && finalHour <= 23 && minute >= 0 && minute <= 59 else { return nil }
            guard let zone = resolveTimezone(zoneStr.trimmingCharacters(in: .whitespaces)) else { return nil }
            return .timeConversion(hour: finalHour, minute: minute, zone: zone)
        }

        // Try Pattern B (4-digit HHMM)
        if let match = try? regexMatch(normalized, pattern: patternB) {
            let hourStr = match[1]
            let minStr = match[2]
            let ampmStr = match[3]
            let zoneStr = match[4]

            guard let hour = Int(hourStr), let minute = Int(minStr) else { return nil }
            let finalHour = adjustHourForAmPm(hour: hour, ampm: ampmStr)
            guard finalHour >= 0 && finalHour <= 23 && minute >= 0 && minute <= 59 else { return nil }
            guard let zone = resolveTimezone(zoneStr.trimmingCharacters(in: .whitespaces)) else { return nil }
            return .timeConversion(hour: finalHour, minute: minute, zone: zone)
        }

        // Try Pattern C (hour + am/pm, no minutes)
        if let match = try? regexMatch(normalized, pattern: patternC) {
            let hourStr = match[1]
            let ampmStr = match[2]
            let zoneStr = match[3]

            guard let hour = Int(hourStr) else { return nil }
            let finalHour = adjustHourForAmPm(hour: hour, ampm: ampmStr)
            guard finalHour >= 0 && finalHour <= 23 else { return nil }
            guard let zone = resolveTimezone(zoneStr.trimmingCharacters(in: .whitespaces)) else { return nil }
            return .timeConversion(hour: finalHour, minute: 0, zone: zone)
        }

        return nil
    }

    // MARK: - AM/PM Adjustment

    private static func adjustHourForAmPm(hour: Int, ampm: String?) -> Int {
        guard let indicator = ampm, !indicator.isEmpty else { return hour }

        let isPm = indicator.hasPrefix("p")
        let isAm = indicator.hasPrefix("a")

        if isPm && hour < 12 {
            return hour + 12
        }
        if isAm && hour == 12 {
            return 0
        }
        return hour
    }

    // MARK: - Regex Helper

    /// Returns an array of captured groups (index 0 = full match, 1..N = capture groups).
    /// Empty string for groups that didn't participate.
    private static func regexMatch(_ input: String, pattern: String) throws -> [String] {
        let regex = try NSRegularExpression(pattern: pattern, options: [.caseInsensitive])
        let range = NSRange(input.startIndex..., in: input)
        guard let match = regex.firstMatch(in: input, options: [], range: range) else {
            throw NSError(domain: "InputParser", code: 0, userInfo: nil)
        }

        var groups: [String] = []
        for i in 0..<match.numberOfRanges {
            let nsRange = match.range(at: i)
            if nsRange.location == NSNotFound {
                groups.append("")
            } else if let swiftRange = Range(nsRange, in: input) {
                groups.append(String(input[swiftRange]))
            } else {
                groups.append("")
            }
        }
        return groups
    }
}
