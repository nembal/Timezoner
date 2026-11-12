import Foundation

public struct CalendarTimedSegment: Identifiable, Equatable, Sendable {
    public let id: String
    public let occurrenceID: String
    public let event: CalendarEventSnapshot
    public let dayStart: Date
    public let startDate: Date
    public let endDate: Date
    public var laneIndex: Int
    public var laneCount: Int
    /// Stable identity for a contiguous set of mutually-overlapping segments on one day.
    public var overlapGroupID: String?

    public init(
        id: String,
        occurrenceID: String,
        event: CalendarEventSnapshot,
        dayStart: Date,
        startDate: Date,
        endDate: Date,
        laneIndex: Int = 0,
        laneCount: Int = 1,
        overlapGroupID: String? = nil
    ) {
        self.id = id
        self.occurrenceID = occurrenceID
        self.event = event
        self.dayStart = dayStart
        self.startDate = startDate
        self.endDate = endDate
        self.laneIndex = laneIndex
        self.laneCount = laneCount
        self.overlapGroupID = overlapGroupID
    }
}

public struct CalendarAllDaySpan: Identifiable, Equatable, Sendable {
    public let id: String
    public let occurrenceID: String
    public let event: CalendarEventSnapshot
    public let startDay: Date
    public let endDay: Date
    public let dayCount: Int

    public init(
        id: String,
        occurrenceID: String,
        event: CalendarEventSnapshot,
        startDay: Date,
        endDay: Date,
        dayCount: Int
    ) {
        self.id = id
        self.occurrenceID = occurrenceID
        self.event = event
        self.startDay = startDay
        self.endDay = endDay
        self.dayCount = dayCount
    }
}

public enum CalendarLayoutEngine {
    public static func timedSegments(
        events: [CalendarEventSnapshot],
        interval: DateInterval,
        calendar: Calendar
    ) -> [CalendarTimedSegment] {
        let segments = events
            .filter { !$0.isAllDay }
            .flatMap { segments(for: $0, in: interval, calendar: calendar) }
            .sorted(by: timedSegmentSort)

        return assigningLanes(to: segments)
    }

    public static func allDaySpans(
        events: [CalendarEventSnapshot],
        interval: DateInterval,
        calendar: Calendar
    ) -> [CalendarAllDaySpan] {
        events
            .filter(\.isAllDay)
            .compactMap { span(for: $0, in: interval, calendar: calendar) }
            .sorted { lhs, rhs in
                if lhs.startDay != rhs.startDay { return lhs.startDay < rhs.startDay }
                if lhs.endDay != rhs.endDay { return lhs.endDay < rhs.endDay }
                return lhs.occurrenceID < rhs.occurrenceID
            }
    }

    private static func segments(
        for event: CalendarEventSnapshot,
        in interval: DateInterval,
        calendar: Calendar
    ) -> [CalendarTimedSegment] {
        let visibleStart = max(event.startDate, interval.start)
        let visibleEnd = min(event.endDate, interval.end)
        guard visibleStart < visibleEnd else { return [] }

        var segments: [CalendarTimedSegment] = []
        var dayStart = calendar.startOfDay(for: visibleStart)

        while dayStart < visibleEnd {
            guard let nextDayStart = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
                break
            }

            let segmentStart = max(visibleStart, dayStart)
            let segmentEnd = min(visibleEnd, nextDayStart)
            if segmentStart < segmentEnd {
                segments.append(CalendarTimedSegment(
                    id: "\(event.id)|\(dayStart.timeIntervalSince1970)",
                    occurrenceID: event.id,
                    event: event,
                    dayStart: dayStart,
                    startDate: segmentStart,
                    endDate: segmentEnd
                ))
            }

            dayStart = nextDayStart
        }

        return segments
    }

    private static func span(
        for event: CalendarEventSnapshot,
        in interval: DateInterval,
        calendar: Calendar
    ) -> CalendarAllDaySpan? {
        let visibleStart = max(event.startDate, interval.start)
        let visibleEnd = min(event.endDate, interval.end)
        guard visibleStart < visibleEnd else { return nil }

        let startDay = calendar.startOfDay(for: visibleStart)
        let endDayStart = calendar.startOfDay(for: visibleEnd)
        let endDay: Date
        if endDayStart == visibleEnd {
            endDay = endDayStart
        } else {
            endDay = calendar.date(byAdding: .day, value: 1, to: endDayStart)!
        }

        let dayCount = calendar.dateComponents([.day], from: startDay, to: endDay).day!
        guard dayCount > 0 else { return nil }

        return CalendarAllDaySpan(
            id: event.id,
            occurrenceID: event.id,
            event: event,
            startDay: startDay,
            endDay: endDay,
            dayCount: dayCount
        )
    }

    private static func timedSegmentSort(_ lhs: CalendarTimedSegment, _ rhs: CalendarTimedSegment) -> Bool {
        if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
        if lhs.endDate != rhs.endDate { return lhs.endDate < rhs.endDate }
        return lhs.occurrenceID < rhs.occurrenceID
    }

    private static func assigningLanes(to segments: [CalendarTimedSegment]) -> [CalendarTimedSegment] {
        var laidOut = segments
        var laneEnds: [Date] = []
        var groupIndices: [Int] = []
        var groupLaneCount = 0

        func finalizeCurrentGroup() {
            let overlapGroupID = groupIndices.first.map { laidOut[$0].id }
            for index in groupIndices {
                laidOut[index].laneCount = groupLaneCount
                laidOut[index].overlapGroupID = overlapGroupID
            }
        }

        for index in laidOut.indices {
            let segment = laidOut[index]
            let hasActiveSegment = laneEnds.contains { $0 > segment.startDate }

            if !hasActiveSegment && !groupIndices.isEmpty {
                finalizeCurrentGroup()
                laneEnds.removeAll()
                groupIndices.removeAll()
                groupLaneCount = 0
            }

            let laneIndex = laneEnds.firstIndex { $0 <= segment.startDate } ?? laneEnds.count
            if laneIndex == laneEnds.count {
                laneEnds.append(segment.endDate)
            } else {
                laneEnds[laneIndex] = segment.endDate
            }

            laidOut[index].laneIndex = laneIndex
            groupIndices.append(index)
            groupLaneCount = max(groupLaneCount, laneEnds.count)
        }

        if !groupIndices.isEmpty {
            finalizeCurrentGroup()
        }

        return laidOut
    }
}
