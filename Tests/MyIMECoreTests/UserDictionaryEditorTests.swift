import Testing
@testable import MyIMECore

@Suite
struct UserDictionaryEditorTests {
    @Test
    func addsCandidateToExistingReading() {
        let entries = [
            DictionaryEntry(reading: "kouzou", candidates: ["構造"])
        ]
        let result = UserDictionaryEditor.adding(
            reading: "kouzou",
            candidate: "構想",
            to: entries
        )

        #expect(result[0].candidates == ["構造", "構想"])
    }

    @Test
    func treatsNormalizedReadingAsSameEntry() {
        let entries = [
            DictionaryEntry(reading: "shuusei", candidates: ["修正"])
        ]
        let result = UserDictionaryEditor.adding(
            reading: "syuusei",
            candidate: "修整",
            to: entries
        )

        #expect(result.count == 1)
        #expect(result[0].candidates == ["修正", "修整"])
    }

    @Test
    func doesNotDuplicateCandidate() {
        let entries = [
            DictionaryEntry(reading: "kenkyuu", candidates: ["研究"])
        ]
        let result = UserDictionaryEditor.adding(
            reading: "kenkyuu",
            candidate: "研究",
            to: entries
        )

        #expect(result == entries)
    }
}
