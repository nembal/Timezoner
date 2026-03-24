import SwiftUI

public struct TimeStepper: View {
    public let timeState: TimeState

    public init(timeState: TimeState) {
        self.timeState = timeState
    }

    public var body: some View {
        HStack(spacing: 16) {
            // Back 30 min
            stepButton(systemName: "chevron.left", minutes: -30)

            // Back 15 min
            stepButton(systemName: "chevron.left", minutes: -15, small: true)

            Spacer()

            // Current reference time label
            VStack(spacing: 1) {
                Text(sourceTimeLabel)
                    .font(.system(size: 12, weight: .medium, design: .rounded))
                    .foregroundStyle(Theme.textSecondary)

                Text(sourceDateLabel)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundStyle(Theme.textTertiary)
            }

            Spacer()

            // Forward 15 min
            stepButton(systemName: "chevron.right", minutes: 15, small: true)

            // Forward 30 min
            stepButton(systemName: "chevron.right", minutes: 30)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
    }

    private func stepButton(systemName: String, minutes: Int, small: Bool = false) -> some View {
        Button(action: {
            let calendar = Calendar.current
            if let newDate = calendar.date(byAdding: .minute, value: minutes, to: timeState.referenceDate) {
                withAnimation(.easeInOut(duration: 0.15)) {
                    timeState.referenceDate = newDate
                }
            }
        }) {
            Image(systemName: systemName)
                .font(.system(size: small ? 10 : 12, weight: .medium))
                .foregroundStyle(Theme.textSecondary)
                .frame(width: small ? 24 : 28, height: small ? 24 : 28)
                .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 6, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .strokeBorder(Theme.border, lineWidth: 0.5)
                )
        }
        .buttonStyle(.plain)
    }

    private var sourceTimeLabel: String {
        let tz = TimeZone(identifier: timeState.sourceZoneId) ?? .current
        return TimeFormatter.formatTime(timeState.referenceDate, in: tz)
    }

    private var sourceDateLabel: String {
        let tz = TimeZone(identifier: timeState.sourceZoneId) ?? .current
        return TimeFormatter.formatDate(timeState.referenceDate, in: tz)
    }
}
