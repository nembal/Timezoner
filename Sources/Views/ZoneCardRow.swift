import SwiftUI

public struct ZoneCardRow: View {
    public let zones: [ZoneInfo]
    @Bindable public var timeState: TimeState
    @Binding public var editingZoneId: UUID?
    public let onRemove: (UUID) -> Void
    public let onMove: (IndexSet, Int) -> Void

    @State private var draggingZone: ZoneInfo?

    public init(zones: [ZoneInfo], timeState: TimeState, editingZoneId: Binding<UUID?>, onRemove: @escaping (UUID) -> Void, onMove: @escaping (IndexSet, Int) -> Void = { _, _ in }) {
        self.zones = zones
        self.timeState = timeState
        self._editingZoneId = editingZoneId
        self.onRemove = onRemove
        self.onMove = onMove
    }

    public var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(zones.enumerated()), id: \.element.id) { index, zone in
                ZoneCard(
                    zone: zone,
                    timeState: timeState,
                    isSource: timeState.sourceZoneId == zone.timeZoneId,
                    editingZoneId: $editingZoneId,
                    onRemove: {
                        withAnimation(.easeInOut(duration: 0.3)) {
                            onRemove(zone.id)
                        }
                    }
                )
                .frame(maxWidth: .infinity)
                .opacity(draggingZone?.id == zone.id ? 0.4 : 1)
                .draggable(zone.id.uuidString) {
                    // Drag preview
                    Text(zone.label)
                        .font(.system(size: 12, weight: .medium, design: .rounded))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Theme.cardBg, in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                        .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Theme.accent.opacity(0.3), lineWidth: 1))
                        .shadow(color: Theme.shadow, radius: 4, y: 2)
                        .onAppear { draggingZone = zone }
                }
                .dropDestination(for: String.self) { items, _ in
                    guard let droppedIdStr = items.first,
                          let droppedId = UUID(uuidString: droppedIdStr),
                          let fromIndex = zones.firstIndex(where: { $0.id == droppedId }),
                          let toIndex = zones.firstIndex(where: { $0.id == zone.id }),
                          fromIndex != toIndex else { return false }

                    withAnimation(.easeInOut(duration: 0.25)) {
                        let dest = toIndex > fromIndex ? toIndex + 1 : toIndex
                        onMove(IndexSet(integer: fromIndex), dest)
                    }
                    draggingZone = nil
                    return true
                } isTargeted: { targeted in
                    // Optional: highlight drop target
                }
                .transition(.asymmetric(
                    insertion: .move(edge: .trailing).combined(with: .opacity),
                    removal: .opacity
                ))

                if index < zones.count - 1 {
                    timeDiffLabel(from: zone, to: zones[index + 1])
                }
            }
        }
        .onChange(of: draggingZone) { _, newValue in
            if newValue != nil {
                editingZoneId = nil // exit edit mode when dragging
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
