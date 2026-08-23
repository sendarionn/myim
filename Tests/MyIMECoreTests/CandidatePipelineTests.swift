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

    @Test
    func keepsHiraganaFirstForSingleCharacterInput() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["き", "キ"],
                direct: ["キ", "木"],
                other: [],
                recencyRanks: [:],
                prioritizeKana: true
            )
        )

        #expect(candidates == ["き", "キ", "木"])
    }

    @Test
    func prioritizesKatakanaForLongerDictionaryInput() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["さじぇすと", "サジェスト"],
                direct: ["サジェスト", "差ジェスト"],
                other: [],
                recencyRanks: [:],
                prioritizeKana: false
            )
        )

        #expect(candidates == ["サジェスト", "差ジェスト", "さじぇすと"])
    }

    @Test
    func prioritizesHiraganaWhenDictionaryUsesHiragana() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["き", "キ"],
                direct: ["き", "木"],
                other: [],
                recencyRanks: [:],
                prioritizeKana: true
            )
        )

        #expect(candidates == ["き", "キ", "木"])
    }

    @Test
    func usesDictionaryOrderWhenBothKanaFormsExist() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["かな", "カナ"],
                direct: ["カナ", "かな"],
                other: [],
                recencyRanks: [:],
                prioritizeKana: false
            )
        )

        #expect(candidates == ["カナ", "かな"])
    }
}
