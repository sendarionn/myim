import Testing
@testable import MyIMECore

@Suite
struct CandidatePipelineTests {
    @Test
    func preservesCandidatePriorityRules() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["での", "デノ"],
                direct: ["出野", "での"],
                other: ["出野さん", "デノ"],
                recencyRanks: ["での": 12],
                prioritizeKana: false
            )
        )

        #expect(candidates == ["での", "出野", "デノ", "出野さん"])
    }
}
