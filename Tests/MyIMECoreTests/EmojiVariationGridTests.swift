import CoreGraphics
import Testing
@testable import MyIMECore

@Suite
struct EmojiVariationGridTests {
    private func layout(_ count: Int, left: Bool, down: Bool) -> EmojiVariationGrid.Layout {
        EmojiVariationGrid.layout(
            count: count, columns: 6, cellSize: 36, spacing: 2, padding: 8,
            expandsLeft: left, expandsDown: down
        )
    }

    /// The same margin on every side, whichever way the panel opens
    @Test(arguments: [(true, true), (true, false), (false, true), (false, false)])
    func everySideHasTheSameMargin(left: Bool, down: Bool) {
        for count in [2, 6, 7, 26] {
            let grid = layout(count, left: left, down: down)
            let all = grid.frames.dropFirst().reduce(grid.frames[0]) { $0.union($1) }
            #expect(all.minX == 8)
            #expect(grid.size.width - all.maxX == 8)
            #expect(all.minY == 8)
            #expect(grid.size.height - all.maxY == 8)
        }
    }

    /// The base emoji sits in the corner nearest the selected emoji, with
    /// the rest of its row running away from it
    @Test
    func theBaseEmojiIsAtTheNearCorner() {
        let leftDown = layout(7, left: true, down: true)
        #expect(leftDown.frames[0].maxX == leftDown.size.width - 8)
        #expect(leftDown.frames[0].minY == 8)
        #expect(leftDown.frames[1].maxX < leftDown.frames[0].minX)
        // The partial second row keeps to the right too
        #expect(leftDown.frames[6].maxX == leftDown.size.width - 8)

        let rightUp = layout(7, left: false, down: false)
        #expect(rightUp.frames[0].minX == 8)
        #expect(rightUp.frames[0].maxY == rightUp.size.height - 8)
        #expect(rightUp.frames[6].minX == 8)
        #expect(rightUp.frames[6].minY == 8)
    }
}
