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

    @Test
    func removesCandidateFromMatchingReading() {
        let entries = [
            DictionaryEntry(
                reading: "kouzou",
                candidates: ["構造", "構想"]
            )
        ]
        let result = UserDictionaryEditor.removing(
            candidate: "構造",
            matchingReadings: ["kouzou"],
            from: entries
        )

        #expect(result == [
            DictionaryEntry(reading: "kouzou", candidates: ["構想"])
        ])
    }

    @Test
    func removesEntryWhenLastCandidateIsRemoved() {
        let entries = [
            DictionaryEntry(reading: "kenkyuu", candidates: ["研究"])
        ]
        let result = UserDictionaryEditor.removing(
            candidate: "研究",
            matchingReadings: ["kenkyuu"],
            from: entries
        )

        #expect(result.isEmpty)
    }

    @Test
    func leavesCandidatesForOtherReadingsUnchanged() {
        let entries = [
            DictionaryEntry(reading: "kouzou", candidates: ["構造"]),
            DictionaryEntry(reading: "shikumi", candidates: ["構造"])
        ]
        let result = UserDictionaryEditor.removing(
            candidate: "構造",
            matchingReadings: ["kouzou"],
            from: entries
        )

        #expect(result == [
            DictionaryEntry(reading: "shikumi", candidates: ["構造"])
        ])
    }

    @Test
    func removesCandidateRegardlessOfCurrentReading() {
        let entries = [
            DictionaryEntry(reading: "readme", candidates: ["README"]),
            DictionaryEntry(reading: "document", candidates: ["README", "文書"])
        ]
        let result = UserDictionaryEditor.removing(
            candidate: "README",
            from: entries
        )

        #expect(result == [
            DictionaryEntry(reading: "document", candidates: ["文書"])
        ])
    }

    @Test
    func leavesOtherUserCandidatesUnchangedWhenRemovingGlobally() {
        let entries = [
            DictionaryEntry(reading: "readme", candidates: ["README"]),
            DictionaryEntry(reading: "read", candidates: ["読む"])
        ]
        let result = UserDictionaryEditor.removing(
            candidate: "README",
            from: entries
        )

        #expect(result == [
            DictionaryEntry(reading: "read", candidates: ["読む"])
        ])
    }
}
