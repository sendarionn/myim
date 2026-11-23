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

    /// Over the panel just below the emoji, or just above it where the
    /// panel ends below, leaving the emoji itself in view; centered on it
    /// and kept inside the panel
    public static func variationFrame(
        cell: CGRect,
        size: CGSize,
        panel: CGRect,
        gap: CGFloat
    ) -> CGRect {
        let below = cell.minY - gap - size.height
        let above = cell.maxY + gap
        let y: CGFloat
        if below >= panel.minY {
            y = below
        } else if above + size.height <= panel.maxY {
            y = above
        } else {
            // Taller than the room on either side: the side with more room,
            // kept inside the panel
            y = cell.minY - panel.minY >= panel.maxY - cell.maxY
                ? max(below, panel.minY)
                : min(above, panel.maxY - size.height)
        }
        let x = min(
            max(cell.midX - size.width / 2, panel.minX),
            max(panel.maxX - size.width, panel.minX)
        )
        return CGRect(x: x, y: y, width: size.width, height: size.height)
    }
}
