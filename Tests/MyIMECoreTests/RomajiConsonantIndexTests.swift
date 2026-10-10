import Testing
@testable import MyIMECore

@Suite
struct RomajiConsonantIndexTests {
    @Test
    func ranksTheClosestConsonantSequenceFirst() {
        let index = RomajiConsonantIndex(
            terms: ["dxyz", "dtbs", "abcd", "knnchh"]
        )

        #expect(index.rankedCandidateIdentifiers(
            for: "dtsbs",
            minimumSharedNGramCount: 2,
            limit: 1
        ) == [1])
    }

    @Test
    func retrievesMultipleConsonantSubstitutionsByStableMiddleBigrams() {
        let index = RomajiConsonantIndex(terms: ["knnchh", "abcdef"])

        #expect(index.rankedCandidateIdentifiers(
            for: "jnnchg",
            minimumSharedNGramCount: 2,
            limit: 2
        ).contains(0))
    }

    @Test
    func rejectsAReadingWithoutEnoughSharedStructure() {
        let index = RomajiConsonantIndex(terms: ["dtbs", "knnchh"])

        #expect(index.rankedCandidateIdentifiers(
            for: "qxzvbnm",
            minimumSharedNGramCount: 2,
            limit: 2
        ).isEmpty)
    }
}
