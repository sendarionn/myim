import Testing
@testable import MyIMECore

struct EmojiGridNavigatorTests {
    @Test func movesVerticallyInTheSameColumn() {
        #expect(next(10, .down) == 18)
        #expect(next(18, .up) == 10)
    }

    @Test func keepsHorizontalMovementInsideTheSameRow() {
        #expect(next(8, .left) == 8)
        #expect(next(15, .right) == 15)
    }

    @Test func doesNotMovePastAnIncompleteLastRow() {
        #expect(next(2_978, .down, itemCount: 2_980) == 2_978)
        #expect(next(2_979, .right, itemCount: 2_980) == 2_979)
    }

    private func next(
        _ index: Int,
        _ direction: EmojiGridDirection,
        itemCount: Int = 2_980
    ) -> Int {
        EmojiGridNavigator.nextIndex(
            from: index,
            direction: direction,
            itemCount: itemCount,
            columnCount: 8
        )
    }
}
