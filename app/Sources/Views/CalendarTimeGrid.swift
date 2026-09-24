import Foundation
import SwiftUI

public struct CalendarGridTimedFrame: Equatable, Sendable {
    public let x: CGFloat
    public let y: CGFloat
    public let width: CGFloat
    public let height: CGFloat

    public init(x: CGFloat, y: CGFloat, width: CGFloat, height: CGFloat) {
        self.x = x
        self.y = y
        self.width = width
        self.height = height
    }
}

public struct CalendarGridAllDayPlacement: Equatable, Sendable {
    public let span: CalendarAllDaySpan
    public let row: Int

    public init(span: CalendarAllDaySpan, row: Int) {
        self.span = span
        self.row = row
    }
}

public struct CalendarGridCurrentTimePosition: Equatable, Sendable {
    public let dayIndex: Int
    public let y: CGFloat

    public init(dayIndex: Int, y: CGFloat) {
        self.dayIndex = dayIndex
        self.y = y
    }
}

/// A contiguous overlap group. Dense groups use one accessible summary control rather than
/// collapsing individual event buttons into unusable slivers.
public struct CalendarGridTimedGroup: Identifiable, Equatable, Sendable {
    public let id: String
    public let dayStart: Date
    public let segments: [CalendarTimedSegment]

    public init(id: String, dayStart: Date, segments: [CalendarTimedSegment]) {
        self.id = id
        self.dayStart = dayStart
        self.segments = segments
    }

    public var laneCount: Int {
        segments.map(\.laneCount).max() ?? 1
    }

    public var usesOverflowMenu: Bool {
        laneCount >= 4
    }

    public var startDate: Date {
        segments.map(\.startDate).min() ?? dayStart
    }

    public var endDate: Date {
        segments.map(\.endDate).max() ?? startDate
    }
}

/// Pure color policy for the calendar grid. SwiftUI receives this value with a ten-percent
/// fill opacity and a two-point leading stripe so calendar identity never depends on fill alone.
public enum CalendarGridColor {
    public static let fillOpacity = 0.10
    public static let leadingIndicatorWidth: CGFloat = 2
    public static let maximumSaturation = 0.55

    public static func displayColor(from color: CalendarColor) -> CalendarColor {
        let rgb = (color.red, color.green, color.blue)
        let maxComponent = max(rgb.0, rgb.1, rgb.2)
        let minComponent = min(rgb.0, rgb.1, rgb.2)
        let delta = maxComponent - minComponent
        let saturation = maxComponent == 0 ? 0 : delta / maxComponent
        let clampedSaturation = min(saturation, maximumSaturation)

        let hue: Double
        if delta == 0 {
            hue = 0
        } else if maxComponent == rgb.0 {
            hue = ((rgb.1 - rgb.2) / delta).truncatingRemainder(dividingBy: 6)
        } else if maxComponent == rgb.1 {
            hue = (rgb.2 - rgb.0) / delta + 2
        } else {
            hue = (rgb.0 - rgb.1) / delta + 4
        }

        let normalizedHue = (hue / 6).truncatingRemainder(dividingBy: 1)
        let h = normalizedHue < 0 ? normalizedHue + 1 : normalizedHue
        let chroma = maxComponent * clampedSaturation
        let secondary = chroma * (1 - abs((h * 6).truncatingRemainder(dividingBy: 2) - 1))
        let match: (Double, Double, Double)
        switch h * 6 {
        case 0 ..< 1: match = (chroma, secondary, 0)
        case 1 ..< 2: match = (secondary, chroma, 0)
        case 2 ..< 3: match = (0, chroma, secondary)
        case 3 ..< 4: match = (0, secondary, chroma)
        case 4 ..< 5: match = (secondary, 0, chroma)
        default: match = (chroma, 0, secondary)
        }
        let offset = maxComponent - chroma
        return CalendarColor(
            red: match.0 + offset,
            green: match.1 + offset,
            blue: match.2 + offset,
            alpha: color.alpha
        )
    }
}

/// Calendar-aware geometry helpers shared by the read-only grid and its tests.
/// Day iteration deliberately asks the injected Calendar for each next boundary so DST days
/// never rely on a fixed elapsed 24-hour duration.
public struct CalendarGridHorizontalFrame: Equatable, Sendable {
    public let x: CGFloat
    public let width: CGFloat

