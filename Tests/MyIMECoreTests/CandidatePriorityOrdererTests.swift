import Testing
@testable import MyIMECore

@Suite
struct CandidatePriorityOrdererTests {
    @Test
    func keepsKanaBeforeDirectAndRecentCandidates() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["き", "キ"],
            direct: ["気", "木"],
            others: ["昨日", "機会", "気"],
            recencyRanks: ["機会": 9],
            prioritizeKana: true
        )
        #expect(result == ["き", "キ", "気", "木", "機会", "昨日"])
    }

    @Test
    func removesDuplicatesAcrossPriorityGroups() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["かな", "カナ"],
            direct: ["かな", "仮名"],
            others: ["仮名", "金物", "カナ"],
            recencyRanks: [:],
            prioritizeKana: true
        )
        #expect(result == ["かな", "カナ", "仮名", "金物"])
    }

    @Test
    func prioritizesDirectAndRecentCandidatesForLongInput() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["きかい", "キカイ"],
            direct: ["機械", "機会"],
            others: ["期間", "機械的"],
            recencyRanks: ["機械的": 12],
            prioritizeKana: false
        )
        #expect(result == [
            "機械的", "機械", "機会", "きかい", "キカイ", "期間"
        ])
    }

    @Test
    func ordersDirectCandidatesByRecentSelection() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["こうしょう", "コウショウ"],
            direct: ["交渉", "高尚", "校章"],
            others: ["工廠"],
            recencyRanks: ["高尚": 12, "交渉": 8],
            prioritizeKana: false
        )
        #expect(result == ["高尚", "交渉", "校章", "こうしょう", "コウショウ", "工廠"])
    }

    @Test
    func selectedKanaCanMoveAheadOfDirectCandidateForLongInput() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["での", "デノ"],
            direct: ["出野"],
            others: [],
            recencyRanks: ["での": 12],
            prioritizeKana: false
        )
        #expect(result == ["での", "出野", "デノ"])
    }

    @Test
    func prioritizesMostRecentSelectionBeforeCandidateUsedAfterPreviousInput() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["けいかく", "ケイカク"],
            direct: ["計画", "軽核"],
            others: ["計画的"],
            recencyRanks: ["軽核": 20],
            contextualCandidates: ["計画"],
            prioritizeKana: false
        )

        #expect(result == ["軽核", "計画", "けいかく", "ケイカク", "計画的"])
    }

    @Test
    func keepsSingleKanaAheadOfContextualCandidate() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["き", "キ"],
            direct: ["木", "気"],
            others: [],
            recencyRanks: [:],
            contextualCandidates: ["気"],
            prioritizeKana: true
        )

        #expect(result == ["き", "キ", "気", "木"])
    }

    @Test
    func prioritizesOnlyTheMostRecentCandidateBeforeCloserMatches() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["さい", "サイ"],
            direct: ["再", "際", "歳"],
            others: ["最愛", "再利用"],
            recencyRanks: ["最愛": 8, "再利用": 12],
            prioritizeKana: false
        )

        #expect(result == ["再利用", "再", "際", "歳", "さい", "サイ", "最愛"])
    }
}
