import Testing
@testable import MyIMECore

struct EmojiSearchCandidateFilterTests {
    @Test func removesEmojiSequencesOnlyWhileEditingEmojiSearch() {
        let candidates = [
            Candidate(storageText: "🐱", source: .userDictionary),
            Candidate(storageText: "猫", source: .basicDictionary),
            Candidate(storageText: "👨‍👩‍👧‍👦", source: .selectionHistory),
            Candidate(storageText: "1", source: .numericPrefix),
            Candidate(storageText: "#", source: .symbolDictionary)
        ]

        let filtered = EmojiSearchCandidateFilter.candidates(
            candidates,
            isEditingEmojiSearch: true
        )

        #expect(filtered.map(\.storageText) == ["猫", "1", "#"])
        #expect(filtered.map(\.primarySource) == [
            .basicDictionary,
            .numericPrefix,
            .symbolDictionary
        ])
    }

    @Test func preservesEmojiCandidatesOutsideEmojiSearch() {
        let candidates = ["猫", "🐱"].map {
            Candidate(storageText: $0)
        }

        let filtered = EmojiSearchCandidateFilter.candidates(
            candidates,
            isEditingEmojiSearch: false
        )

        #expect(filtered == candidates)
    }

    @Test func removesEmojiBeforeTheDisplayLimitIsApplied() {
        let candidates = ["🐱", "猫", "ネコ", "ねこ", "猫科"].map {
            Candidate(storageText: $0)
        }

        let displayed = EmojiSearchCandidateFilter.candidates(
            candidates,
            isEditingEmojiSearch: true
        ).prefix(4)

        #expect(displayed.map(\.storageText) == ["猫", "ネコ", "ねこ", "猫科"])
    }

    @Test func recognizesKeycapsButNotTheirStandaloneBases() {
        let candidates = ["1️⃣", "#️⃣", "1", "#", "*"].map {
            Candidate(storageText: $0)
        }

        let filtered = EmojiSearchCandidateFilter.candidates(
            candidates,
            isEditingEmojiSearch: true
        )

        #expect(filtered.map(\.storageText) == ["1", "#", "*"])
    }
}