    public init(x: CGFloat, width: CGFloat) {
        self.x = x
        self.width = width
    }
}

/// The one horizontal coordinate system shared by every Calendar grid strip. Keeping the ruler
/// and day frames here prevents the header, all-day area, and timed scroll document from deriving
/// subtly different origins from their own container proposals.
public struct CalendarGridHorizontalLayout: Equatable, Sendable {
    public let totalWidth: CGFloat
    public let rulerWidth: CGFloat
    public let dayCount: Int
    public let dayWidth: CGFloat

    public init(
        totalWidth: CGFloat,
        dayCount: Int,
        rulerWidth: CGFloat = CalendarGridMetrics.timeRulerWidth
    ) {
        self.totalWidth = max(totalWidth, 0)
        self.rulerWidth = rulerWidth
        self.dayCount = max(dayCount, 0)
        self.dayWidth = dayCount > 0
            ? max((totalWidth - rulerWidth) / CGFloat(dayCount), 0)
            : 0
    }

    public func dayFrame(at index: Int) -> CalendarGridHorizontalFrame {
        CalendarGridHorizontalFrame(
            x: rulerWidth + CGFloat(index) * dayWidth,
            width: dayWidth
        )
    }

    public func daySpanFrame(startingAt index: Int, dayCount: Int) -> CalendarGridHorizontalFrame {
        let start = dayFrame(at: index)
        return CalendarGridHorizontalFrame(
            x: start.x,
            width: max(CGFloat(dayCount), 0) * dayWidth
        )
    }
}

public enum CalendarGridMetrics {
    public static let timeRulerWidth: CGFloat = 48
    public static let hourHeight: CGFloat = 52
    public static let horizontalInset: CGFloat = 4
    public static let laneGap: CGFloat = 2
    public static let minimumInteractiveEventWidth: CGFloat = 44
    public static let minimumInteractiveEventHeight: CGFloat = 22

    public static func overlapGroups(from segments: [CalendarTimedSegment]) -> [CalendarGridTimedGroup] {
        let grouped = Dictionary(grouping: segments) { segment in
            segment.overlapGroupID ?? segment.id
        }
        return grouped.map { id, segments in
            let ordered = segments.sorted { lhs, rhs in
                if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
                if lhs.endDate != rhs.endDate { return lhs.endDate < rhs.endDate }
                return lhs.occurrenceID < rhs.occurrenceID
            }
            return CalendarGridTimedGroup(id: id, dayStart: ordered.first?.dayStart ?? .distantPast, segments: ordered)
        }
        .sorted { lhs, rhs in
            if lhs.dayStart != rhs.dayStart { return lhs.dayStart < rhs.dayStart }
            if lhs.startDate != rhs.startDate { return lhs.startDate < rhs.startDate }
            return lhs.id < rhs.id
        }
    }

    /// Uses the full local-day column for a dense overlap menu, never a one-point lane.
    public static func overlapSummaryFrame(
        for group: CalendarGridTimedGroup,
        dayStarts: [Date],
        totalWidth: CGFloat,
        calendar: Calendar
    ) -> CalendarGridTimedFrame? {
        overlapSummaryFrame(
            for: group,
            dayStarts: dayStarts,
            horizontalLayout: CalendarGridHorizontalLayout(totalWidth: totalWidth, dayCount: dayStarts.count),
            calendar: calendar
        )
    }

    public static func overlapSummaryFrame(
        for group: CalendarGridTimedGroup,
        dayStarts: [Date],
        horizontalLayout: CalendarGridHorizontalLayout,
        calendar: Calendar
    ) -> CalendarGridTimedFrame? {
        guard let dayIndex = dayStarts.firstIndex(of: group.dayStart), !dayStarts.isEmpty else {
            return nil
        }
        let dayFrame = horizontalLayout.dayFrame(at: dayIndex)
        let x = dayFrame.x + horizontalInset
        let y = wallMinute(for: group.startDate, on: group.dayStart, calendar: calendar) / 60 * hourHeight
        let endY = wallMinute(
            for: group.endDate,
            on: group.dayStart,
            calendar: calendar,
            isEnd: true
        ) / 60 * hourHeight
        return CalendarGridTimedFrame(
            x: x,
            y: y,
            width: max(dayFrame.width - 2 * horizontalInset, minimumInteractiveEventWidth),
            height: max(endY - y, minimumInteractiveEventHeight)
        )
    }

