import Foundation
import SwiftUI
import TimeZonerLib

func runZoneCardOrderingTests() {
    print("Running ZoneCardOrderingTests...")

    workspaceExpect(
        ZoneCardHeaderLayout.usesSeparateActionRow(for: 180),
        "narrow cards reserve a separate row for header actions instead of overlapping the title"
    )
    workspaceExpect(
        ZoneCardHeaderLayout.usesSeparateActionRow(for: CalendarPanelMetrics.normalCardWidth),
        "normal 200-point cards put actions below the city name and GMT offset"
    )
    workspaceExpect(
        !ZoneCardHeaderLayout.usesSeparateActionRow(for: 300),
        "wide cards keep header actions inline without adding vertical space"
    )

    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 1, translation: 74, slotExtent: 150, count: 4) == nil,
        "dragging short of the rounded slot threshold does not reorder"
    )
    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 1, translation: 150, slotExtent: 150, count: 4) == 3,
        "dragging one horizontal slot right uses the onMove insertion index"
    )
    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 2, translation: -150, slotExtent: 150, count: 4) == 1,
        "dragging one vertical slot left uses the onMove insertion index"
    )
    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 0, translation: -150, slotExtent: 150, count: 4) == nil,
        "dragging left past the first edge does not reorder"
    )
    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 3, translation: 150, slotExtent: 150, count: 4) == nil,
        "dragging right past the last edge does not reorder"
    )
    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: -1, translation: 150, slotExtent: 150, count: 4) == nil,
        "invalid source indices are ignored"
    )
    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 1, translation: 150, slotExtent: 0, count: 4) == nil,
        "zero slot extent is ignored"
    )

    let firstMove = ZoneCardOrdering.destination(sourceIndex: 1, translation: 150, slotExtent: 150, count: 4)
    let repeatedMove = ZoneCardOrdering.destination(sourceIndex: 2, originIndex: 1,
                                                    translation: 150, slotExtent: 150, count: 4)
    workspaceExpect(firstMove == 3 && repeatedMove == nil,
                    "unchanged cumulative drag translation moves the same card only one slot")

    let firstMoveEarlier = ZoneCardOrdering.destination(sourceIndex: 2, translation: -150, slotExtent: 150, count: 4)
    let repeatedMoveEarlier = ZoneCardOrdering.destination(sourceIndex: 1, originIndex: 2,
                                                           translation: -150, slotExtent: 150, count: 4)
    workspaceExpect(firstMoveEarlier == 1 && repeatedMoveEarlier == nil,
                    "unchanged cumulative drag translation cannot repeatedly move earlier")

    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 2, originIndex: 1,
                                     translation: 300, slotExtent: 150, count: 4) == 4,
        "two slots of cumulative translation move the card from index one to index three"
    )

    workspaceExpect(
        ZoneCardOrdering.destination(sourceIndex: 2, originIndex: 1,
                                     translation: 0, slotExtent: 150, count: 4) == 1,
        "reversing the gesture to zero moves the card back to its original slot"
    )

    let zone = ZoneInfo(label: "Tokyo", timeZoneId: "Asia/Tokyo")
    let otherZone = ZoneInfo(label: "Paris", timeZoneId: "Europe/Paris")
    let suiteName = "ZoneCardOrderingTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suiteName)!
    defer { defaults.removePersistentDomain(forName: suiteName) }
    let store = ZoneStore(userDefaults: defaults)
    store.zones = [zone, otherZone]
    var editingZoneId: UUID?
    let card = ZoneCard(
        zone: zone,
        referenceMoment: ReferenceMomentController(timeState: TimeState()),
        isSource: false,
        editingZoneId: Binding(get: { editingZoneId }, set: { editingZoneId = $0 }),
        canMoveEarlier: false,
        canMoveLater: true,
        onRemove: { store.remove(id: zone.id) },
        onMoveEarlier: { store.move(from: IndexSet(integer: 0), to: 2) },
        onMoveLater: { store.move(from: IndexSet(integer: 0), to: 2) }
    )
    card.performAccessibilityAction(.editTime)
    workspaceExpect(editingZoneId == zone.id, "the card's edit action enters the shared time editor")
    card.performAccessibilityAction(.moveEarlier)
    workspaceExpect(store.zones.map(\.label) == ["Tokyo", "Paris"],
                    "an unavailable earlier action cannot reorder beyond the first card")
    card.performAccessibilityAction(.moveLater)
    workspaceExpect(store.zones.map(\.label) == ["Paris", "Tokyo"],
                    "the card's later action reorders the real zone store")
    let cardAtEnd = ZoneCard(
        zone: zone,
        referenceMoment: ReferenceMomentController(timeState: TimeState()),
        isSource: false,
        editingZoneId: Binding(get: { editingZoneId }, set: { editingZoneId = $0 }),
        canMoveEarlier: true,
        canMoveLater: false,
        onRemove: { store.remove(id: zone.id) },
        onMoveEarlier: { store.move(from: IndexSet(integer: 1), to: 0) },
        onMoveLater: { store.move(from: IndexSet(integer: 1), to: 0) }
    )
    cardAtEnd.performAccessibilityAction(.moveEarlier)
    workspaceExpect(store.zones.map(\.label) == ["Tokyo", "Paris"],
                    "the available earlier action restores the city's position in the real zone store")
    cardAtEnd.performAccessibilityAction(.moveLater)
    workspaceExpect(store.zones.map(\.label) == ["Tokyo", "Paris"],
                    "an unavailable later action cannot reorder beyond the last card")
    cardAtEnd.performAccessibilityAction(.remove)
    workspaceExpect(store.zones.map(\.label) == ["Paris"],
                    "the card's remove action removes the city from the real zone store")
}
