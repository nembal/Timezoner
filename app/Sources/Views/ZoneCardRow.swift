import SwiftUI

public struct ZoneCardRow: View {
    public let zones: [ZoneInfo]
    @Bindable public var timeState: TimeState
    @Binding public var editingZoneId: UUID?
    public let highlightedZoneIds: Set<UUID>
    public let onRemove: (UUID) -> Void
    public let onMove: (Int, Int) -> Void  // fromIndex, toIndex

    @State private var draggingZoneId: UUID? = nil
    @State private var dragOffset: CGFloat = 0
    @State private var cardWidth: CGFloat = 150  // measured dynamically

    public init(zones: [ZoneInfo], timeState: TimeState, editingZoneId: Binding<UUID?>,
                highlightedZoneIds: Set<UUID> = [],
                onRemove: @escaping (UUID) -> Void,
                onMove: @escaping (IndexSet, Int) -> Void = { _, _ in }) {
        self.zones = zones
        self.timeState = timeState
        self._editingZoneId = editingZoneId
        self.highlightedZoneIds = highlightedZoneIds
        self.onRemove = onRemove
        // Adapt IndexSet API to simple Int,Int
        self.onMove = { from, to in
            onMove(IndexSet(integer: from), to)
        }
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                let isDragging = draggingZoneId == zone.id

                ZoneCard(
                    zone: zone,
                    timeState: timeState,
                    isSource: timeState.sourceZoneId == zone.timeZoneId,
                    isHighlighted: highlightedZoneIds.contains(zone.id),
                    editingZoneId: $editingZoneId,
                    isDragging: isDragging,
                    onRemove: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onRemove(zone.id)
                        }
                    },
                    onDragChanged: { offset in
                        draggingZoneId = zone.id
                        dragOffset = offset
                        editingZoneId = nil

                        // Check if we should swap
                        let slotWidth = cardWidth + 36 // card + diff label
                        let slotsToMove = Int((offset / slotWidth).rounded())
                        if slotsToMove != 0 {
                            let targetIndex = min(max(index + slotsToMove, 0), zones.count - 1)
                            if targetIndex != index {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    let dest = targetIndex > index ? targetIndex + 1 : targetIndex
                                    onMove(index, dest)
                                }
                                // Reset offset after swap so it feels natural
                                dragOffset = 0
                            }
                        }
                    },
                    onDragEnded: {
                        // Instantly clear offset (no animation) to avoid flicker
                        dragOffset = 0
                        // Animate only the visual lift (scale/shadow) back
                        withAnimation(.easeOut(duration: 0.15)) {
                            draggingZoneId = nil
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                .offset(x: isDragging ? dragOffset : 0)
                .zIndex(isDragging ? 10 : 0)
                .background(
                    GeometryReader { geo in
                        Color.clear.onAppear {
                            cardWidth = geo.size.width
                        }
                    }
                )
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))

                if index < zones.count - 1 {
                    timeDiffLabel(from: zone, to: zones[index + 1])
                }
            }
        }
    }

    private func timeDiffLabel(from: ZoneInfo, to: ZoneInfo) -> some View {
        let diff = TimeFormatter.relativeOffset(from: from.timeZone, to: to.timeZone, at: timeState.referenceDate)

        return VStack(spacing: 2) {
            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(Theme.textTertiary)

            Text(diff)
                .font(.system(size: 12, weight: .medium, design: .rounded))
                .foregroundStyle(Theme.textTertiary)
        }
        .frame(width: 36)
    }
}
