import Testing
@testable import MyIMECore

@Suite
struct SymmetricDeleteIndexTests {
    @Test
    func findsInsertionDeletionAndSubstitutionCandidates() {
        let terms = ["hitsuyou", "susumete", "kakudai"]
        let index = SymmetricDeleteIndex(
            terms: terms,
            maximumDistance: 2
        )

        #expect(index.candidateIdentifiers(
            for: "hiruyou",
            maximumDistance: 2
        ).contains(0))
        #expect(index.candidateIdentifiers(
            for: "susmete",
            maximumDistance: 1
        ).contains(1))
    }

    @Test
    func includesOriginalAndDeletionKeys() {
        let keys = SymmetricDeleteIndex.keys(
            for: "abc",
            maximumDistance: 1
        )

        #expect(keys == ["abc", "bc", "ac", "ab"])
    }

    @Test
    func findsEveryTermSharingADeletionKey() {
        let index = SymmetricDeleteIndex(
            terms: ["abc", "abd", "xyz"],
            maximumDistance: 1
        )

        #expect(index.candidateIdentifiers(
            for: "ab",
            maximumDistance: 1
        ) == [0, 1])
    }
}
