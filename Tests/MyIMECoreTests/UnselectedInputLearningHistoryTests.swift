import Foundation
import Testing
@testable import MyIMECore

@Suite
struct UnselectedInputLearningHistoryTests {
    @Test(arguments: [
        "smart", "Smart", "abc123", "12345", "1",
        "こんにちは", "ありがとう", "よろしく", "あ",
        "スマート", "コンピューター", "テスト", "ア"
    ])
    func repeatedConfirmationIsRequiredForDirectText(_ input: String) throws {
        let entry = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: input,
            hasSelectedCandidate: false
        ))
        var history = UnselectedInputLearningHistory()

        #expect(history.registration(after: entry) == nil)
        #expect(history.registration(after: entry) == entry)
        #expect(history.registration(after: entry) == entry)
    }

    /// Kana chosen from candidates the dictionaries lack, such as the
    /// particle composition そこから, is registered on its second selection
    @Test(arguments: [
        ("sokokara", "そこから"), ("itsuno", "いつの"),
        ("hottopeppa-", "ホットペッパー"), ("hotto", "ﾎｯﾄ")
    ])
    func selectedKanaIsRegisteredOnItsSecondSelection(
        reading: String,
        candidate: String
    ) {
        #expect(UnselectedInputLearningPolicy.requiresRepeatedSelection(
            candidate
        ))
        let entry = UnselectedInputLearningEntry(
            reading: reading,
            candidate: candidate
        )
        var history = UnselectedInputLearningHistory()

        #expect(history.registration(after: entry) == nil)
        #expect(history.registration(after: entry) == entry)
    }

    @Test(arguments: ["指示書を作成", "HubSpot", "Smart Inn", "第一パネル", ""])
    func selectedCandidatesOtherThanKanaAreRegisteredAtOnce(
        _ candidate: String
    ) {
        #expect(!UnselectedInputLearningPolicy.requiresRepeatedSelection(
            candidate
        ))
    }

    @Test
    func deletedKanaStartsCountingAgain() {
        let entry = UnselectedInputLearningEntry(
            reading: "sokokara",
            candidate: "そこから"
        )
        var history = UnselectedInputLearningHistory()
        #expect(history.registration(after: entry) == nil)

        history.remove(candidate: "そこから")

        #expect(history.registration(after: entry) == nil)
        #expect(history.registration(after: entry) == entry)
    }

    @Test
    func confirmationsDoNotNeedToBeConsecutive() throws {
        let target = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "smart",
            hasSelectedCandidate: false
        ))
        let unrelated = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "漢字交じり",
            hasSelectedCandidate: false
        ))
        var history = UnselectedInputLearningHistory()

        #expect(history.registration(after: target) == nil)
        #expect(history.registration(after: unrelated) == unrelated)
        #expect(history.registration(after: target) == target)
    }

    @Test
    func firstConfirmationSurvivesSavingAndReloading() throws {
        let entry = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "スマート",
            hasSelectedCandidate: false
        ))
        var history = UnselectedInputLearningHistory()
        #expect(history.registration(after: entry) == nil)

        var restored = try JSONDecoder().decode(
            UnselectedInputLearningHistory.self,
            from: JSONEncoder().encode(history)
        )

        #expect(restored.registration(after: entry) == entry)
    }

    @Test
    func confirmationIdentityPreservesLetterCase() throws {
        let lower = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "smart",
            hasSelectedCandidate: false
        ))
        let capitalized = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "Smart",
            hasSelectedCandidate: false
        ))
        var history = UnselectedInputLearningHistory()

        #expect(history.registration(after: lower) == nil)
        #expect(history.registration(after: capitalized) == nil)
        #expect(history.registration(after: lower) == lower)
        #expect(history.registration(after: capitalized) == capitalized)
    }

    @Test(arguments: [
        "漢字", "漢字交じり", "ひらがなカタカナ", "Wi-Fi",
        "スマート・イン", " 前後空白 "
    ])
    func otherTextKeepsImmediateLearning(_ input: String) throws {
        let entry = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: input,
            hasSelectedCandidate: false
        ))
        var history = UnselectedInputLearningHistory()

        #expect(history.registration(after: entry) == entry)
    }

    @Test
    func removingAConfirmationRequiresTwoNewCommits() throws {
        let entry = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "smart",
            hasSelectedCandidate: false
        ))
        var history = UnselectedInputLearningHistory()
        #expect(history.registration(after: entry) == nil)
        #expect(history.registration(after: entry) == entry)

        history.remove(candidate: entry.candidate)

        #expect(history.registration(after: entry) == nil)
        #expect(history.registration(after: entry) == entry)
    }

    @Test
    func successfulRegistrationClearsEarlierConfirmation() throws {
        let entry = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "smart",
            hasSelectedCandidate: false
        ))
        var history = UnselectedInputLearningHistory()
        #expect(history.registration(after: entry) == nil)

        history.remove(candidate: entry.candidate)

        #expect(history.registration(after: entry) == nil)
        #expect(history.registration(after: entry) == entry)
    }

    @Test
    func existingDictionaryCandidatesClearLegacyConfirmations() throws {
        let existing = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "existing",
            hasSelectedCandidate: false
        ))
        let pending = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "pending",
            hasSelectedCandidate: false
        ))
        var history = UnselectedInputLearningHistory()
        _ = history.registration(after: existing)
        _ = history.registration(after: pending)

        history.remove(candidates: [existing.candidate])

        #expect(history.confirmationCount(for: existing.candidate) == 0)
        #expect(history.confirmationCount(for: pending.candidate) == 1)
    }

    @Test
    func oldConfirmationsAreBounded() throws {
        var history = UnselectedInputLearningHistory(maximumEntryCount: 2)
        let first = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "first",
            hasSelectedCandidate: false
        ))
        let second = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "second",
            hasSelectedCandidate: false
        ))
        let third = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: "third",
            hasSelectedCandidate: false
        ))

        _ = history.registration(after: first)
        _ = history.registration(after: second)
        _ = history.registration(after: third)

        #expect(history.trackedCandidateCount == 2)
        #expect(history.confirmationCount(for: first.candidate) == 0)
        #expect(history.confirmationCount(for: second.candidate) == 1)
        #expect(history.confirmationCount(for: third.candidate) == 1)
    }
}
