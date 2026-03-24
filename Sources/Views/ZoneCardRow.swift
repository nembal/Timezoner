import SwiftUI

public struct ZoneCardRow: View {
    public let zones: [ZoneInfo]
    @Bindable public var timeState: TimeState
    public let onRemove: (UUID) -> Void

    public init(zones: [ZoneInfo], timeState: TimeState, onRemove: @escaping (UUID) -> Void) {
        self.zones = zones
        self.timeState = timeState
        self.onRemove = onRemove
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                ZoneCard(
                    zone: zone,
                    timeState: timeState,
                    isSource: timeState.sourceZoneId == zone.timeZoneId,
                    onRemove: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onRemove(zone.id)
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))

                // Time difference annotation between cards
                if index < zones.count - 1 {
                    timeDiffLabel(from: zone, to: zones[index + 1])
                }
            }
        }
    }

    private func timeDiffLabel(from: ZoneInfo, to: ZoneInfo) -> some View {
        let diff = hourDifference(from: from.timeZone, to: to.timeZone)

        return VStack(spacing: 2) {
            Image(systemName: "arrow.right")
                .font(.system(size: 8, weight: .medium))
                .foregroundStyle(Theme.textTertiary)

            Text(diff)
                .font(.system(size: 10, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(width: 36)
    }

    private func hourDifference(from: TimeZone, to: TimeZone) -> String {
        let fromOffset = from.secondsFromGMT(for: timeState.referenceDate)
        let toOffset = to.secondsFromGMT(for: timeState.referenceDate)
        let diffHours = Double(toOffset - fromOffset) / 3600.0

        if diffHours == diffHours.rounded() {
            let h = Int(diffHours)
            return h >= 0 ? "+\(h)h" : "\(h)h"
        } else {
            return diffHours >= 0
                ? String(format: "+%.1fh", diffHours)
                : String(format: "%.1fh", diffHours)
        }
    }
}
