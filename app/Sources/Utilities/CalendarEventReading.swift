import Foundation

public protocol CalendarEventReading: AnyObject {
    var authorizationStatus: CalendarAuthorizationStatus { get }
    func requestAccess() async throws -> Bool
    func calendars() async throws -> [CalendarDescriptor]
    func events(from start: Date, to end: Date, calendarIDs: Set<String>) async throws -> [CalendarEventSnapshot]
    var changes: AsyncStream<Void> { get }
}