    public static func dayStarts(in interval: DateInterval, calendar: Calendar) -> [Date] {
        var starts: [Date] = []
        var day = calendar.startOfDay(for: interval.start)

        while day < interval.end {
            starts.append(day)
            guard let nextDay = calendar.date(byAdding: .day, value: 1, to: day) else {
                break
            }
            day = nextDay
        }

        return starts
    }

    /// Formats the ruler's logical hour index using a fixed non-DST date. The rendered label
    /// therefore never normalizes a missing spring-forward time or duplicates a fall-back hour.
    public static func rulerHourLabel(for hour: Int, locale: Locale = .current) -> String {
        let logicalHour = ((hour % 24) + 24) % 24
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(
            calendar: calendar,
            timeZone: calendar.timeZone,
            year: 2001,
            month: 1,
            day: 1,
            hour: logicalHour
        ))!
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = locale
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h a"
        return formatter.string(from: date)
    }

    /// Uses local wall-clock components. Repeated fall-back 01:xx times intentionally overlay:
    /// keeping the spring-forward missing hour aligned with the ruler is the chosen trade-off.
    public static func wallMinute(
        for date: Date,
        on dayStart: Date,
        calendar: Calendar,
        isEnd: Bool = false
    ) -> CGFloat {
        if isEnd,
           let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart),
           date == nextDay {
            return 24 * 60
        }
        let components = calendar.dateComponents([.hour, .minute, .second], from: date)
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = components.second ?? 0
        return CGFloat(hour * 60 + minute) + CGFloat(second) / 60
    }

    public static func timedFrame(
        for segment: CalendarTimedSegment,
        dayStarts: [Date],
        totalWidth: CGFloat,
        calendar: Calendar
    ) -> CalendarGridTimedFrame? {
        timedFrame(
            for: segment,
            dayStarts: dayStarts,
            horizontalLayout: CalendarGridHorizontalLayout(totalWidth: totalWidth, dayCount: dayStarts.count),
            calendar: calendar
        )
    }

    public static func timedFrame(
        for segment: CalendarTimedSegment,
        dayStarts: [Date],
        horizontalLayout: CalendarGridHorizontalLayout,
        calendar: Calendar
    ) -> CalendarGridTimedFrame? {
        guard let dayIndex = dayStarts.firstIndex(of: segment.dayStart), !dayStarts.isEmpty else {
            return nil
        }

        let dayFrame = horizontalLayout.dayFrame(at: dayIndex)
        let usableWidth = max(dayFrame.width - 2 * horizontalInset, 0)
        let laneCount = max(segment.laneCount, 1)
        let laneWidth = usableWidth / CGFloat(laneCount)
        let x = dayFrame.x
            + horizontalInset
            + CGFloat(segment.laneIndex) * laneWidth
        let y = wallMinute(for: segment.startDate, on: segment.dayStart, calendar: calendar) / 60 * hourHeight
        let endY = wallMinute(
            for: segment.endDate,
            on: segment.dayStart,
            calendar: calendar,
            isEnd: true
        ) / 60 * hourHeight
        return CalendarGridTimedFrame(
            x: x,
            y: y,
            width: max(laneWidth - laneGap, 0),
            height: max(endY - y, 0)
        )
    }

    /// Assigns all-day spans to the earliest available row, treating their end day as exclusive.
    /// This deterministic greedy policy prevents overlapping multi-day labels in the all-day area.
    public static func allDayPlacements(for spans: [CalendarAllDaySpan]) -> [CalendarGridAllDayPlacement] {
        let ordered = spans.sorted { lhs, rhs in
            if lhs.startDay != rhs.startDay { return lhs.startDay < rhs.startDay }
            if lhs.endDay != rhs.endDay { return lhs.endDay < rhs.endDay }
            return lhs.occurrenceID < rhs.occurrenceID
        }
        var rowEndDays: [Date] = []
        return ordered.map { span in
            let row = rowEndDays.firstIndex(where: { $0 <= span.startDay }) ?? rowEndDays.count
            if row == rowEndDays.count {
                rowEndDays.append(span.endDay)
            } else {
                rowEndDays[row] = span.endDay
            }
            return CalendarGridAllDayPlacement(span: span, row: row)
        }
    }

    public static func currentTimePosition(
        now: Date,
        dayStarts: [Date],
        calendar: Calendar
    ) -> CalendarGridCurrentTimePosition? {
        guard let dayIndex = dayStarts.firstIndex(where: { calendar.isDate($0, inSameDayAs: now) }) else {
            return nil
        }
        return CalendarGridCurrentTimePosition(
            dayIndex: dayIndex,
            y: wallMinute(for: now, on: dayStarts[dayIndex], calendar: calendar) / 60 * hourHeight
        )
    }

    /// Identity-only companion to the current-time line. A Date must match a local visible day,
    /// not a fixed elapsed duration or a presentation anchor, before the decorative tint appears.
    public static func todayColumnIndex(
        now: Date,
        dayStarts: [Date],
        calendar: Calendar
    ) -> Int? {
        dayStarts.firstIndex { calendar.isDate($0, inSameDayAs: now) }
    }
}

