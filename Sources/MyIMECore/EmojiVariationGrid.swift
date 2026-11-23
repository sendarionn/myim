import CoreGraphics

/// Where each variation goes inside the variations panel, with the same
/// margin on every side. Rows of up to `columns`; the base emoji, the first
/// entry, sits in the corner nearest the selected emoji: its row comes
/// first when the panel opens down and last when it opens up, and when the
/// panel opens left each row is reversed and kept to the right
public enum EmojiVariationGrid {
    public struct Layout: Equatable, Sendable {
        public let size: CGSize
        /// Each entry's cell, by its index, from the top left
        public let frames: [CGRect]
    }

    public static func layout(
        count: Int,
        columns: Int,
        cellSize: CGFloat,
        spacing: CGFloat,
        padding: CGFloat,
        expandsLeft: Bool,
        expandsDown: Bool
    ) -> Layout {
        guard count > 0, columns > 0 else {
            return Layout(size: CGSize(width: padding * 2, height: padding * 2), frames: [])
        }
        let rows = (count + columns - 1) / columns
        let usedColumns = min(count, columns)
        let step = cellSize + spacing
        let size = CGSize(
            width: padding * 2 + CGFloat(usedColumns) * step - spacing,
            height: padding * 2 + CGFloat(rows) * step - spacing
        )
        let frames = (0..<count).map { index -> CGRect in
            let row = index / columns
            let position = CGFloat(index % columns)
            let shownRow = CGFloat(expandsDown ? row : rows - 1 - row)
            let x = expandsLeft
                ? size.width - padding - cellSize - position * step
                : padding + position * step
            return CGRect(
                x: x,
                y: padding + shownRow * step,
                width: cellSize,
                height: cellSize
            )
        }
        return Layout(size: size, frames: frames)
    }
}
