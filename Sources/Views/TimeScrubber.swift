import SwiftUI

public struct TimeScrubber: View {
    public let timeState: TimeState

    // Each 30-min slot is 40px wide; ±12 hours = 48 slots = 49 markers
    private let slotWidth: CGFloat = 40
    private let totalSlots = 48 // ±12 hours in 30-min increments
    private let halfSlots = 24  // 12 hours worth of 30-min slots

    @State private var dragOffset: CGFloat = 0
    @State private var isDragging = false

    public init(timeState: TimeState) {
        self.timeState = timeState
    }

    public var body: some View {
        GeometryReader { geo in
            let viewWidth = geo.size.width
            let contentWidth = CGFloat(totalSlots) * slotWidth
            let centerX = viewWidth / 2

            ZStack {
                // Track background
                Capsule()
                    .fill(.regularMaterial)
                    .frame(height: 44)

                // Time markers
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 0) {
                        ForEach(-halfSlots...halfSlots, id: \.self) { slotOffset in
                            let date = dateForSlotOffset(slotOffset)
                            let isCenter = slotOffset == currentSnappedSlot

                            VStack(spacing: 2) {
                                // Tick mark
                                RoundedRectangle(cornerRadius: 1)
                                    .fill(isCenter ? Color.accentColor : Color.secondary.opacity(0.3))
                                    .frame(width: isCenter ? 3 : 1, height: isCenter ? 16 : 10)

                                // Label (show every hour, i.e., every 2 slots)
                                if slotOffset % 2 == 0 {
                                    Text(shortTimeLabel(for: date))
                                        .font(.system(size: 9, weight: isCenter ? .semibold : .regular, design: .rounded))
                                        .foregroundStyle(isCenter ? Color.accentColor : .secondary)
                                        .lineLimit(1)
                                        .fixedSize()
                                }
                            }
                            .frame(width: slotWidth)
                        }
                    }
                    .padding(.horizontal, max(0, (viewWidth - contentWidth) / 2))
                }
                .frame(height: 44)
                .clipShape(Capsule())

                // Center indicator line
                Rectangle()
                    .fill(Color.accentColor)
                    .frame(width: 2, height: 44)
                    .position(x: centerX, y: 22)
                    .allowsHitTesting(false)
            }
            .frame(height: 44)
            .gesture(
                DragGesture()
                    .onChanged { value in
                        isDragging = true
                        dragOffset = value.translation.width
                    }
                    .onEnded { value in
                        isDragging = false
                        let slotsMoved = -value.translation.width / slotWidth
                        let roundedSlots = Int(slotsMoved.rounded())
                        let minuteOffset = roundedSlots * 30

                        if minuteOffset != 0 {
                            var calendar = Calendar.current
                            calendar.timeZone = TimeZone(identifier: timeState.sourceZoneId) ?? .current
                            if let newDate = calendar.date(byAdding: .minute, value: minuteOffset, to: timeState.referenceDate) {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    timeState.referenceDate = newDate
                                }
                            }
                        }
                        dragOffset = 0
                    }
            )
        }
        .frame(height: 44)
    }

    private var currentSnappedSlot: Int {
        0 // Center is always the current reference time
    }

    private func dateForSlotOffset(_ offset: Int) -> Date {
        let calendar = Calendar.current
        return calendar.date(byAdding: .minute, value: offset * 30, to: timeState.referenceDate) ?? timeState.referenceDate
    }

    private func shortTimeLabel(for date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeZone = TimeZone(identifier: timeState.sourceZoneId) ?? .current
        formatter.dateFormat = "ha"
        formatter.amSymbol = "a"
        formatter.pmSymbol = "p"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        return formatter.string(from: date).lowercased()
    }
}
