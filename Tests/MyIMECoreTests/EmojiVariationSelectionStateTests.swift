import Testing
@testable import MyIMECore

@Suite
struct EmojiVariationSelectionStateTests {
    @Test
    func selectingVariantBaseShowsOnceThenKeepsThePanel() {
        var state = EmojiVariationSelectionState()

        #expect(state.selectionChanged(to: "1f44d") == .show(
            baseCode: "1f44d"
        ))
        #expect(state.selectionChanged(to: "1f44d") == .keep)
    }

    @Test
    func selectingOrdinaryEmojiHidesVariations() {
        var state = EmojiVariationSelectionState()
        _ = state.selectionChanged(to: "1f44d")

        #expect(state.selectionChanged(to: nil) == .hide)
        #expect(state.presentedBaseCode == nil)
        #expect(state.suppressedBaseCode == nil)
    }

    @Test
    func escapeSuppressesOnlyTheCurrentSelection() {
        var state = EmojiVariationSelectionState()
        _ = state.selectionChanged(to: "1f44d")
        state.dismissCurrent()

        #expect(state.selectionChanged(to: "1f44d") == .hide)
        #expect(state.selectionChanged(to: "1f44b") == .show(
            baseCode: "1f44b"
        ))
    }

    @Test
    func clickingSuppressedSelectionReopensIt() {
        var state = EmojiVariationSelectionState()
        _ = state.selectionChanged(to: "1f44d")
        state.dismissCurrent()

        #expect(state.selectionChanged(
            to: "1f44d",
            reopensSuppressed: true
        ) == .show(baseCode: "1f44d"))
    }
}
