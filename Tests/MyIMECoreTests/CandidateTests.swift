import Testing
@testable import MyIMECore

@Suite
struct CandidateTests {
    @Test
    func exposesDisplayAndCommitTextWithoutChangingStoredRepresentation() {
        let encoded = DictionaryCandidateRepresentation.encoded(
            display: "表示",
            value: "https://example.com"
        )!
        let candidate = Candidate(
            storageText: encoded,
            source: .userDictionary,
            reading: "hyouji"
        )

        #expect(candidate.storageText == encoded)
        #expect(candidate.displayText == "表示")
        #expect(candidate.commitText == "https://example.com")
    }

    @Test
    func keepsDifferentOriginsWhenVisibleTextIsDeduplicated() {
        let dictionary = Candidate(
            storageText: "候補",
            source: .basicDictionary
        )
        let external = Candidate(
            storageText: "候補",
            source: .externalSuggestion,
            isLearnable: true
        )

        let merged = dictionary.mergingOrigins(from: external)

        #expect(merged.sources == [.basicDictionary, .externalSuggestion])
        #expect(merged.primarySource == .basicDictionary)
        #expect(merged.isLearnable)
    }
}
