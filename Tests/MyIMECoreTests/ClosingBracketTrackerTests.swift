import Testing
@testable import MyIMECore

/// The closing bracket is offered once, right after the first text
/// committed or pasted after its opening
@Suite
struct ClosingBracketTrackerTests {
    @Test func openingAloneOffersNothing() {
        var tracker = ClosingBracketTracker()

        tracker.consume("「")

        #expect(tracker.candidate == nil)
    }

    @Test func firstCommittedTextOffersTheClosing() {
        var tracker = ClosingBracketTracker()
        tracker.consume("「")

        tracker.consume("こんにちは")

        #expect(tracker.candidate == "」")
        #expect(!tracker.shouldRecordAsNextInput("」"))
    }

    @Test func nextCommitEndsTheOfferForGood() {
        var tracker = ClosingBracketTracker()
        tracker.consume("「")
        tracker.consume("こんにちは")

        tracker.consume("世界")
        #expect(tracker.candidate == nil)
        tracker.consume("です")
        #expect(tracker.candidate == nil)
    }

    @Test func startingTheNextInputEndsTheOffer() {
        var tracker = ClosingBracketTracker()
        tracker.consume("「")
        tracker.consume("こんにちは")

        tracker.endOffering()
        #expect(tracker.candidate == nil)
        tracker.consume("世界")

        #expect(tracker.candidate == nil)
    }

    @Test func endingTheOfferBeforeTheFirstTextKeepsWaitingForIt() {
        var tracker = ClosingBracketTracker()
        tracker.consume("「")

        // Panels closing before the first text do not affect the offer
        tracker.endOffering()
        tracker.consume("こんにちは")

        #expect(tracker.candidate == "」")
    }

    @Test func spaceIsNotTheFirstText() {
        var tracker = ClosingBracketTracker()
        tracker.consume("(")
        tracker.consume(" ")
        #expect(tracker.candidate == nil)

        tracker.consume("text")
        #expect(tracker.candidate == ")")
    }

    @Test func textCommittedWithTheOpeningOffersTheClosing() {
        var tracker = ClosingBracketTracker()

        tracker.consume("「こんにちは")

        #expect(tracker.candidate == "」")
    }

    @Test func textAlreadyClosedOffersNothing() {
        var tracker = ClosingBracketTracker()
        tracker.consume("「")

        tracker.consume("こんにちは」")

        #expect(tracker.candidate == nil)
    }

    @Test func typedClosingEndsTheOffer() {
        var tracker = ClosingBracketTracker()
        tracker.consume("「")
        tracker.consume("こんにちは")

        tracker.consume("」")
        #expect(tracker.candidate == nil)
        tracker.consume("続き")

        #expect(tracker.candidate == nil)
    }

    @Test func cancellingForgetsTheOpening() {
        var tracker = ClosingBracketTracker()
        tracker.consume("「")

        tracker.reset()
        tracker.consume("こんにちは")

        #expect(tracker.candidate == nil)
    }

    @Test func newOpeningStartsANewOffer() {
        var tracker = ClosingBracketTracker()
        tracker.consume("「")
        tracker.consume("前")
        tracker.consume("後")
        #expect(tracker.candidate == nil)

        tracker.consume("「")
        tracker.consume("次")

        #expect(tracker.candidate == "」")
    }

    @Test func nestedOpeningIsOfferedForItsOwnText() {
        var tracker = ClosingBracketTracker()
        tracker.consume("「")
        tracker.consume("（")
        #expect(tracker.candidate == nil)

        tracker.consume("こんにちは")
        #expect(tracker.candidate == "）")

        // Closing the inner bracket ends the cycle without offering 」
        tracker.consume("）")
        #expect(tracker.candidate == nil)
    }

    @Test func eitherWidthClosesTheOpening() {
        var tracker = ClosingBracketTracker()
        tracker.consume("（")
        tracker.consume("text")
        #expect(tracker.candidate == "）")

        tracker.consume(")")
        tracker.consume("（")
        tracker.consume("more")

        #expect(tracker.candidate == "）")
    }

    @Test func preservesTheOfferAcrossAnEmptySystemCommit() {
        var tracker = ClosingBracketTracker()
        tracker.consume("[")
        #expect(!tracker.shouldPreserveCandidatesDuringEmptySystemCommit(
            hasCandidates: true
        ))

        tracker.consume("text")
        #expect(tracker.shouldPreserveCandidatesDuringEmptySystemCommit(
            hasCandidates: true
        ))
        #expect(!tracker.shouldPreserveCandidatesDuringEmptySystemCommit(
            hasCandidates: false
        ))
    }

    @Test func consumesTheSameClosingTypedOverASelectedCandidate() {
        var tracker = ClosingBracketTracker()
        tracker.consume("[")
        tracker.consume("text")

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
}
