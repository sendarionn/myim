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
    func keepsSingleHiraganaBeforeKatakanaFoundInDictionary() {
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
    func keepsRiHiraganaBeforeMozcKatakanaCandidate() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["り", "リ"],
                direct: ["リ", "李", "利", "里", "理"],
                other: [],
                recencyRanks: [:],
                prioritizeKana: true
            )
        )

        #expect(candidates == ["り", "リ", "李", "利", "里", "理"])
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

    @Test
    func usesRecentSelectionWhenBothKanaFormsExist() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["もにたー", "モニター"],
                direct: ["モニター", "もにたー"],
                other: [],
                recencyRanks: ["もにたー": 12, "モニター": 8],
                prioritizeKana: false
            )
        )

        #expect(candidates == ["もにたー", "モニター"])
    }

    @Test
    func prioritizesKatakanaWhenOnlyKatakanaExistsInDictionary() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["もにたー", "モニター"],
                direct: ["モニター", "監視装置"],
                other: [],
                recencyRanks: [:],
                prioritizeKana: false
            )
        )

        #expect(candidates == ["モニター", "監視装置", "もにたー"])
    }

    @Test
    func keepsEnglishCandidatesAfterCloseJapaneseCandidates() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["こーど", "コード"],
                direct: ["高度", "コード"],
                other: ["行動"],
                english: ["code", "coder"],
                recencyRanks: ["code": 20],
                prioritizeKana: false
            )
        )

        #expect(candidates == [
            "高度", "コード", "こーど", "code", "coder", "行動"
        ])
    }

    @Test
    func keepsTrailingCandidateAfterLowercaseAndKana() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["まいむ", "マイム"],
                direct: ["myim"],
                other: [],
                trailing: ["MYIM"],
                recencyRanks: ["MYIM": 100],
                prioritizeKana: false
            )
        )

        #expect(candidates == ["myim", "まいむ", "マイム", "MYIM"])
    }

    @Test
    func keepsExactCandidateAheadOfLearnedCompletion() {
        let candidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: ["その", "ソノ"],
                direct: ["その"],
                other: ["そのまま"],
                recencyRanks: [:],
                prioritizeKana: false
            )
        )

        #expect(candidates.first == "その")
        #expect(candidates.contains("そのまま"))
    }
}
