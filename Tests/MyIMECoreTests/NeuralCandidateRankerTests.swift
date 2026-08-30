import Testing
@testable import MyIMECore

struct NeuralCandidateRankerTests {
    @Test func promotesContextMatchesAheadOfMostRecentCandidate() {
        #expect(NeuralCandidateRanker.ordered(
            ["計る", "測る", "図る", "量る"],
            neuralCandidates: ["測る", "量る"]
        ) == ["測る", "量る", "計る", "図る"])
    }

    @Test func canExplicitlyProtectCandidatesFromNeuralReordering() {
        #expect(NeuralCandidateRanker.ordered(
            ["計る", "測る", "図る"],
            neuralCandidates: ["測る"],
            protectedPrefixCount: 1
        ) == ["計る", "測る", "図る"])
    }

    @Test func promotesOnlyCandidatesInsideCurrentCandidateSet() {
        #expect(NeuralCandidateRanker.ordered(
            ["公正", "校正"],
            neuralCandidates: ["恒星", "校正"]
        ) == ["校正", "公正"])
    }

    @Test func preservesOrderWithoutNeuralCandidates() {
        #expect(NeuralCandidateRanker.ordered(
            ["見る", "観る"],
            neuralCandidates: []
        ) == ["見る", "観る"])
    }
}
