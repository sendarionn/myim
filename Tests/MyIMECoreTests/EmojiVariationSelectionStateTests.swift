import Testing
@testable import MyIMECore

@Suite
struct EmojiVariationSelectionStateTests {
    @Test
    func keyboardSelectionSchedulesThenShowsThePanel() {
        var state = EmojiVariationSelectionState()

        #expect(EmojiVariationSelectionState.automaticPresentationDelay == 0.3)
        #expect(state.selectionChanged(to: "1f44d") == .schedule(
            baseCode: "1f44d",
            generation: 1
        ))
        #expect(state.selectionChanged(to: "1f44d") == .keep)
        let displayed = state.scheduledPresentationFired(
            for: "1f44d",
            generation: 1
        )
        #expect(displayed)
        #expect(state.selectionChanged(to: "1f44d") == .keep)
    }

    @Test
    func movingBeforeTheDelayInvalidatesTheOldSelection() {
        var state = EmojiVariationSelectionState()
        _ = state.selectionChanged(to: "1f44d")

        #expect(state.selectionChanged(to: "1f44b") == .schedule(
            baseCode: "1f44b",
            generation: 2
        ))
        let oldSelectionDisplayed = state.scheduledPresentationFired(
            for: "1f44d",
            generation: 1
        )
        let currentSelectionDisplayed = state.scheduledPresentationFired(
            for: "1f44b",
            generation: 2
        )
        #expect(!oldSelectionDisplayed)
        #expect(currentSelectionDisplayed)
    }

    @Test
    func staleReservationForTheSameBaseCannotFireEarly() {
        var state = EmojiVariationSelectionState()
        _ = state.selectionChanged(to: "1f44d")
        _ = state.selectionChanged(to: "1f44b")
        #expect(state.selectionChanged(to: "1f44d") == .schedule(
            baseCode: "1f44d",
            generation: 3
        ))

        let staleDisplayed = state.scheduledPresentationFired(
            for: "1f44d",
            generation: 1
        )
        let currentDisplayed = state.scheduledPresentationFired(
            for: "1f44d",
            generation: 3
        )
        #expect(!staleDisplayed)
        #expect(currentDisplayed)
    }

    @Test
    func mouseSelectionShowsThePanelImmediately() {
        var state = EmojiVariationSelectionState()

        #expect(state.selectionChanged(
            to: "1f44d",
            presentsImmediately: true
        ) == .show(baseCode: "1f44d"))
    }

    @Test
    func selectingOrdinaryEmojiHidesVariations() {
        var state = EmojiVariationSelectionState()
        _ = state.selectionChanged(to: "1f44d")
        _ = state.scheduledPresentationFired(
            for: "1f44d",
            generation: 1
        )

        #expect(state.selectionChanged(to: nil) == .hide)
        #expect(state.presentedBaseCode == nil)
        #expect(state.pendingBaseCode == nil)
        #expect(state.pendingGeneration == nil)
        #expect(state.suppressedBaseCode == nil)
    }

    @Test
    func escapeSuppressesOnlyTheCurrentSelection() {
        var state = EmojiVariationSelectionState()
        _ = state.selectionChanged(to: "1f44d")
        _ = state.scheduledPresentationFired(
            for: "1f44d",
            generation: 1
        )
        state.dismissCurrent()

        #expect(state.selectionChanged(to: "1f44d") == .hide)
        #expect(state.selectionChanged(to: "1f44b") == .schedule(
            baseCode: "1f44b",
            generation: 2
        ))
    }

    @Test
    func clickingSuppressedSelectionReopensIt() {
        var state = EmojiVariationSelectionState()
        _ = state.selectionChanged(to: "1f44d")
        _ = state.scheduledPresentationFired(
            for: "1f44d",
            generation: 1
        )
        state.dismissCurrent()

        #expect(state.selectionChanged(
            to: "1f44d",
            presentsImmediately: true
        ) == .show(baseCode: "1f44d"))
    }
}
