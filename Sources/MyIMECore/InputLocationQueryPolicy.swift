import Foundation

public enum InputLocationQueryPolicy {
    public static func characterIndices(
        markedRange: NSRange,
        selectedRange: NSRange
    ) -> [Int] {
        guard markedRange.location != NSNotFound else {
            // IMKTextInput expects 0 when there is no inline session
            return [0]
        }

        var indices: [Int] = []
        if selectedRange.location != NSNotFound {
            let relativeSelection = selectedRange.location - markedRange.location
            if relativeSelection >= 0, relativeSelection <= markedRange.length {
                indices.append(relativeSelection)
            }
        }
        for fallback in [markedRange.length, 0] where !indices.contains(fallback) {
            indices.append(fallback)
        }
        return indices
    }

    public static func characterIndex(for selectedRange: NSRange) -> Int {
        0
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
