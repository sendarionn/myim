import Testing
@testable import MyIMECore

struct ClosingBracketTrackerTests {
    @Test func pendingClosingIsExcludedFromNextInputLearning() {
        var tracker = ClosingBracketTracker()
        tracker.consume("（")

        #expect(!tracker.shouldRecordAsNextInput("）"))
        #expect(!tracker.shouldRecordCommittedInput("）", requested: true))
        #expect(tracker.shouldRecordAsNextInput("続き"))
        #expect(tracker.shouldRecordCommittedInput("続き", requested: true))
        #expect(!tracker.shouldRecordCommittedInput("続き", requested: false))
        #expect(tracker.shouldBypassCandidateSuppression("）"))
        #expect(!tracker.shouldBypassCandidateSuppression("続き"))
    }

    @Test func keepsClosingBracketUntilItIsEntered() {
        var tracker = ClosingBracketTracker()
        tracker.consume("「")
        #expect(tracker.candidate == "」")

        tracker.consume("文章")
        #expect(tracker.candidate == "」")

        tracker.consume("」")
        #expect(tracker.candidate == nil)
    }

    @Test func followsNestedBrackets() {
        var tracker = ClosingBracketTracker()
        tracker.consume("（「")
        #expect(tracker.candidate == "」")
        tracker.consume("」")
        #expect(tracker.candidate == "）")
    }

    @Test func preservesAClosingCandidateAcrossAnEmptySystemCommit() {
        var tracker = ClosingBracketTracker()
        tracker.consume("[")

        #expect(tracker.shouldPreserveCandidatesDuringEmptySystemCommit(
            hasCandidates: true
        ))
        #expect(!tracker.shouldPreserveCandidatesDuringEmptySystemCommit(
            hasCandidates: false
        ))

        tracker.consume("]")
        #expect(!tracker.shouldPreserveCandidatesDuringEmptySystemCommit(
            hasCandidates: true
        ))
    }

    @Test func consumesTheSameClosingTypedOverASelectedCandidate() {
        var tracker = ClosingBracketTracker()
        tracker.consume("[")

        #expect(tracker.shouldConsumeTypedClosing(
            "]",
            selectedCandidate: "]"
        ))
        #expect(!tracker.shouldConsumeTypedClosing(
            "a",
            selectedCandidate: "]"
        ))
        #expect(!tracker.shouldConsumeTypedClosing(
            "]",
            selectedCandidate: "続き"
        ))
    }

    @Test(arguments: [
        ("「こんにちは", "", "」"),
        ("（こんにちは", "", "）"),
        ("「（こんにちは", "", "）"),
        ("「（こんにちは）", "", "」"),
        ("「こんにちは」", "", nil),
        ("", "「こんにちは", nil)
    ])
    func rebuildsTheCandidateFromTextBeforeTheCursor(
        preceding: String,
        following: String,
        expected: String?
    ) {
        var tracker = ClosingBracketTracker()

        tracker.synchronize(
            precedingText: preceding,
            followingText: following
        )

        #expect(tracker.candidate == expected)
    }

    @Test(arguments: [
        ("「こんにちは", "」続き"),
        ("(hello", "）"),
        ("（hello", ")"),
        ("[hello", "］")
    ])
    func doesNotOfferAClosingAlreadyAfterTheCursor(
        preceding: String,
        following: String
    ) {
        var tracker = ClosingBracketTracker()

        tracker.synchronize(
            precedingText: preceding,
            followingText: following
        )

        #expect(tracker.candidate == nil)
    }

    @Test
    func offersTheOuterClosingAfterMovingPastTheInnerClosing() {
        var tracker = ClosingBracketTracker()

        tracker.synchronize(
            precedingText: "「（こんにちは）",
            followingText: "続き"
        )

        #expect(tracker.candidate == "」")
    }

    @Test
    func ignoresOpeningsBeforeTheLatestLineBreak() {
        var tracker = ClosingBracketTracker()

        tracker.synchronize(
            precedingText: "「前の行\n現在の行",
            followingText: ""
        )

        #expect(tracker.candidate == nil)
    }
}
