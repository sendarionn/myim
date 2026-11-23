import CoreGraphics

/// Where the emoji panel's two side panels go, each from its own anchor:
/// the variations over the panel at the emoji they belong to, and the
/// platform comparison outside the panel. Neither moves the panel, and as
/// one is inside the panel and the other outside, they never meet
public enum EmojiSidePanelLayout {
    /// Beside the panel with its top aligned, on the right unless the
    /// screen ends there; the variations do not move it
    public static func comparisonFrame(
        panel: CGRect,
        size: CGSize,
        visibleFrame visible: CGRect,
        spacing: CGFloat
    ) -> CGRect {
        let right = panel.maxX + spacing
        let left = panel.minX - spacing - size.width
        let x = right + size.width <= visible.maxX + 0.5 || left < visible.minX
            ? right
            : left
        return CGRect(
            x: x,
            y: min(max(panel.maxY - size.height, visible.minY), visible.maxY - size.height),
            width: size.width,
            height: size.height
        )
    }

    /// Whether the comparison went on the panel's right
    public static func comparisonIsOnRight(comparison: CGRect, panel: CGRect) -> Bool {
        comparison.minX >= panel.maxX
    }

    /// Diagonally from the emoji: down when the emoji panel opened
    /// downward and up when it opened upward, and away from the comparison.
    /// The base emoji, at the variations' end nearest the emoji, sits
    /// `baseOffset` beside the emoji's center; `baseCenterX` is that base's
    /// center from the variations' left edge. The variations then move only
    /// as far as the screen needs, and off the comparison
    public static func variationFrame(
        cell: CGRect,
        size: CGSize,
        baseCenterX: CGFloat,
        expandsLeft: Bool,
        expandsDown: Bool,
        baseOffset: CGFloat,
        gap: CGFloat,
        avoiding comparison: CGRect?,
        visibleFrame visible: CGRect,
        spacing: CGFloat
    ) -> CGRect {
        let baseCenter = cell.midX + (expandsLeft ? -baseOffset : baseOffset)
        var frame = CGRect(
            x: baseCenter - baseCenterX,
            y: expandsDown ? cell.minY - gap - size.height : cell.maxY + gap,
            width: size.width,
            height: size.height
        )
        frame.origin.x = min(
            max(frame.minX, visible.minX),
            max(visible.maxX - size.width, visible.minX)
        )
        frame.origin.y = min(
            max(frame.minY, visible.minY),
            max(visible.maxY - size.height, visible.minY)
        )
        if let comparison, frame.intersects(comparison) {
            frame.origin.x = comparison.minX >= cell.midX
                ? comparison.minX - spacing - size.width
                : comparison.maxX + spacing
        }
        return frame
    }
}
