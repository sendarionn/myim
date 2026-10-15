import Testing
@testable import MyIMECore

/// ⌘X removes the selected emoji from the recent history only
@Suite
struct RecentEmojiRemovalTests {
    @Test
    func removesOnlyTheEmojiAndKeepsTheOrder() {
        var history = RecentEmojiHistory(emojis: ["😀", "🐱", "👍", "🎉"])

        let removed = history.remove("🐱")

        #expect(removed)
        #expect(history.emojis == ["😀", "👍", "🎉"])
    }

    @Test
    func removalSurvivesARestart() {
        var history = RecentEmojiHistory(emojis: ["😀", "🐱", "👍"])
        history.remove("🐱")

        // The panel saves `emojis` and restores the history from them
        let restored = RecentEmojiHistory(emojis: history.emojis)

        #expect(restored.emojis == ["😀", "👍"])
    }

    @Test
    func usingTheEmojiAgainRecordsItAnew() {
        var history = RecentEmojiHistory(emojis: ["😀", "🐱", "👍"])
        history.remove("🐱")

        history.record("🐱")

        #expect(history.emojis == ["🐱", "😀", "👍"])
    }

    @Test
    func removingAnEmojiNotInTheHistoryChangesNothing() {
        var history = RecentEmojiHistory(emojis: ["😀"])

        let removed = history.remove("🐱")

        #expect(!removed)
        #expect(history.emojis == ["😀"])
    }

    @Test
    func removingTheLastEmojiLeavesAnEmptyHistory() {
        var history = RecentEmojiHistory(emojis: ["😀"])

        history.remove("😀")

        #expect(history.emojis.isEmpty)
        #expect(RecentEmojiHistory.selectionAfterRemoving(
            at: 0,
            remainingCount: 0
        ) == nil)
    }

    @Test(arguments: [
        (0, 3, 0), (1, 3, 1), (3, 3, 2), (2, 2, 1)
    ])
    func selectsTheEmojiTakingThePlaceOrThePreviousOne(
        removed: Int,
        remaining: Int,
        expected: Int
    ) {
        #expect(RecentEmojiHistory.selectionAfterRemoving(
            at: removed,
            remainingCount: remaining
        ) == expected)
    }

    @Test
    func selectedRecentEmojiIsTheDeletionTarget() {
        #expect(CandidateDeletionCommandPolicy.target(
            hasInput: false,
            hasStandardSelection: false,
            hasFuzzySelection: false,
            hasNextInputSelection: false,
            hasRecentEmojiSelection: true
        ) == .recentEmoji)
    }

    @Test
    func otherSelectionsKeepTheirDeletionTargets() {
        #expect(CandidateDeletionCommandPolicy.target(
            hasInput: true,
            hasStandardSelection: true,
            hasFuzzySelection: false,
            hasNextInputSelection: false,
            hasRecentEmojiSelection: false
        ) == .standardCandidate)
        #expect(CandidateDeletionCommandPolicy.target(
            hasInput: false,
            hasStandardSelection: false,
            hasFuzzySelection: false,
            hasNextInputSelection: false
        ) == nil)
    }
}
