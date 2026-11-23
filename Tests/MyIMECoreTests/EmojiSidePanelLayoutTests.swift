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

    private func variation(
        cell: CGRect,
        left: Bool,
        down: Bool,
        comparison: CGRect? = nil,
        screen: CGRect? = nil
    ) -> CGRect {
        let size = CGSize(width: 240, height: 52)
        return EmojiSidePanelLayout.variationFrame(
            cell: cell,
            size: size,
            baseCenterX: left ? size.width - 8 - 18 : 8 + 18,
            expandsLeft: left,
            expandsDown: down,
            baseOffset: 18,
            gap: 2,
            avoiding: comparison,
            visibleFrame: screen ?? self.screen,
            spacing: 8
        )
    }

    /// The base emoji, at the end nearest the selected emoji, sits half an
    /// emoji beside it, below or above as the emoji panel opened
    @Test(arguments: [(true, true), (true, false), (false, true), (false, false)])
    func theVariationsOpenDiagonally(left: Bool, down: Bool) {
        let emoji = cell(column: 3, row: 2)
        let frame = variation(cell: emoji, left: left, down: down)
        let baseCenter = left ? frame.maxX - 8 - 18 : frame.minX + 8 + 18
        #expect(baseCenter == emoji.midX + (left ? -18 : 18))
        if down {
            #expect(frame.maxY == emoji.minY - 2)
        } else {
            #expect(frame.minY == emoji.maxY + 2)
        }
    }

    /// At the screen's edge they move only as far as needed, and never
    /// onto the comparison
    @Test
    func atTheScreenEdgeTheyMoveInAndStayOffTheComparison() {
        let edge = CGRect(x: 0, y: 400, width: 36, height: 36)
        let frame = variation(cell: edge, left: true, down: true)
        #expect(frame.minX == screen.minX)

        let comparison = CGRect(x: 348, y: 552, width: 240, height: 88)
        let near = CGRect(x: 300, y: 600, width: 36, height: 36)
        let moved = variation(cell: near, left: false, down: true, comparison: comparison)
        #expect(!moved.intersects(comparison))
    }
}
