import Testing
@testable import MyIMECore

@Suite
struct CalculationCandidateSetTests {
    @Test
    func excludesTheInputExpressionAndDuplicateResults() {
        #expect(CalculationCandidateSet.visible(
            generatedCandidates: ["1+2=", "3", "3", "約3.0"],
            input: "1+2="
        ) == ["3", "約3.0"])
    }
}
