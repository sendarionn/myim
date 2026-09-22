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
    func ordersEachReadingOnlyByMostRecentUse() {
        var history = CandidateSelectionHistory()
        history.record("際", reading: "sai")
        history.record("歳", reading: "sai")
        history.record("際", reading: "sai")
        history.record("再", reading: "sai")
        history.record("差異", reading: "sai")
        history.record("歳", reading: "toshi")

        let saiRanks = history.ranks(for: "sai")
        #expect(saiRanks["差異"]! > saiRanks["再"]!)
        #expect(saiRanks["再"]! > saiRanks["際"]!)
        #expect(saiRanks["際"]! > saiRanks["歳"]!)
        #expect(Set(history.ranks(for: "toshi").keys) == ["歳"])
    }

    @Test
    func frequentOlderCandidateDoesNotBeatMoreRecentCandidate() {
        var history = CandidateSelectionHistory()
        history.record("頻出", reading: "kouho")
        history.record("頻出", reading: "kouho")
        history.record("頻出", reading: "kouho")
        history.record("最新", reading: "kouho")

        let ranks = history.ranks(for: "kouho")
        #expect(ranks["最新"]! > ranks["頻出"]!)
    }

    @Test
    func recordsOneSelectionForOriginalAndCorrectedReadings() {
        var history = CandidateSelectionHistory()
        history.record(
            "慶應大学",
            readings: ["keioudaigku", "keioudaigaku"]
        )

        #expect(history.ranks(for: "keioudaigku")["慶應大学"] != nil)
        #expect(history.ranks(for: "keioudaigaku")["慶應大学"] != nil)
        #expect(history.ranks["慶應大学"] == 1)
    }

    @Test
    func learnsNextInputSelectionForItsDictionaryReading() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(
                reading: "kouho",
                candidates: ["候補", "公募"]
            )
        ])
        var history = CandidateSelectionHistory()

        history.record(
            "候補",
            readings: engine.readings(for: "候補")
        )

        #expect(history.ranks(for: "kouho")["候補"] != nil)
        #expect(history.ranks(for: "kouho")["公募"] == nil)
    }

    @Test
    func combinesRanksAcrossEquivalentReadingInputs() {
        var history = CandidateSelectionHistory()
        history.record("通用候補", reading: "tuujoukouho")
        history.record("通常候補", reading: "tsuujoukouho")

        let ranks = history.ranks(
            for: ["tuujoukouho", "tsuujoukouho"]
        )
        #expect(ranks["通常候補"]! > ranks["通用候補"]!)
    }

    @Test
    func doesNotApplyLearningFromAnotherReading() {
        var history = CandidateSelectionHistory()
        history.record("そのまま", reading: "sonomama")

        #expect(history.ranks(for: "sono").isEmpty)
        #expect(history.ranks(for: "sonomama")["そのまま"] != nil)
    }

    @Test
    func restoresCandidatesLearnedForTheExactReading() {
        var history = CandidateSelectionHistory()
        history.record("◯", reading: "maru")
        history.record("○", reading: "maru")
        history.record("候補", reading: "kouho")
        history.record("◯", reading: "maru")

        #expect(history.candidates(for: ["maru"]) == ["◯", "○"])
        #expect(!history.candidates(for: ["maru"]).contains("候補"))
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
    func limitsEntriesByDefault() {
        var history = CandidateSelectionHistory()
        for index in 0...CandidateSelectionHistory.defaultMaximumEntryCount {
            history.record("候補\(index)", reading: "よみ\(index)")
        }

        #expect(
            history.ranks.count
                == CandidateSelectionHistory.defaultMaximumEntryCount
        )
        #expect(history.ranks["候補0"] == nil)
        #expect(history.ranks["候補10000"] != nil)
    }

    @Test
    func limitsCandidatesForEachReading() {
        var history = CandidateSelectionHistory()
        for index in 0...CandidateSelectionHistory.maximumCandidatesPerReading {
            history.record("候補\(index)", reading: "yomi")
        }

        #expect(
            history.ranks(for: "yomi").count
                == CandidateSelectionHistory.maximumCandidatesPerReading
        )
        #expect(history.ranks(for: "yomi")["候補0"] == nil)
        #expect(history.ranks(for: "yomi")["候補16"] != nil)
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
