import CoreGraphics
import Testing
@testable import MyIMECore

@Suite
struct EmojiSidePanelLayoutTests {
    private let screen = CGRect(x: 0, y: 0, width: 1440, height: 900)
    private let panel = CGRect(x: 100, y: 400, width: 240, height: 240)
    private let variation = CGSize(width: 160, height: 52)

    private func cell(column: Int, row: Int) -> CGRect {
        CGRect(
            x: panel.minX + 8 + CGFloat(column) * 38,
            y: panel.maxY - 8 - 36 - CGFloat(row) * 38,
            width: 36,
            height: 36
        )
    }

    @Test
    func theComparisonSitsBesideThePanelAtItsTop() {
        let frame = EmojiSidePanelLayout.comparisonFrame(
            panel: panel,
            size: CGSize(width: 240, height: 88),
            visibleFrame: screen,
            spacing: 8
        )
        #expect(frame == CGRect(x: 348, y: 552, width: 240, height: 88))
    }

    @Test
    func atTheRightEdgeTheComparisonGoesLeft() {
        let edge = CGRect(x: 1190, y: 400, width: 240, height: 240)
        let frame = EmojiSidePanelLayout.comparisonFrame(
            panel: edge,
            size: CGSize(width: 240, height: 88),
            visibleFrame: screen,
            spacing: 8
        )
        #expect(frame.maxX == edge.minX - 8)
    }

    /// Over the panel just below the emoji, which stays in view
    @Test
    func theVariationsGoJustBelowTheirEmoji() {
        let emoji = cell(column: 2, row: 1)
        let frame = EmojiSidePanelLayout.variationFrame(
            cell: emoji, size: variation, panel: panel, gap: 2
        )
        #expect(frame.maxY == emoji.minY - 2)
        #expect(!frame.intersects(emoji))
        #expect(panel.contains(frame))
    }

    /// In the bottom row they go above; in a corner they stay inside
    @Test(arguments: [(0, 5), (5, 5), (0, 0), (5, 0)])
    func inEveryCornerTheyStayInsideAndLeaveTheEmojiInView(column: Int, row: Int) {
        let emoji = cell(column: column, row: row)
        let frame = EmojiSidePanelLayout.variationFrame(
            cell: emoji, size: variation, panel: panel, gap: 2
        )
        #expect(panel.contains(frame))
        #expect(!frame.intersects(emoji))
    }
}
