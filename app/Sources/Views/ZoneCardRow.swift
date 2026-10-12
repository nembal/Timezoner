import SwiftUI

public struct ZoneCardRow: View {
    public let zones: [ZoneInfo]
    public let referenceMoment: ReferenceMomentController
    @Binding public var editingZoneId: UUID?
    public let highlightedZoneIds: Set<UUID>
    public let onRemove: (UUID) -> Void
    public let onMove: (Int, Int) -> Void

    public init(zones: [ZoneInfo], referenceMoment: ReferenceMomentController, editingZoneId: Binding<UUID?>,
                highlightedZoneIds: Set<UUID> = [],
                onRemove: @escaping (UUID) -> Void,
                onMove: @escaping (IndexSet, Int) -> Void = { _, _ in }) {
        self.zones = zones
        self.referenceMoment = referenceMoment
        self._editingZoneId = editingZoneId
        self.highlightedZoneIds = highlightedZoneIds
        self.onRemove = onRemove
        self.onMove = { from, to in
            onMove(IndexSet(integer: from), to)
        }
    }

    public var body: some View {
        ScrollView(.horizontal) {
            ZoneCardCollection(
                axis: .horizontal,
                zones: zones,
                referenceMoment: referenceMoment,
                editingZoneId: $editingZoneId,
                highlightedZoneIds: highlightedZoneIds,
                onRemove: onRemove,
                onMove: { source, destination in
                    guard let sourceIndex = source.first else { return }
                    onMove(sourceIndex, destination)
                }
            )
        }
        .scrollIndicators(.hidden)
    }
}
