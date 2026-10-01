import Testing
@testable import MyIMECore

@Suite
struct CandidateSessionTests {
    @Test
    func preservesSelectedCandidateAcrossReordering() {
        var session = CandidateSession()
        session.replace(
            with: ["候補", "公募"].map { Candidate(storageText: $0) },
            input: "kouho",
            reading: "kouho"
        )
        session.selectedIndex = 1

        session.replace(
            with: ["公募", "候補"].map { Candidate(storageText: $0) },
            input: "kouho",
            reading: "kouho"
        )

        #expect(session.selectedIndex == 0)
        #expect(session.selectedCandidate?.storageText == "公募")
    }

    @Test
    func filteringAndRestorationKeepCandidateMetadata() {
        var session = CandidateSession()
        session.replace(
            with: [
                Candidate(
                    storageText: "候補",
                    source: .particleComposition,
                    isLearnable: true,
                    attributes: [.generated]
                ),
                Candidate(storageText: "公募", source: .basicDictionary)
            ],
            input: "kouho",
            reading: "kouho"
        )
        session.beginFiltering()
        session.applyFilteredTexts(["公募"])
        let restored = session.restoreUnfilteredCandidates()
        #expect(restored)

        #expect(session.candidates[0].isLearnable)
        #expect(session.candidates[0].hasAttribute(.generated))
    }
}
