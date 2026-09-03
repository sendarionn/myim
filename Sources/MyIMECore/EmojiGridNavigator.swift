public enum EmojiGridDirection {
    case left
    case right
    case up
    case down
}

public enum EmojiGridNavigator {
    public static func nextIndex(
        from index: Int,
        direction: EmojiGridDirection,
        itemCount: Int,
        columnCount: Int
    ) -> Int {
        guard itemCount > 0,
              columnCount > 0,
              (0..<itemCount).contains(index) else {
            return index
        }
        let rowStart = index / columnCount * columnCount
        let rowEnd = min(rowStart + columnCount - 1, itemCount - 1)
        switch direction {
        case .left:
            return max(index - 1, rowStart)
        case .right:
            return min(index + 1, rowEnd)
        case .up:
            return index >= columnCount ? index - columnCount : index
        case .down:
            let candidate = index + columnCount
            return candidate < itemCount ? candidate : index
        }
    }
}
