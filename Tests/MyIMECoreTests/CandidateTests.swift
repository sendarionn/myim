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

    @Test
    func alternateCommitIndicatorDependsOnlyOnDisplayAndCommitText() throws {
        let normal = Candidate(
            storageText: "知る",
            source: .userDictionary
        )
        let encoded = try #require(DictionaryCandidateRepresentation.encoded(
            display: "Google",
            value: "https://www.google.com/"
        ))
        let javaScript = Candidate(
            storageText: encoded,
            source: .javaScriptExtension
        )

        #expect(!normal.hasDistinctCommitText)
        #expect(javaScript.hasDistinctCommitText)
        #expect(javaScript.displayText == "Google")
        #expect(javaScript.commitText == "https://www.google.com/")
    }

    @Test
    func duplicateDisplayTextKeepsIndependentIndicatorAndCommitIdentity() throws {
        let first = try #require(DictionaryCandidateRepresentation.encoded(
            display: "Google",
            value: "AAA"
        ))
        let second = try #require(DictionaryCandidateRepresentation.encoded(
            display: "Google",
            value: "BBB"
        ))
        let candidates = [Candidate(storageText: first), Candidate(storageText: second)]

        #expect(candidates.map(\.hasDistinctCommitText) == [true, true])
        #expect(candidates.map(\.displayText) == ["Google", "Google"])
        #expect(candidates.map(\.commitText) == ["AAA", "BBB"])
    }
}
