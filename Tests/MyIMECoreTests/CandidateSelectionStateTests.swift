import Testing
@testable import MyIMECore

struct CandidateSelectionStateTests {
    @Test func resolvesAValidSelection() {
        let state = CandidateSelectionState(
            values: ["候補1", "候補2"],
            selectedIndex: 1
        )
        #expect(state.selectedValue == "候補2")
    }

    @Test func rejectsAnInvalidSelectionWithoutChangingCandidates() {
        let state = CandidateSelectionState(
            values: ["候補"],
            selectedIndex: 2
        )
        #expect(state.selectedValue == nil)
        #expect(state.values == ["候補"])
    }

    @Test func resetsCandidatesAndSelectionTogether() {
        var state = CandidateSelectionState(
            values: ["候補"],
            selectedIndex: 0
        )
        state.reset()
        #expect(state == CandidateSelectionState<String>())
    }
}
