import Foundation

public enum InputLocationQueryPolicy {
    public static func characterIndices(
        markedRange: NSRange,
        selectedRange: NSRange
    ) -> [Int] {
        var indices: [Int] = []
        if markedRange.location != NSNotFound {
            indices.append(markedRange.location)
        }
        if selectedRange.location != NSNotFound,
           !indices.contains(selectedRange.location) {
            indices.append(selectedRange.location)
        }
        return indices.isEmpty ? [0] : indices
    }

    public static func characterIndex(for selectedRange: NSRange) -> Int {
        selectedRange.location == NSNotFound ? 0 : selectedRange.location
    }

    public static func isValidRectangle(
        x: Double,
        y: Double,
        width: Double,
        height: Double
    ) -> Bool {
        x.isFinite
            && y.isFinite
            && width.isFinite
            && height.isFinite
            && width >= 0
            && height > 0
    }

    public static func isTopLeftScreenPlaceholder(
        x: Double,
        y: Double,
        width: Double,
        height: Double,
        screenMinX: Double,
        screenMaxY: Double,
        maximumTopInset: Double = 160,
        tolerance: Double = 1
    ) -> Bool {
        let topInset = screenMaxY - (y + height)
        return abs(x - screenMinX) <= tolerance
            && width <= 2
            && topInset >= -tolerance
            && topInset <= maximumTopInset
    }
}
