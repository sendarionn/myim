import Testing
@testable import MyIMECore

struct ClosingBracketTrackerTests {
    @Test func pendingClosingIsExcludedFromNextInputLearning() {
        var tracker = ClosingBracketTracker()
        tracker.consume("（")

        #expect(!tracker.shouldRecordAsNextInput("）"))
        #expect(tracker.shouldRecordAsNextInput("続き"))
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
}
