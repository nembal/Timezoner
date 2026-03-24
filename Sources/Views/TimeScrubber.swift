import SwiftUI

public struct TimeScrubber: View {
    public let timeState: TimeState

    private let slotWidth: CGFloat = 48
    private let halfSlots = 24  // ±12 hours in 30-min increments
    private let height: CGFloat = 48

    @State private var accumulatedOffset: CGFloat = 0
    @State private var dragOffset: CGFloat = 0

    public init(timeState: TimeState) {
        self.timeState = timeState
    }

    private var effectiveOffset: CGFloat {
        accumulatedOffset + dragOffset
    }

    public var body: some View {
        GeometryReader { geo in
            let viewWidth = geo.size.width
            let centerX = viewWidth / 2

            ZStack {
                // Track background
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Theme.scrubberBg)
                    .frame(height: height)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .strokeBorder(Theme.warmBorder, lineWidth: 0.5)
                    )

                // Time markers — drawn relative to center + offset
                Canvas { context, size in
                    let midX = size.width / 2

                    for i in -halfSlots...halfSlots {
                        let x = midX + CGFloat(i) * slotWidth + effectiveOffset

                        // Skip if off screen
                        guard x > -slotWidth && x < size.width + slotWidth else { continue }

                        let date = dateForSlotOffset(i)
                        let isHour = i % 2 == 0

                        // Tick mark
                        let tickHeight: CGFloat = isHour ? 14 : 8
                        let tickWidth: CGFloat = isHour ? 1.5 : 1
                        let tickY = (size.height - tickHeight) / 2 - 4
                        let tickRect = CGRect(x: x - tickWidth / 2, y: tickY, width: tickWidth, height: tickHeight)

                        // Fade based on distance from center
                        let distFromCenter = abs(x - midX)
                        let maxDist = size.width / 2
                        let opacity = max(0, 1 - (distFromCenter / maxDist) * 0.7)

                        context.fill(
                            Path(roundedRect: tickRect, cornerRadius: 0.5),
                            with: .color(Theme.warmGray.opacity(opacity * (isHour ? 0.5 : 0.25)))
                        )

                        // Time label (every hour)
                        if isHour {
                            let label = shortTimeLabel(for: date)
                            let text = Text(label)
                                .font(.system(size: 10, weight: .regular, design: .rounded))
                                .foregroundStyle(Theme.warmGray.opacity(opacity))
                            let resolved = context.resolve(text)
                            let textSize = resolved.measure(in: CGSize(width: 60, height: 20))
                            context.draw(resolved, at: CGPoint(x: x, y: size.height / 2 + 12), anchor: .center)
                            _ = textSize // silence warning
                        }
                    }
                }
                .frame(height: height)
                .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))

                // Center indicator
                VStack(spacing: 0) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Theme.accent)
                        .frame(width: 3, height: 20)
                    Circle()
                        .fill(Theme.accent)
                        .frame(width: 7, height: 7)
                }
                .position(x: centerX, y: height / 2 - 2)
                .allowsHitTesting(false)
            }
            .frame(height: height)
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 1)
                    .onChanged { value in
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        let totalOffset = accumulatedOffset + value.translation.width
                        let slotsMoved = -totalOffset / slotWidth
                        let roundedSlots = Int(slotsMoved.rounded())
                        let minuteOffset = roundedSlots * 30

                        if minuteOffset != 0 {
                            let calendar = Calendar.current
                            if let newDate = calendar.date(byAdding: .minute, value: minuteOffset, to: timeState.referenceDate) {
                                timeState.referenceDate = newDate
                            }
                        }

                        withAnimation(.easeOut(duration: 0.15)) {
                            accumulatedOffset = 0
                            dragOffset = 0
                        }
                    }
            )
        }
        .frame(height: height)
    }

    private func dateForSlotOffset(_ offset: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .minute, value: offset * 30, to: timeState.referenceDate) ?? timeState.referenceDate
    }

    private func shortTimeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeState.sourceZoneId) ?? .current
        formatter.dateFormat = "h:mm a"
        formatter.amSymbol = "am"
        formatter.pmSymbol = "pm"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date).lowercased()
    }
}
