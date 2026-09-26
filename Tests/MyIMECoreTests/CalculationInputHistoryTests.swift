import Testing
@testable import MyIMECore

@Suite
struct CalculationInputHistoryTests {
    @Test
    func storesExpressionInsteadOfSelectedAnswer() {
        #expect(CalculationInputHistory.value(
            input: "1+2=",
            selectedCandidate: "3",
            generatedCandidates: ["3"]
        ) == "1+2=")
    }

    @Test
    func preservesSpacesInExpression() {
        #expect(CalculationInputHistory.value(
            input: "1 + 2 = ",
            selectedCandidate: "3",
            generatedCandidates: ["3"]
        ) == "1 + 2 = ")
    }

    @Test
    func doesNotChangeHistoryForNonCalculationCandidate() {
        #expect(CalculationInputHistory.value(
            input: "1+2=",
            selectedCandidate: "別候補",
            generatedCandidates: ["3"]
        ) == nil)
    }

    @Test
    func restoresPreviouslyUsedExpressionFromItsPrefix() {
        var history = CandidateSelectionHistory()
        history.record("1+2=", reading: "1+2=")
        history.record("通常候補", reading: "1+abc")

        #expect(CalculationInputHistory.completionCandidates(
            input: "1+",
            historyCandidates: history.completions(for: "1+")
        ) == ["1+2="])
    }
}
