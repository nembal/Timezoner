import Foundation
import TimeZonerLib

func runZoneCardOrderingTests() {
    print("Running ZoneCardOrderingTests...")

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
}
