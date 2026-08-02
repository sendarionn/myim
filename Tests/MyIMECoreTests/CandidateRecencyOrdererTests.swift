import Testing
@testable import MyIMECore

@Suite
struct CandidateRecencyOrdererTests {
    @Test
    func placesMostRecentlySelectedCandidateFirst() {
        let candidates = ["構造", "構想", "高層"]
        let ordered = CandidateRecencyOrderer.ordered(
            candidates,
            ranks: ["構想": 3, "構造": 8]
        )

        #expect(ordered == ["構造", "構想", "高層"])
    }

    @Test
    func preservesOriginalOrderWithoutHistory() {
        let candidates = ["に", "ニ", "二"]

        #expect(
            CandidateRecencyOrderer.ordered(candidates, ranks: [:])
                == candidates
        )
    }

    @Test
    func onlySortsRankedCandidatesAndKeepsUnrankedOrder() {
        let candidates = ["未選択1", "履歴A", "未選択2", "履歴B", "未選択3"]

        let ordered = CandidateRecencyOrderer.ordered(
            candidates,
            ranks: ["履歴A": 10, "履歴B": 20]
        )

        #expect(
            ordered
                == ["履歴B", "履歴A", "未選択1", "未選択2", "未選択3"]
        )
    }

    @Test
    func returnsOriginalArrayWhenHistoryIsEmpty() {
        let candidates = (0..<10_000).map { "候補\($0)" }

        #expect(
            CandidateRecencyOrderer.ordered(candidates, ranks: [:])
                == candidates
        )
    }
}
