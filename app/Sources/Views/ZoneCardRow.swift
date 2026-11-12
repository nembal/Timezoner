import SwiftUI

public struct ZoneCardRow: View {
    public let zones: [ZoneInfo]
    public let referenceMoment: ReferenceMomentController
    @Binding public var editingZoneId: UUID?
    public let highlightedZoneIds: Set<UUID>
    public let highlightRequestID: UInt64
    public let onRemove: (UUID) -> Void
    public let onMove: (IndexSet, Int) -> Void

    @State private var viewportWidth: CGFloat = 0
    @State private var contentWidth: CGFloat = 0

    public init(zones: [ZoneInfo], referenceMoment: ReferenceMomentController, editingZoneId: Binding<UUID?>,
                highlightedZoneIds: Set<UUID> = [], highlightRequestID: UInt64 = 0,
                onRemove: @escaping (UUID) -> Void,
                onMove: @escaping (IndexSet, Int) -> Void = { _, _ in }) {
        self.zones = zones
        self.referenceMoment = referenceMoment
        self._editingZoneId = editingZoneId
        self.highlightedZoneIds = highlightedZoneIds
        self.highlightRequestID = highlightRequestID
        self.onRemove = onRemove
        self.onMove = onMove
    }

    private struct RevealRequest: Equatable {
        let target: UUID?
        let zoneIDs: [UUID]
        let requestID: UInt64
        let viewportWidth: CGFloat
        let contentWidth: CGFloat
    }

    private var revealRequest: RevealRequest {
        let highlighted = zones.filter { highlightedZoneIds.contains($0.id) }
        // A source/target conversion should show the result, with zone order
        // providing a stable fallback for duplicate aliases or source-only input.
        let target = highlighted.first { $0.timeZoneId != referenceMoment.timeState.sourceZoneId }
            ?? highlighted.first
        return RevealRequest(target: target?.id, zoneIDs: zones.map(\.id), requestID: highlightRequestID,
                             viewportWidth: viewportWidth, contentWidth: contentWidth)
    }

    public var body: some View {
        ScrollViewReader { proxy in
            ScrollView(.horizontal) {
                ZoneCardCollection(
                    axis: .horizontal,
                    zones: zones,
                    referenceMoment: referenceMoment,
                    editingZoneId: $editingZoneId,
                    highlightedZoneIds: highlightedZoneIds,
                    onRemove: onRemove,
                    onMove: onMove
                )
                .background {
                    GeometryReader { geometry in
                        Color.clear
                            .onAppear { contentWidth = geometry.size.width }
                            .onChange(of: geometry.size.width) { _, width in contentWidth = width }
                    }
                }
            }
            .scrollIndicators(.hidden)
            .background {
                GeometryReader { geometry in
                    Color.clear
                        .onAppear { viewportWidth = geometry.size.width }
                        .onChange(of: geometry.size.width) { _, width in viewportWidth = width }
                }
            }
            .task(id: revealRequest) {
                // Run after the identity update; measured layout changes also
                // retry this reveal when an appended card or panel resize settles.
                await Task.yield()
                guard !Task.isCancelled, let target = revealRequest.target else { return }
                proxy.scrollTo(target, anchor: .center)
            }
        }
    }
}
