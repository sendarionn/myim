import Testing
@testable import MyIMECore

/// A closing bracket is offered only while its opening is still open, and
/// is not learned as a word following ordinary text
@Suite
struct ClosingBracketStateTests {
    @Test(arguments: [
        (["（", "smaller", ")"], "full-width opening closed by ASCII"),
        (["(", "smaller", "）"], "ASCII opening closed by full-width"),
        (["［", "a", "]"], "full-width square bracket closed by ASCII")
    ])
    func eitherWidthClosesTheOpening(commits: [String], _: String) {
        let commitsAfter = commit(commits + ["text", "more"])

        #expect(commitsAfter.last?.offered == nil)
        #expect(commitsAfter[2].learns == false)
    }

    @Test
    func closingAnOuterBracketEndsTheBracketsOpenedInside() {
        let commits = commit(["「", "(", "a", "」", "text"])

        #expect(commits[3].learns == false)
        #expect(commits[3].offered == nil)
        #expect(commits[4].offered == nil)
    }

    @Test
    func nestedBracketsStillCloseInTurn() {
        let commits = commit(["「", "『", "a", "』", "b", "」", "c"])

        // Only the innermost opening is offered, once after its first text
        #expect(commits.map(\.offered)
            == [nil, nil, "』", nil, nil, nil, nil])
    }

    @Test
    func closingWithoutAnOpeningIsNotLearned() {
        let commits = commit(["smaller", ")", "text"])

        #expect(commits[1].learns == false)
        #expect(commits.map(\.offered) == [nil, nil, nil])
    }

    @Test
    func ordinaryTextIsStillLearned() {
        let commits = commit(["(", "smaller", ")", "text"])

        #expect(commits.map(\.learns) == [true, true, false, true])
        #expect(commits[1].offered == ")")
    }

    @Test
    func resetForgetsBracketsLeftOpen() {
        var tracker = ClosingBracketTracker()
        tracker.consume("（a")

        tracker.reset()

        #expect(tracker.candidate == nil)
        tracker.consume("「")
        tracker.consume("b")
        #expect(tracker.candidate == "」")
    }

    @Test(arguments: [")", "）", "」", "』", "】", "]", "」「を"])
    func continuationsStartingWithAClosingAreLeftToTheTracker(
        _ value: String
    ) {
        #expect(ClosingBracketTracker.startsWithClosingBracket(value))
    }

    @Test(arguments: ["を", "(笑)", "「引用」", "年", ""])
    func otherContinuationsAreKept(_ value: String) {
        #expect(!ClosingBracketTracker.startsWithClosingBracket(value))
    }

    /// Commits each value as the input controller does, returning whether
    /// it was learned and which closing is offered afterwards
    private func commit(
        _ values: [String]
    ) -> [(learns: Bool, offered: String?)] {
        var tracker = ClosingBracketTracker()
        return values.map { value in
            let learns = NextInputCommitPolicy.resolve(
                committing: value,
                closingBracketTracker: tracker,
                isGeneratedParticle: false
            ).learnsInput
            tracker.consume(value)
            return (learns, tracker.candidate)
        }
    }
}
