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
}
