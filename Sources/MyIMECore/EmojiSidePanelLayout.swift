import CoreGraphics

/// Where the emoji panel's variations and platform comparison go beside
/// the panel, which itself never moves. The variations keep beside the
/// emoji they belong to; the comparison keeps to the panel's top. Beside
/// the panel come the variations, then the comparison, on one side kept
/// while it fits; without room, the two go on either side of the panel,
/// and only then one above the other
///
/// The comparison's place depends on whether a column is kept for the
/// variations, never on how wide they are, so moving between emoji does
/// not push it about
public enum EmojiSidePanelLayout {
    public enum Side: Equatable, Sendable {
        case right
        case left
    }

    public struct Frames: Equatable, Sendable {
        public let variation: CGRect?
        public let comparison: CGRect?
        /// The side both went on, to be kept next time; nil when they had
        /// to be split or stacked
        public let side: Side?
    }

    /// `variationTop` is the top of the emoji the variations belong to.
    /// `keepsVariationColumn` keeps the column while the variations are
    /// about to show, so the comparison stays where it will be
    public static func frames(
        panel: CGRect,
        variationSize: CGSize?,
        variationTop: CGFloat,
        variationColumnWidth: CGFloat,
        keepsVariationColumn: Bool,
        comparisonSize: CGSize?,
        preferredSide: Side?,
        visibleFrame visible: CGRect,
        spacing: CGFloat
    ) -> Frames {
        func y(top: CGFloat, height: CGFloat) -> CGFloat {
            min(max(top - height, visible.minY), visible.maxY - height)
        }
        func fits(_ frame: CGRect?) -> Bool {
            frame.map { visible.insetBy(dx: -0.5, dy: -0.5).contains($0) } ?? true
        }
        func apart(_ variation: CGRect?, _ comparison: CGRect?) -> Bool {
            guard let variation, let comparison else { return true }
            return !variation.intersects(comparison)
        }
        func beside(_ size: CGSize, top: CGFloat, side: Side, gap: CGFloat = 0) -> CGRect {
            CGRect(
                x: side == .right
                    ? panel.maxX + spacing + gap
                    : panel.minX - spacing - gap - size.width,
                y: y(top: top, height: size.height),
                width: size.width,
                height: size.height
            )
        }

        let usesColumn = variationSize != nil || keepsVariationColumn
        let comparisonGap = usesColumn ? variationColumnWidth + spacing : 0
        // In a row on one side: a side the whole row fits on comes first, so
        // the side does not change when the variations show; then the side
        // used last
        func fitsWholeRow(_ side: Side) -> Bool {
            let width = variationColumnWidth + spacing
                + (comparisonSize?.width ?? 0) + spacing
            return side == .right
                ? panel.maxX + width <= visible.maxX + 0.5
                : panel.minX - width >= visible.minX - 0.5
        }
        let preferred: [Side] = preferredSide == .left ? [.left, .right] : [.right, .left]
        let sides = preferred.filter(fitsWholeRow) + preferred.filter { !fitsWholeRow($0) }
        for side in sides {
            let variation = variationSize.map {
                beside($0, top: variationTop, side: side)
            }
            let comparison = comparisonSize.map {
                beside($0, top: panel.maxY, side: side, gap: comparisonGap)
            }
            // The column kept for the variations must fit as well
            let column = usesColumn
                ? beside(
                    CGSize(width: variationColumnWidth, height: 1),
                    top: panel.maxY,
                    side: side
                )
                : nil
            if fits(variation), fits(comparison), fits(column) {
                return Frames(variation: variation, comparison: comparison, side: side)
            }
        }

        // On either side of the panel, each beside it
        for side in sides {
            let other: Side = side == .right ? .left : .right
            let variation = variationSize.map {
                beside($0, top: variationTop, side: side)
            }
            let comparison = comparisonSize.map {
                beside($0, top: panel.maxY, side: variationSize == nil ? side : other)
            }
            if fits(variation), fits(comparison) {
                return Frames(variation: variation, comparison: comparison, side: nil)
            }
        }

        // One above the other on one side
        if let variationSize, let comparisonSize {
            for side in sides {
                let comparison = beside(comparisonSize, top: panel.maxY, side: side)
                for variationOriginY in [
                    comparison.minY - spacing - variationSize.height,
                    comparison.maxY + spacing
                ] {
                    var variation = beside(variationSize, top: variationTop, side: side)
                    variation.origin.y = variationOriginY
                    if fits(variation), fits(comparison), apart(variation, comparison) {
                        return Frames(variation: variation, comparison: comparison, side: nil)
                    }
                }
            }
        }

        func clamped(_ frame: CGRect) -> CGRect {
            CGRect(
                x: min(max(frame.minX, visible.minX), visible.maxX - frame.width),
                y: frame.minY,
                width: frame.width,
                height: frame.height
            )
        }
        return Frames(
            variation: variationSize.map {
                clamped(beside($0, top: variationTop, side: sides[0]))
            },
            comparison: comparisonSize.map {
                clamped(beside($0, top: panel.maxY, side: sides[0], gap: comparisonGap))
            },
            side: nil
        )
    }
}
