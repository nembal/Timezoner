import SwiftUI

public struct ZoneCardRow: View {
    public let zones: [ZoneInfo]
    public let timeState: TimeState
    public let onRemove: (UUID) -> Void

    public init(zones: [ZoneInfo], timeState: TimeState, onRemove: @escaping (UUID) -> Void) {
        self.zones = zones
        self.timeState = timeState
        self.onRemove = onRemove
    }

    public var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 12) {
                ForEach(zones) { zone in
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
                    .transition(.asymmetric(
                        insertion: .move(edge: .trailing).combined(with: .opacity),
                        removal: .opacity
                    ))
                }
            }
            .padding(.horizontal, 4)
        }
    }
}
