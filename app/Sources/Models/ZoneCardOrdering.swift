import Foundation

public enum ZoneCardOrdering {
    public static func destination(
        sourceIndex: Int,
        originIndex: Int? = nil,
        translation: CGFloat,
        slotExtent: CGFloat,
        count: Int
    ) -> Int? {
        let originIndex = originIndex ?? sourceIndex
        guard count > 0,
              (0..<count).contains(sourceIndex),
              (0..<count).contains(originIndex),
              slotExtent.isFinite,
              slotExtent > 0,
              translation.isFinite else {
            return nil
        }

        let slotsToMove = Int((translation / slotExtent).rounded())
        let targetIndex = min(max(originIndex + slotsToMove, 0), count - 1)
        guard targetIndex != sourceIndex else { return nil }

        return targetIndex > sourceIndex ? targetIndex + 1 : targetIndex
    }
}
