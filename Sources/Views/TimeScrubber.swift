import SwiftUI

public struct TimeScrubber: View {
    public let zones: [ZoneInfo]
    public let timeState: TimeState

    private let rowHeight: CGFloat = 28
    private let hourWidth: CGFloat = 28     // width per hour — 24h * 28 = 672px total
    private let totalHours = 24

    @State private var dragOffset: CGFloat = 0

    public init(zones: [ZoneInfo], timeState: TimeState) {
        self.zones = zones
        self.timeState = timeState
    }

    public var body: some View {
        VStack(spacing: 0) {
            // Hour labels row
            hourLabelsRow
                .padding(.leading, labelWidth)

            // One bar per timezone
            ForEach(zones) { zone in
                HStack(spacing: 0) {
                    // Zone abbreviation label
                    Text(zone.label)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .foregroundStyle(Theme.warmGray)
                        .frame(width: labelWidth, alignment: .trailing)
                        .padding(.trailing, 6)
                        .lineLimit(1)

                    // 24h color bar with current time indicator
                    timelineBar(for: zone)
                }
                .frame(height: rowHeight)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 2)
                .onChanged { value in
                    dragOffset = value.translation.width
                }
                .onEnded { value in
                    // Convert drag distance to minutes (15-min increments)
                    let minutesPerPixel = (24.0 * 60.0) / (CGFloat(totalHours) * hourWidth)
                    let rawMinutes = -Double(dragOffset) * Double(minutesPerPixel)
                    let snappedMinutes = (rawMinutes / 15.0).rounded() * 15.0

                    if abs(snappedMinutes) >= 15 {
                        let calendar = Calendar.current
                        if let newDate = calendar.date(byAdding: .minute, value: Int(snappedMinutes), to: timeState.referenceDate) {
                            timeState.referenceDate = newDate
                        }
                    }
                    withAnimation(.easeOut(duration: 0.15)) {
                        dragOffset = 0
                    }
                }
        )
        // Prevent window drag from eating our gesture
        .onHover { _ in }
    }

    private var labelWidth: CGFloat { 56 }

    // MARK: - Hour labels

    private var hourLabelsRow: some View {
        HStack(spacing: 0) {
            ForEach(0..<totalHours, id: \.self) { hour in
                Text(hour % 3 == 0 ? "\(hour)" : "")
                    .font(.system(size: 9, weight: .regular, design: .rounded))
                    .foregroundStyle(Theme.warmGray.opacity(0.7))
                    .frame(width: hourWidth)
            }
        }
        .frame(height: 14)
        .offset(x: dragOffset)
    }

    // MARK: - Timeline bar for a zone

    private func timelineBar(for zone: ZoneInfo) -> some View {
        let tz = zone.timeZone

        return GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Day-period color blocks
                HStack(spacing: 0) {
                    ForEach(0..<totalHours, id: \.self) { hour in
                        Rectangle()
                            .fill(colorForHour(hour))
                            .frame(width: hourWidth)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                .offset(x: dragOffset)

                // Current time indicator
                let xPos = currentTimeX(in: tz)
                if xPos >= 0 && xPos <= geo.size.width + abs(dragOffset) {
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(Theme.accent)
                        .frame(width: 3, height: rowHeight - 4)
                        .offset(x: xPos + dragOffset - 1.5)
                }
            }
            .frame(height: rowHeight)
        }
        .frame(width: CGFloat(totalHours) * hourWidth, height: rowHeight)
        .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .strokeBorder(Theme.warmBorder.opacity(0.5), lineWidth: 0.5)
        )
    }

    // MARK: - Time position

    private func currentTimeX(in zone: TimeZone) -> CGFloat {
        var calendar = Calendar.current
        calendar.timeZone = zone
        let components = calendar.dateComponents([.hour, .minute], from: timeState.referenceDate)
        let hour = CGFloat(components.hour ?? 0)
        let minute = CGFloat(components.minute ?? 0)
        return (hour + minute / 60.0) * hourWidth
    }

    // MARK: - Day period colors

    private func colorForHour(_ hour: Int) -> Color {
        switch hour {
        case 0..<6:     // Night — dark cool gray
            return Color(red: 0.22, green: 0.24, blue: 0.28).opacity(0.35)
        case 6..<9:     // Early morning — warm sunrise
            return Color(red: 0.95, green: 0.85, blue: 0.65).opacity(0.45)
        case 9..<17:    // Working hours — bright warm
            return Color(red: 0.92, green: 0.95, blue: 0.85).opacity(0.50)
        case 17..<20:   // Evening — warm sunset
            return Color(red: 0.95, green: 0.82, blue: 0.65).opacity(0.45)
        case 20..<24:   // Night — dark cool gray
            return Color(red: 0.22, green: 0.24, blue: 0.28).opacity(0.35)
        default:
            return Color.clear
        }
    }
}
