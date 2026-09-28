import Foundation

public enum InputLocationQueryPolicy {
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
}
