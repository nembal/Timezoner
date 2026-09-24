import Foundation

/// VoiceOver labels for compact per-calendar controls. The visible UI keeps short control titles,
/// while each control identifies the precise calendar account it changes.
public enum CalendarAccessibilityLabels {
    public static func showCalendar(for descriptor: CalendarDescriptor) -> String {
        "Show \(identity(for: descriptor)) calendar"
    }

    public static func alertsCalendar(for descriptor: CalendarDescriptor) -> String {
        "Calendar alerts for \(identity(for: descriptor))"
    }

    private static func identity(for descriptor: CalendarDescriptor) -> String {
        let title = descriptor.title.trimmingCharacters(in: .whitespacesAndNewlines)
        let source = descriptor.sourceTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !source.isEmpty, source.caseInsensitiveCompare(title) != .orderedSame else {
            return title
        }
        return "\(title), \(source)"
    }
}
