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

    @Test
    func retainsAllLearnedCandidatesAfterPreferredCandidates() {
        let learned = (0..<16).map { "履歴候補\($0)" }

        #expect(
            NextInputCandidateMerger.merged(
                preferred: ["計算結果"],
                learned: learned,
                limit: 17
            ) == ["計算結果"] + learned
        )
    }
}