/// Read-only, local-time grid. Event geometry is deliberately driven by the pure Task 2 layout
/// output; this view never reaches into EventKit or recomputes overlap lanes.
public struct CalendarTimeGrid: View {
    public let interval: DateInterval
    public let events: [CalendarEventSnapshot]
    public let currentDate: Date
    public let descriptorColors: [String: CalendarColor]
    public let calendar: Calendar
    public let onSelectTimedEvent: (CalendarEventSnapshot) -> Void
    public let eventDetailPopoverTarget: Binding<CalendarEventDetailPopoverTarget?>
    public let onShowEventDetails: (CalendarEventSnapshot) -> Void
    public let onEventDetailPopoverChanged: (CalendarEventDetailPopoverTarget?) -> Void

    public init(
        interval: DateInterval,
        events: [CalendarEventSnapshot],
        currentDate: Date,
        descriptorColors: [String: CalendarColor],
        calendar: Calendar,
        onSelectTimedEvent: @escaping (CalendarEventSnapshot) -> Void,
        eventDetailPopoverTarget: Binding<CalendarEventDetailPopoverTarget?>,
        onShowEventDetails: @escaping (CalendarEventSnapshot) -> Void,
        onEventDetailPopoverChanged: @escaping (CalendarEventDetailPopoverTarget?) -> Void
    ) {
        self.interval = interval
        self.events = events
        self.currentDate = currentDate
        self.descriptorColors = descriptorColors
        self.calendar = calendar
        self.onSelectTimedEvent = onSelectTimedEvent
        self.eventDetailPopoverTarget = eventDetailPopoverTarget
        self.onShowEventDetails = onShowEventDetails
        self.onEventDetailPopoverChanged = onEventDetailPopoverChanged
    }

    private var dayStarts: [Date] {
        CalendarGridMetrics.dayStarts(in: interval, calendar: calendar)
    }

    private var timedSegments: [CalendarTimedSegment] {
        CalendarLayoutEngine.timedSegments(events: events, interval: interval, calendar: calendar)
    }

    private var timedGroups: [CalendarGridTimedGroup] {
        CalendarGridMetrics.overlapGroups(from: timedSegments)
    }

    private var allDayPlacements: [CalendarGridAllDayPlacement] {
        CalendarGridMetrics.allDayPlacements(
            for: CalendarLayoutEngine.allDaySpans(events: events, interval: interval, calendar: calendar)
        )
    }

    private var allDayRowCount: Int {
        max((allDayPlacements.map(\.row).max() ?? -1) + 1, 1)
    }

