import Testing
@testable import MyIMECore

struct TieredCandidateOrdererTests {
    @Test func neverMovesASecondaryCandidateIntoThePrimaryTier() {
        let tiers = [
            ["入力全体の補正A", "入力全体の補正B"],
            ["複合予測A", "複合予測B"]
        ]
        let indices = TieredCandidateOrderer.orderedIndices(
            for: tiers,
            ranks: ["複合予測B": 100, "入力全体の補正B": 1]
        )
        let ordered = zip(tiers, indices).flatMap { tier, indices in
            indices.map { tier[$0] }
        }
        #expect(ordered == [
            "入力全体の補正B",
            "入力全体の補正A",
            "複合予測B",
            "複合予測A"
        ])
    }
}
