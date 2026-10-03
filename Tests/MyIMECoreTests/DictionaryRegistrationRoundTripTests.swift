import Testing
@testable import MyIMECore

@Suite
struct DictionaryRegistrationRoundTripTests {
    @Test
    func registeredDisplayAndInsertedTextSurviveReloadAsOneCandidate() throws {
        var session = DictionaryRegistrationSession(
            originalInput: "gg",
            reading: "gg"
        )
        session.appendConfirmed("Google")
        session.toggleInputField(absorbing: nil)
        session.appendConfirmed("https://www.google.com/")
        let completion = try #require(session.completionWhenInputIsEmpty())

        var savedText = ""
        let store = UserDictionaryStore(entries: []) {
            savedText = DictionarySerializer.text(from: $0)
        }
        try store.add(
            reading: completion.reading,
            candidate: completion.output,
            display: completion.display
        )

        #expect(savedText == "gg\tGoogle\thttps://www.google.com/\n")

        let reloaded = try DictionaryParser().parse(savedText)
        let storageText = try #require(
            ConversionEngine(entries: reloaded).candidates(for: "gg").first
        )
        let candidate = Candidate(
            storageText: storageText,
            source: .userDictionary,
            reading: "gg"
        )

        #expect(candidate.displayText == "Google")
        #expect(candidate.commitText == "https://www.google.com/")
        #expect(candidate.hasDistinctCommitText)
        #expect(CandidateSelectionProjection.markedText(for: candidate)
            == "https://www.google.com/")
    }

    @Test
    func ordinaryRegistrationIsSavedWithoutADisplayColumn() throws {
        var session = DictionaryRegistrationSession(
            originalInput: "shiru",
            reading: "shiru"
        )
        session.appendConfirmed("知る")
        let completion = try #require(session.completionWhenInputIsEmpty())
        var savedText = ""
        let store = UserDictionaryStore(entries: []) {
            savedText = DictionarySerializer.text(from: $0)
        }

        try store.add(
            reading: completion.reading,
            candidate: completion.output,
            display: completion.display
        )

        #expect(savedText == "shiru\t知る\n")
        let candidate = Candidate(storageText: "知る", source: .userDictionary)
        #expect(!candidate.hasDistinctCommitText)
    }
}
