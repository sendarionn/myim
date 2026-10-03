import Testing
@testable import MyIMECore

@Suite
struct CandidateSelectionProjectionTests {
    @Test
    func usesCommitTextForMarkedTextPreview() throws {
        let stored = try #require(DictionaryCandidateRepresentation.encoded(
            display: "Google",
            value: "https://www.google.com/"
        ))
        let candidate = Candidate(storageText: stored)

        #expect(CandidateSelectionProjection.markedText(
            for: candidate,
            prefix: "前",
            suffix: "後"
        ) == "前https://www.google.com/後")
    }

    @Test
    func preferredIndexKeepsCandidatesWithSameDisplayTextDistinct() throws {
        let first = try #require(DictionaryCandidateRepresentation.encoded(
            display: "同じ表示",
            value: "AAA"
        ))
        let second = try #require(DictionaryCandidateRepresentation.encoded(
            display: "同じ表示",
            value: "BBB"
        ))
        let candidates = [Candidate(storageText: first), Candidate(storageText: second)]

        #expect(CandidateSelectionProjection.index(
            for: "同じ表示",
            preferredIndex: 0,
            in: candidates
        ) == 0)
        #expect(CandidateSelectionProjection.index(
            for: "同じ表示",
            preferredIndex: 1,
            in: candidates
        ) == 1)
        #expect(CandidateSelectionProjection.index(
            for: "同じ表示",
            preferredIndex: nil,
            in: candidates
        ) == nil)
    }

    @Test
    func candidateMovementChangesPreviewAndCancellationClearsSelection() throws {
        let google = try #require(DictionaryCandidateRepresentation.encoded(
            display: "Google",
            value: "https://www.google.com/"
        ))
        let gmail = try #require(DictionaryCandidateRepresentation.encoded(
            display: "Gmail",
            value: "https://mail.google.com/"
        ))
        var session = CandidateSession()
        session.candidates = [
            Candidate(storageText: google),
            Candidate(storageText: gmail)
        ]

        session.selectedIndex = 0
        #expect(session.selectedCandidate.map {
            CandidateSelectionProjection.markedText(for: $0)
        } == "https://www.google.com/")

        session.selectedIndex = 1
        #expect(session.selectedCandidate.map {
            CandidateSelectionProjection.markedText(for: $0)
        } == "https://mail.google.com/")

        session.selectedIndex = nil
        #expect(session.selectedCandidate == nil)
    }

    @Test
    func normalCandidateUsesSameTextForDisplayAndCommit() {
        let candidate = Candidate(storageText: "知る")

        #expect(candidate.displayText == "知る")
        #expect(CandidateSelectionProjection.markedText(for: candidate) == "知る")
    }
}
