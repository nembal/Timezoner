import Foundation

public struct CalendarWorkspaceMotion: Equatable, Sendable {
    public let fadeOut: TimeInterval
    public let move: TimeInterval
    public let fadeIn: TimeInterval
    public let travel: CGFloat

    public init(reduceMotion: Bool) {
        fadeOut = reduceMotion ? 0.05 : 0.06
        move = reduceMotion ? 0 : 0.22
        fadeIn = reduceMotion ? 0.05 : 0.06
        travel = reduceMotion ? 0 : 4
    }
}

public struct CalendarWorkspaceTransitionGate {
    public struct Request: Equatable, Sendable {
        public let id: UInt64
        public let destination: CalendarDestination
    }

    public private(set) var active: Request?
    private var queued: CalendarDestination?
    private var serial: UInt64 = 0

    public init() {}

    public mutating func begin(to destination: CalendarDestination) -> Request? {
        guard active == nil else {
            queued = destination
            return nil
        }

        serial &+= 1
        let request = Request(id: serial, destination: destination)
        active = request
        return request
    }

    public func isCurrent(_ id: UInt64) -> Bool {
        active?.id == id
    }

    public mutating func finish(_ id: UInt64) -> CalendarDestination? {
        guard let completed = active, completed.id == id else { return nil }
        let next = queued
        active = nil
        queued = nil
        return next == completed.destination ? nil : next
    }

    public mutating func cancel() -> CalendarDestination? {
        let destination = queued ?? active?.destination
        serial &+= 1
        active = nil
        queued = nil
        return destination
    }
}
