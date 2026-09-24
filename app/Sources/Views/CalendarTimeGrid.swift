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
public enum CalendarGridMetrics {
    public static let timeRulerWidth: CGFloat = 48
    public static let hourHeight: CGFloat = 52
    public static let horizontalInset: CGFloat = 4
    public static let laneGap: CGFloat = 2

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
        guard let dayIndex = dayStarts.firstIndex(of: segment.dayStart), !dayStarts.isEmpty else {
            return nil
        }

        let dayWidth = max((totalWidth - timeRulerWidth) / CGFloat(dayStarts.count), 0)
        let usableWidth = max(dayWidth - 2 * horizontalInset, 0)
        let laneCount = max(segment.laneCount, 1)
        let laneWidth = usableWidth / CGFloat(laneCount)
        let x = timeRulerWidth
            + CGFloat(dayIndex) * dayWidth
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

    public init(
        interval: DateInterval,
        events: [CalendarEventSnapshot],
        currentDate: Date,
        descriptorColors: [String: CalendarColor],
        calendar: Calendar,
        onSelectTimedEvent: @escaping (CalendarEventSnapshot) -> Void
    ) {
        self.interval = interval
        self.events = events
        self.currentDate = currentDate
        self.descriptorColors = descriptorColors
        self.calendar = calendar
        self.onSelectTimedEvent = onSelectTimedEvent
    }

    private var dayStarts: [Date] {
        CalendarGridMetrics.dayStarts(in: interval, calendar: calendar)
    }

    private var timedSegments: [CalendarTimedSegment] {
        CalendarLayoutEngine.timedSegments(events: events, interval: interval, calendar: calendar)
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
            let gridWidth = geometry.size.width
            let starts = dayStarts
            VStack(spacing: 0) {
                dayHeader(dayStarts: starts, totalWidth: gridWidth)
                allDayArea(dayStarts: starts, totalWidth: gridWidth)
                Divider()
                ScrollViewReader { proxy in
                    ScrollView(.vertical) {
                        timedArea(dayStarts: starts, totalWidth: gridWidth)
                    }
                    .onAppear {
                        scrollToInitialHour(proxy: proxy, dayStarts: starts)
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Calendar time grid")
    }

    private func dayHeader(dayStarts: [Date], totalWidth: CGFloat) -> some View {
        let dayWidth = dayColumnWidth(totalWidth: totalWidth, dayCount: dayStarts.count)
        return HStack(spacing: 0) {
            Text("Local \(calendar.timeZone.abbreviation(for: currentDate) ?? "time")")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: CalendarGridMetrics.timeRulerWidth, alignment: .trailing)
                .padding(.trailing, 6)
            ForEach(dayStarts, id: \.self) { day in
                VStack(spacing: 2) {
                    Text(dayFormatter.string(from: day))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                    Text(dayNumberFormatter.string(from: day))
                        .font(.system(size: 10, design: .rounded))
                        .foregroundStyle(Theme.textTertiary)
                }
                .frame(width: dayWidth)
            }
        }
        .frame(height: 44)
        .accessibilityElement(children: .combine)
    }

    private func allDayArea(dayStarts: [Date], totalWidth: CGFloat) -> some View {
        let dayWidth = dayColumnWidth(totalWidth: totalWidth, dayCount: dayStarts.count)
        let height = CGFloat(allDayRowCount) * 22
        return ZStack(alignment: .topLeading) {
            Text("All-day")
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: CalendarGridMetrics.timeRulerWidth, alignment: .trailing)
                .padding(.trailing, 6)
                .frame(height: 22, alignment: .top)

            ForEach(Array(allDayPlacements.enumerated()), id: \.offset) { _, placement in
                if let startIndex = dayStarts.firstIndex(of: placement.span.startDay) {
                    let width = CGFloat(placement.span.dayCount) * dayWidth
                    allDayLabel(for: placement.span.event)
                        .frame(width: max(width - 4, 0), height: 20, alignment: .leading)
                        .offset(
                            x: CalendarGridMetrics.timeRulerWidth + CGFloat(startIndex) * dayWidth + 2,
                            y: CGFloat(placement.row) * 22
                        )
                }
            }
        }
        .frame(width: totalWidth, height: height, alignment: .topLeading)
    }

    private func timedArea(dayStarts: [Date], totalWidth: CGFloat) -> some View {
        let contentHeight = 24 * CalendarGridMetrics.hourHeight
        let dayWidth = dayColumnWidth(totalWidth: totalWidth, dayCount: dayStarts.count)
        return ZStack(alignment: .topLeading) {
            ForEach(0 ... 24, id: \.self) { hour in
                hourRule(hour: hour, totalWidth: totalWidth)
                    .id("calendar-hour-\(hour)")
                    .offset(y: CGFloat(hour) * CalendarGridMetrics.hourHeight)
            }

            ForEach(1 ..< dayStarts.count, id: \.self) { dayIndex in
                Rectangle()
                    .fill(Theme.border.opacity(0.55))
                    .frame(width: 1, height: contentHeight)
                    .offset(x: CalendarGridMetrics.timeRulerWidth + CGFloat(dayIndex) * dayWidth)
                    .accessibilityHidden(true)
            }

            if let position = CalendarGridMetrics.currentTimePosition(
                now: currentDate,
                dayStarts: dayStarts,
                calendar: calendar
            ) {
                Rectangle()
                    .fill(Theme.accent)
                    .frame(width: dayWidth, height: 1)
                    .offset(
                        x: CalendarGridMetrics.timeRulerWidth + CGFloat(position.dayIndex) * dayWidth,
                        y: position.y
                    )
                    .accessibilityHidden(true)
            }

            ForEach(timedSegments) { segment in
                if let frame = CalendarGridMetrics.timedFrame(
                    for: segment,
                    dayStarts: dayStarts,
                    totalWidth: totalWidth,
                    calendar: calendar
                ) {
                    timedEventButton(segment: segment, frame: frame)
                        .offset(x: frame.x, y: frame.y)
                }
            }
        }
        .frame(width: totalWidth, height: contentHeight, alignment: .topLeading)
    }

    private func hourRule(hour: Int, totalWidth: CGFloat) -> some View {
        HStack(spacing: 0) {
            Text(hour == 24 ? "" : hourFormatter.string(from: hourDate(hour)))
                .font(.system(size: 10, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
                .frame(width: CalendarGridMetrics.timeRulerWidth, alignment: .trailing)
                .padding(.trailing, 6)
            Rectangle()
                .fill(Theme.border.opacity(0.65))
                .frame(height: 1)
        }
        .frame(width: totalWidth, height: 1, alignment: .topLeading)
        .accessibilityHidden(true)
    }

    private func allDayLabel(for event: CalendarEventSnapshot) -> some View {
        let color = calendarColor(for: event)
        return HStack(spacing: 5) {
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
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(event.title), all-day, \(event.calendarTitle). Does not set a time.")
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
    }

    private func dayColumnWidth(totalWidth: CGFloat, dayCount: Int) -> CGFloat {
        guard dayCount > 0 else { return 0 }
        return max((totalWidth - CalendarGridMetrics.timeRulerWidth) / CGFloat(dayCount), 0)
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

    private func hourDate(_ hour: Int) -> Date {
        calendar.date(bySettingHour: hour % 24, minute: 0, second: 0, of: interval.start) ?? interval.start
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

    private var hourFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.calendar = calendar
        formatter.locale = .current
        formatter.timeZone = calendar.timeZone
        formatter.dateFormat = "h a"
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
