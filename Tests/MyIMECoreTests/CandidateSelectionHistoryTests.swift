import Foundation
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

    @Test
    func learnsRecencyAndFrequencyForEachReading() {
        var history = CandidateSelectionHistory()
        history.record("際", reading: "sai")
        history.record("歳", reading: "sai")
        history.record("際", reading: "sai")
        history.record("再", reading: "sai")
        history.record("差異", reading: "sai")
        history.record("歳", reading: "toshi")

        let saiRanks = history.ranks(for: "sai")
        #expect(saiRanks["差異"]! > saiRanks["際"]!)
        #expect(saiRanks["際"]! > saiRanks["再"]!)
        #expect(saiRanks["歳"] != nil)
        #expect(Set(history.ranks(for: "toshi").keys) == ["歳"])
    }

    @Test
    func doesNotApplyLearningFromAnotherReading() {
        var history = CandidateSelectionHistory()
        history.record("そのまま", reading: "sonomama")

        #expect(history.ranks(for: "sono").isEmpty)
        #expect(history.ranks(for: "sonomama")["そのまま"] != nil)
    }

    @Test
    func suggestsFrequentlyUsedLongerReadingsAsCompletions() {
        var history = CandidateSelectionHistory()
        history.record("そのため", reading: "sonotame")
        history.record("そのまま", reading: "sonomama")
        history.record("そのまま", reading: "sonomama")

        let completions = history.completions(for: "sono")
        #expect(completions.first == "そのまま")
        #expect(completions.contains("そのため"))
        #expect(history.completions(for: "sonomama").isEmpty)
    }

    @Test
    func doesNotSuggestCompletionsForOneCharacterInput() {
        var history = CandidateSelectionHistory()
        history.record("そのまま", reading: "sonomama")

        #expect(history.completions(for: "s").isEmpty)
    }

    @Test
    func keepsAllEntriesByDefault() {
        var history = CandidateSelectionHistory()
        for index in 0..<4_200 {
            history.record("候補\(index)", reading: "よみ\(index)")
        }

        #expect(history.ranks.count == 4_200)
    }

    @Test
    func persistsDetailedLearning() throws {
        var history = CandidateSelectionHistory()
        history.record("再", reading: "sai")
        let data = try JSONEncoder().encode(history)
        let restored = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: data
        )

        #expect(restored.ranks(for: "sai")["再"] != nil)
    }

    @Test
    func removesCandidateFromRanksAndCompletions() {
        var history = CandidateSelectionHistory()
        history.record("みるみる", reading: "mirumiru")
        history.remove(["みるみる"])

        #expect(history.ranks["みるみる"] == nil)
        #expect(history.ranks(for: "mirumiru")["みるみる"] == nil)
        #expect(!history.completions(for: "miru").contains("みるみる"))
    }
}
