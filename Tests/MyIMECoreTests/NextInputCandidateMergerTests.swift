import Testing
@testable import MyIMECore

@Suite
struct NextInputCandidateMergerTests {
    @Test
    func placesCalculatorResultBeforeLearnedCandidates() {
        #expect(
            NextInputCandidateMerger.merged(
                preferred: ["3"],
                learned: ["次", "3"],
                limit: 3
            ) == ["3", "次"]
        )
    }

    @Test
    func respectsCandidateLimit() {
        #expect(
            NextInputCandidateMerger.merged(
                preferred: ["3"],
                learned: ["次", "候補"],
                limit: 2
            ) == ["3", "次"]
        )
    }
}
