import Testing
@testable import MyIMECore

@Suite
struct CandidateSelectionHistoryTests {
    @Test
    func recordsSelectionsInRecentOrder() {
        var history = CandidateSelectionHistory()
        history.record("見る")
        history.record("診る")
        history.record("見る")

        #expect(history.ranks["見る"]! > history.ranks["診る"]!)
    }

    @Test
    func keepsOnlyTheMostRecentEntries() {
        var history = CandidateSelectionHistory(maximumEntryCount: 2)
        history.record("見る")
        history.record("診る")
        history.record("観る")

        #expect(history.ranks.count == 2)
        #expect(history.ranks["見る"] == nil)
        #expect(history.ranks["診る"] != nil)
        #expect(history.ranks["観る"] != nil)
    }

    @Test
    func compactsOversizedLoadedHistory() {
        let history = CandidateSelectionHistory(
            ranks: ["古い": 1, "中間": 4, "新しい": 9],
            maximumEntryCount: 2
        )

        #expect(history.ranks.count == 2)
        #expect(history.ranks["古い"] == nil)
        #expect(history.ranks["新しい"]! > history.ranks["中間"]!)
    }
}
