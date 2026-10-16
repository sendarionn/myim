import Testing
@testable import MyIMECore

@Suite
struct ClosingBracketPanelUpdateTests {
    @Test
    func repositionsTheVisiblePanelWhenTheCandidateIsUnchanged() {
        #expect(ClosingBracketPanelUpdate.resolve(
            currentContext: "structuralClosingBracket",
            currentCandidates: ["」"],
            isPanelVisible: true,
            refreshedCandidate: "」"
        ) == .reposition)
    }

    @Test
    func replacesTheCandidateWhenTheRequiredBracketChanges() {
        #expect(ClosingBracketPanelUpdate.resolve(
            currentContext: "structuralClosingBracket",
            currentCandidates: ["」"],
            isPanelVisible: true,
            refreshedCandidate: "）"
        ) == .present("）"))
    }

    @Test
    func dismissesTheStructuralPanelWhenNoBracketRemains() {
        #expect(ClosingBracketPanelUpdate.resolve(
            currentContext: "structuralClosingBracket",
            currentCandidates: ["」"],
            isPanelVisible: true,
            refreshedCandidate: nil
        ) == .dismiss)
    }

    @Test
    func leavesAnUnrelatedNextInputPanelAlone() {
        #expect(ClosingBracketPanelUpdate.resolve(
            currentContext: "ordinaryContext",
            currentCandidates: ["候補"],
            isPanelVisible: true,
            refreshedCandidate: nil
        ) == .unchanged)
    }

    @Test
    func presentsAnUnchangedCandidateWhenItsPanelIsHidden() {
        #expect(ClosingBracketPanelUpdate.resolve(
            currentContext: "structuralClosingBracket",
            currentCandidates: ["」"],
            isPanelVisible: false,
            refreshedCandidate: "」"
        ) == .present("」"))
    }
}