    public var body: some View {
        GeometryReader { geometry in
            let starts = dayStarts
            let horizontalLayout = CalendarGridHorizontalLayout(
                totalWidth: geometry.size.width,
                dayCount: starts.count
            )
            VStack(spacing: 0) {
                dayHeader(dayStarts: starts, horizontalLayout: horizontalLayout)
                allDayArea(dayStarts: starts, horizontalLayout: horizontalLayout)
                Divider()
                    .frame(width: horizontalLayout.totalWidth)
                ScrollViewReader { proxy in
                    ScrollView(.vertical, showsIndicators: false) {
                        timedArea(dayStarts: starts, horizontalLayout: horizontalLayout)
                    }
                    .frame(width: horizontalLayout.totalWidth, alignment: .leading)
                    .onAppear {
                        scrollToInitialHour(proxy: proxy, dayStarts: starts)
                    }
                }
            }
            .frame(width: horizontalLayout.totalWidth, alignment: .leading)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar time grid")
    }

    private func dayHeader(
        dayStarts: [Date],
        horizontalLayout: CalendarGridHorizontalLayout
    ) -> some View {
        return HStack(spacing: 0) {
            Text("Local \(calendar.timeZone.abbreviation(for: currentDate) ?? "time")")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: horizontalLayout.rulerWidth - 6, alignment: .trailing)
                .padding(.trailing, 6)
                .frame(width: horizontalLayout.rulerWidth, alignment: .trailing)
            ForEach(Array(dayStarts.enumerated()), id: \.element) { index, day in
                let dayFrame = horizontalLayout.dayFrame(at: index)
                ZStack {
                    if CalendarGridMetrics.todayColumnIndex(
                        now: currentDate,
                        dayStarts: dayStarts,
                        calendar: calendar
                    ) == index {
                        todayColumnFill(width: dayFrame.width, height: 44)
                    }
                    VStack(spacing: 2) {
                        Text(dayFormatter.string(from: day))
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                        Text(dayNumberFormatter.string(from: day))
                            .font(.system(size: 10, design: .rounded))
                            .foregroundStyle(Theme.textTertiary)
                    }
                }
                .frame(width: dayFrame.width)
            }
        }
        .frame(width: horizontalLayout.totalWidth, height: 44, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func allDayArea(
        dayStarts: [Date],
        horizontalLayout: CalendarGridHorizontalLayout
    ) -> some View {
        let height = CGFloat(allDayRowCount) * 22
        return ZStack(alignment: .topLeading) {
            todayColumnFill(dayStarts: dayStarts, horizontalLayout: horizontalLayout, height: height)

            Text("All-day")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: horizontalLayout.rulerWidth - 6, alignment: .trailing)
                .padding(.trailing, 6)
                .frame(width: horizontalLayout.rulerWidth, alignment: .trailing)
                .frame(height: 22, alignment: .top)

            ForEach(Array(allDayPlacements.enumerated()), id: \.offset) { _, placement in
                if let startIndex = dayStarts.firstIndex(of: placement.span.startDay) {
                    let spanFrame = horizontalLayout.daySpanFrame(
                        startingAt: startIndex,
                        dayCount: placement.span.dayCount
                    )
                    allDayLabel(for: placement.span.event)
                        .frame(width: max(spanFrame.width - 4, 0), height: 20, alignment: .leading)
                        .offset(
                            x: spanFrame.x + 2,
                            y: CGFloat(placement.row) * 22
                        )
                }
            }
        }
        .frame(width: horizontalLayout.totalWidth, height: height, alignment: .topLeading)
    }

    private func timedArea(
        dayStarts: [Date],
        horizontalLayout: CalendarGridHorizontalLayout
    ) -> some View {
        let contentHeight = 24 * CalendarGridMetrics.hourHeight
        return ZStack(alignment: .topLeading) {
            todayColumnFill(dayStarts: dayStarts, horizontalLayout: horizontalLayout, height: contentHeight)

            ForEach(0 ... 24, id: \.self) { hour in
                hourRule(hour: hour, horizontalLayout: horizontalLayout)
                    .id("calendar-hour-\(hour)")
                    .offset(y: CGFloat(hour) * CalendarGridMetrics.hourHeight)
            }

            ForEach(1 ..< dayStarts.count, id: \.self) { dayIndex in
                let dayFrame = horizontalLayout.dayFrame(at: dayIndex)
                Rectangle()
                    .fill(Theme.border.opacity(0.55))
                    .frame(width: 1, height: contentHeight)
                    .offset(x: dayFrame.x)
                    .accessibilityHidden(true)
            }

            if let position = CalendarGridMetrics.currentTimePosition(
                now: currentDate,
                dayStarts: dayStarts,
                calendar: calendar
            ) {
                let dayFrame = horizontalLayout.dayFrame(at: position.dayIndex)
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: dayFrame.width, height: 1)
                    .offset(
                        x: dayFrame.x,
                        y: position.y
                    )
                    .accessibilityHidden(true)
            }

            ForEach(timedGroups) { group in
                if group.usesOverflowMenu {
                    if let frame = CalendarGridMetrics.overlapSummaryFrame(
                        for: group,
                        dayStarts: dayStarts,
                        horizontalLayout: horizontalLayout,
                        calendar: calendar
                    ) {
                        overlapMenu(group: group, frame: frame)
                            .offset(x: frame.x, y: frame.y)
                    }
                } else {
                    ForEach(group.segments) { segment in
                        if let frame = CalendarGridMetrics.timedFrame(
                            for: segment,
                            dayStarts: dayStarts,
                            horizontalLayout: horizontalLayout,
                            calendar: calendar
                        ) {
                            timedEventButton(segment: segment, frame: frame)
                                .offset(x: frame.x, y: frame.y)
                        }
                    }
                }
            }
        }
        .frame(width: horizontalLayout.totalWidth, height: contentHeight, alignment: .topLeading)
    }

