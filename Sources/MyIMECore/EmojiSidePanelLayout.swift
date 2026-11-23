import CoreGraphics

/// Where the emoji panel's variations and platform comparison go beside
/// it, considered together so neither covers the other or the panel: the
/// variations next to the panel and the comparison outside them, on the
/// right or else the left, then stacked in one column, then on either side
public enum EmojiSidePanelLayout {
    public struct Frames: Equatable, Sendable {
        public let variation: CGRect?
        public let comparison: CGRect?
    }

    /// `variationTop` is the top the variations take, beside the emoji
    /// they belong to; the comparison keeps to the panel's top
    public static func frames(
        panel: CGRect,
        variationSize: CGSize?,
        variationTop: CGFloat,
        comparisonSize: CGSize?,
        visibleFrame visible: CGRect,
        spacing: CGFloat
    ) -> Frames {
        func y(top: CGFloat, height: CGFloat) -> CGFloat {
            min(max(top - height, visible.minY), visible.maxY - height)
        }
        func fits(_ frame: CGRect) -> Bool {
            visible.insetBy(dx: -0.5, dy: -0.5).contains(frame)
        }
        func besides(_ size: CGSize, top: CGFloat) -> [CGRect] {
            let originY = y(top: top, height: size.height)
            return [
                CGRect(x: panel.maxX + spacing, y: originY,
                       width: size.width, height: size.height),
                CGRect(x: panel.minX - spacing - size.width, y: originY,
                       width: size.width, height: size.height)
            ]
        }
        func clamped(_ frame: CGRect) -> CGRect {
            CGRect(
                x: min(max(frame.minX, visible.minX), visible.maxX - frame.width),
                y: frame.minY,
                width: frame.width,
                height: frame.height
            )
        }

        guard let variationSize else {
            guard let comparisonSize else {
                return Frames(variation: nil, comparison: nil)
            }
            let options = besides(comparisonSize, top: panel.maxY)
            return Frames(
                variation: nil,
                comparison: options.first(where: fits) ?? clamped(options[0])
            )
        }
        let variations = besides(variationSize, top: variationTop)
        guard let comparisonSize else {
            return Frames(
                variation: variations.first(where: fits) ?? clamped(variations[0]),
                comparison: nil
            )
        }

        let comparisonY = y(top: panel.maxY, height: comparisonSize.height)
        var options: [(CGRect, CGRect)] = []
        // In a row: panel, variations, comparison, on the right or the left
        let right = variations[0]
        let left = variations[1]
        options.append((right, CGRect(
            x: right.maxX + spacing, y: comparisonY,
            width: comparisonSize.width, height: comparisonSize.height
        )))
        options.append((left, CGRect(
            x: left.minX - spacing - comparisonSize.width, y: comparisonY,
            width: comparisonSize.width, height: comparisonSize.height
        )))
        // In one column beside the panel, the comparison below or above
        for variation in [right, left] {
            let x = variation.minX < panel.minX
                ? panel.minX - spacing - comparisonSize.width
                : panel.maxX + spacing
            for comparisonOriginY in [
                variation.minY - spacing - comparisonSize.height,
                variation.maxY + spacing
            ] {
                options.append((variation, CGRect(
                    x: x, y: comparisonOriginY,
                    width: comparisonSize.width, height: comparisonSize.height
                )))
            }
        }
        // On either side of the panel
        let comparisons = besides(comparisonSize, top: panel.maxY)
        options.append((right, comparisons[1]))
        options.append((left, comparisons[0]))

        let chosen = options.first { variation, comparison in
            fits(variation) && fits(comparison)
                && !variation.intersects(comparison)
                && !variation.intersects(panel)
                && !comparison.intersects(panel)
        } ?? (clamped(options[0].0), clamped(options[0].1))
        return Frames(variation: chosen.0, comparison: chosen.1)
    }
}
