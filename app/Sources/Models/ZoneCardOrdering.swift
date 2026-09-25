import Foundation

public enum ZoneCardOrdering {
    public static func destination(
        sourceIndex: Int,
        translation: CGFloat,
        slotExtent: CGFloat,
        count: Int
    ) -> Int? {
        guard count > 0,
              (0..<count).contains(sourceIndex),
              slotExtent.isFinite,
              slotExtent > 0,
              translation.isFinite else {
            return nil
        }

        let slotsToMove = Int((translation / slotExtent).rounded())
        let targetIndex = min(max(sourceIndex + slotsToMove, 0), count - 1)
        guard targetIndex != sourceIndex else { return nil }

        return targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
    }
}