    private func hourRule(hour: Int, horizontalLayout: CalendarGridHorizontalLayout) -> some View {
        HStack(spacing: 0) {
            Text(hour == 24 ? "" : CalendarGridMetrics.rulerHourLabel(for: hour))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: horizontalLayout.rulerWidth - 6, alignment: .trailing)
                .padding(.trailing, 6)
                .frame(width: horizontalLayout.rulerWidth, alignment: .trailing)
            Rectangle()
                .fill(Theme.border.opacity(0.65))
                .frame(height: 1)
        }
        .frame(width: horizontalLayout.totalWidth, height: 1, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func allDayLabel(for event: CalendarEventSnapshot) -> some View {
        let color = calendarColor(for: event)
        return Button {
            onShowEventDetails(event)
        } label: {
            HStack(spacing: 5) {
                Rectangle()
                    .fill(color)
                    .frame(width: CalendarGridColor.leadingIndicatorWidth)
                Text(event.title)
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textPrimary)
                    .lineLimit(1)
                    .truncationMode(.tail)
                Spacer(minLength: 0)
            }
            .padding(.trailing, 4)
            .background(color.opacity(CalendarGridColor.fillOpacity), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(event.title), all-day, \(event.calendarTitle)")
        .accessibilityHint("Opens event details. Does not set a time.")
        .popover(isPresented: eventDetailPopoverBinding(for: event), arrowEdge: .bottom) {
            CalendarEventDetailsPopover(event: event, timeZone: calendar.timeZone)
        }
        .opacity(CalendarEventPresentationStyle.opacity(for: event))
    }

    private func timedEventButton(segment: CalendarTimedSegment, frame: CalendarGridTimedFrame) -> some View {
        let color = calendarColor(for: segment.event)
        let visualHeight = max(frame.height, 1)
        let hitHeight = max(frame.height, 22)
        return Button {
            onSelectTimedEvent(segment.event)
        } label: {
            ZStack(alignment: .topLeading) {
                HStack(spacing: 4) {
                    Rectangle()
                        .fill(color)
                        .frame(width: CalendarGridColor.leadingIndicatorWidth)
                    VStack(alignment: .leading, spacing: 1) {
                        Text(segment.event.title)
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Theme.textPrimary)
                            .lineLimit(1)
                        if visualHeight >= 28 {
                            Text(segment.event.calendarTitle)
                                .font(.system(size: 9, design: .rounded))
                                .foregroundStyle(Theme.textSecondary)
                                .lineLimit(1)
                        }
                    }
                    Spacer(minLength: 0)
                }
                .padding(.trailing, 3)
                .frame(width: max(frame.width, 1), height: visualHeight, alignment: .topLeading)
                .background(color.opacity(CalendarGridColor.fillOpacity), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
            }
            .frame(width: max(frame.width, 1), height: hitHeight, alignment: .topLeading)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(eventAccessibilityLabel(segment.event))
        .accessibilityHint("Sets TimeZoner to this event start")
        .opacity(CalendarEventPresentationStyle.opacity(for: segment.event))
    }

    private func overlapMenu(group: CalendarGridTimedGroup, frame: CalendarGridTimedFrame) -> some View {
        let color = group.segments.first.map { calendarColor(for: $0.event) } ?? Theme.border
        return Menu {
            ForEach(group.segments) { segment in
                Button(eventMenuTitle(segment.event)) {
                    onSelectTimedEvent(segment.event)
                }
                .accessibilityLabel(eventAccessibilityLabel(segment.event))
            }
        } label: {
            HStack(spacing: 5) {
                Rectangle()
                    .fill(color)
                    .frame(width: CalendarGridColor.leadingIndicatorWidth)
                VStack(alignment: .leading, spacing: 1) {
                    Text("\(group.segments.count) overlapping events")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.textPrimary)
                        .lineLimit(1)
                    Text("Choose an event")
                        .font(.system(size: 9, design: .rounded))
                        .foregroundStyle(Theme.textSecondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 0)
            }
            .padding(.trailing, 3)
            .frame(width: frame.width, height: frame.height, alignment: .topLeading)
            .background(color.opacity(CalendarGridColor.fillOpacity), in: RoundedRectangle(cornerRadius: 4, style: .continuous))
        }
        .menuStyle(.borderlessButton)
        .accessibilityLabel("\(group.segments.count) overlapping events, \(timeFormatter.string(from: group.startDate)) to \(timeFormatter.string(from: group.endDate))")
        .accessibilityHint("Opens a menu of calendar events to set TimeZoner to an event start")
    }

    @ViewBuilder
    private func todayColumnFill(
        dayStarts: [Date],
        horizontalLayout: CalendarGridHorizontalLayout,
        height: CGFloat
    ) -> some View {
        if let dayIndex = CalendarGridMetrics.todayColumnIndex(
            now: currentDate,
            dayStarts: dayStarts,
            calendar: calendar
        ) {
            let dayFrame = horizontalLayout.dayFrame(at: dayIndex)
            todayColumnFill(width: dayFrame.width, height: height)
                .offset(x: dayFrame.x)
        }
    }

    private func todayColumnFill(width: CGFloat, height: CGFloat) -> some View {
        Rectangle()
            .fill(Theme.accent.opacity(0.07))
            .frame(width: width, height: height)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }

    private func eventDetailPopoverBinding(for event: CalendarEventSnapshot) -> Binding<Bool> {
        let target = detailPopoverTarget(for: event)
        return Binding(
            get: { eventDetailPopoverTarget.wrappedValue == target },
            set: { isPresented in
                if isPresented {
                    onEventDetailPopoverChanged(target)
                } else if eventDetailPopoverTarget.wrappedValue == target {
                    onEventDetailPopoverChanged(nil)
                }
            }
        )
    }

    private func detailPopoverTarget(for event: CalendarEventSnapshot) -> CalendarEventDetailPopoverTarget {
        CalendarEventDetailPopoverTarget(eventID: event.id, presenterID: "calendar-grid:\(event.id)")
    }

    private func calendarColor(for event: CalendarEventSnapshot) -> Color {
        guard let rawColor = descriptorColors[event.calendarID] else {
            return Theme.border
        }
        let color = CalendarGridColor.displayColor(from: rawColor)
        return Color(red: color.red, green: color.green, blue: color.blue, opacity: color.alpha)
    }

    private func eventAccessibilityLabel(_ event: CalendarEventSnapshot) -> String {
        "\(event.title), \(timeFormatter.string(from: event.startDate)) to \(timeFormatter.string(from: event.endDate)), \(event.calendarTitle)"
    }

    private func eventMenuTitle(_ event: CalendarEventSnapshot) -> String {
        "\(event.title) — \(timeFormatter.string(from: event.startDate)) to \(timeFormatter.string(from: event.endDate)) — \(event.calendarTitle)"
    }

    private func scrollToInitialHour(proxy: ScrollViewProxy, dayStarts: [Date]) {
        let nowIsVisible = CalendarGridMetrics.currentTimePosition(
            now: currentDate,
            dayStarts: dayStarts,
            calendar: calendar
        ) != nil
        let hour = nowIsVisible ? calendar.component(.hour, from: currentDate) : 8
        DispatchQueue.main.async {
            proxy.scrollTo("calendar-hour-\(hour)", anchor: .top)
        }
    }

    private var dayFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "EEE"
        return formatter
    }

    private var dayNumberFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "MMM d"
        return formatter
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h:mm a z"
        return formatter
    }
}
