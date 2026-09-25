import SwiftUI

public struct ZoneCardCollection: View {
    public enum Axis: Equatable {
        case horizontal
        case vertical
    }

    public let axis: Axis
    public let zones: [ZoneInfo]
    public let referenceMoment: ReferenceMomentController
    @Binding public var editingZoneId: UUID?
    public let highlightedZoneIds: Set<UUID>
    public let onRemove: (UUID) -> Void
    public let onMove: (IndexSet, Int) -> Void

    @State private var draggingZoneId: UUID?
    @State private var dragOffset: CGSize = .zero
    @State private var cardSize = CGSize(width: 150, height: 120)

    private var timeState: TimeState {
        referenceMoment.timeState
    }

    public init(
        axis: Axis,
        zones: [ZoneInfo],
        referenceMoment: ReferenceMomentController,
        editingZoneId: Binding<UUID?>,
        highlightedZoneIds: Set<UUID> = [],
        onRemove: @escaping (UUID) -> Void,
        onMove: @escaping (IndexSet, Int) -> Void = { _, _ in }
    ) {
        self.axis = axis
        self.zones = zones
        self.referenceMoment = referenceMoment
        self._editingZoneId = editingZoneId
        self.highlightedZoneIds = highlightedZoneIds
        self.onRemove = onRemove
        self.onMove = onMove
    }

    public var body: some View {
        Group {
            switch axis {
            case .horizontal:
                HStack(spacing: 0) {
                    ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                        zoneCard(index: index, zone: zone)

                        if index < zones.count - 1 {
                            timeDiffLabel(from: zone, to: zones[index + 1])
                        }
                    }
                }
            case .vertical:
                LazyVStack(spacing: 10) {
                    ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                        zoneCard(index: index, zone: zone)
                    }
                }
            }
        }
    }

    private func zoneCard(index: Int, zone: ZoneInfo) -> some View {
        let isDragging = draggingZoneId == zone.id

        return ZoneCard(
            zone: zone,
            referenceMoment: referenceMoment,
            isSource: timeState.sourceZoneId == zone.timeZoneId,
            isHighlighted: highlightedZoneIds.contains(zone.id),
            editingZoneId: $editingZoneId,
            isDragging: isDragging,
            onRemove: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    onRemove(zone.id)
                }
            },
            onDragChanged: { translation in
                handleDrag(index: index, zone: zone, translation: translation)
            },
            onDragEnded: endDrag
        )
        .frame(maxWidth: .infinity)
        .offset(
            x: axis == .horizontal && isDragging ? dragOffset.width : 0,
            y: axis == .vertical && isDragging ? dragOffset.height : 0
        )
        .zIndex(isDragging ? 10 : 0)
        .background(
            GeometryReader { geo in
                Color.clear.onAppear {
                    cardSize = geo.size
                }
            }
        )
        .transition(cardTransition)
    }

    private func handleDrag(index: Int, zone: ZoneInfo, translation: CGSize) {
        draggingZoneId = zone.id
        dragOffset = translation
        editingZoneId = nil

        let primaryTranslation = axis == .horizontal ? translation.width : translation.height
        let slotExtent = axis == .horizontal ? cardSize.width + 36 : cardSize.height + 10
        guard let destination = ZoneCardOrdering.destination(
            sourceIndex: index,
            translation: primaryTranslation,
            slotExtent: slotExtent,
            count: zones.count
        ) else {
            return
        }

        withAnimation(.easeInOut(duration: 0.2)) {
            onMove(IndexSet(integer: index), destination)
        }
        dragOffset = .zero
    }

    private func endDrag() {
        dragOffset = .zero
        withAnimation(.easeOut(duration: 0.15)) {
            draggingZoneId = nil
        }
    }

    private var cardTransition: AnyTransition {
        switch axis {
        case .horizontal:
            .asymmetric(
                insertion: .move(edge: .trailing).combined(with: .opacity),
                removal: .opacity
            )
        case .vertical:
            .identity
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
