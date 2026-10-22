import Testing
@testable import MyIMECore

@Suite
struct CandidatePriorityOrdererTests {
    @Test
    func keepsSingleHiraganaAheadOfEstablishedCandidate() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["き", "キ"],
            direct: ["気", "木"],
            others: ["昨日", "機会", "気"],
            recencyRanks: ["機会": 9],
            prioritizeKana: true
        )
        #expect(result == ["き", "機会", "キ", "気", "木", "昨日"])
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
    func movesEstablishedOtherCandidateAheadOfGroupsForLongInput() {
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
    func keepsExactUnvoicedCandidatesBeforeLaterRendakuCandidates() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["ごく", "ゴク"],
            direct: ["語句", "極", "国"],
            others: [],
            recencyRanks: [:],
            prioritizeKana: false
        )
        #expect(result == ["語句", "極", "国", "ごく", "ゴク"])
    }

    @Test
    func movesEstablishedKanaAheadOfDirectCandidatesForLongInput() {
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
    func keepsRecentSelectionInsideItsCandidateGroup() {
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
    func movesEstablishedCompletionsAheadOfCandidateGroups() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["さい", "サイ"],
            direct: ["再", "際", "歳"],
            others: ["最愛", "再利用"],
            recencyRanks: ["最愛": 8, "再利用": 12],
            prioritizeKana: false
        )

        #expect(result == ["再利用", "最愛", "再", "際", "歳", "さい", "サイ"])
    }

    @Test
    func keepsSecondaryCandidatesAheadOfGeneratedKanaForLongInput() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["こうほを", "コウホヲ"],
            direct: ["公募を"],
            secondary: ["候補を"],
            others: [],
            recencyRanks: [:],
            prioritizeKana: false
        )

        #expect(result == ["公募を", "候補を", "こうほを", "コウホヲ"])
    }

    @Test
    func movesEstablishedSelectionAheadOfCandidateGroups() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["あります", "アリマス"],
            direct: ["有ります", "在ります"],
            secondary: ["あります"],
            others: ["ありました"],
            recencyRanks: ["あります": 12],
            secondaryRanks: ["あります": 12],
            prioritizeKana: false
        )

        #expect(result == [
            "あります", "有ります", "在ります", "アリマス", "ありました"
        ])
    }

    @Test
    func keepsDefaultGroupsWhenSelectionIsNotEstablished() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["あります", "アリマス"],
            direct: ["有ります", "在ります"],
            secondary: ["あります"],
            others: [],
            recencyRanks: [:],
            secondaryRanks: ["あります": 12],
            prioritizeKana: false
        )

        #expect(result == ["有ります", "在ります", "あります", "アリマス"])
    }

    @Test
    func mostRecentEstablishedSelectionWinsAcrossCandidateGroups() {
        let firstGenerated = CandidatePriorityOrderer.ordered(
            kana: [],
            direct: ["完全一致"],
            secondary: ["生成候補"],
            others: [],
            recencyRanks: ["完全一致": 4, "生成候補": 5],
            prioritizeKana: false
        )
        let thenExact = CandidatePriorityOrderer.ordered(
            kana: [],
            direct: ["完全一致"],
            secondary: ["生成候補"],
            others: [],
            recencyRanks: ["完全一致": 6, "生成候補": 5],
            prioritizeKana: false
        )

        #expect(firstGenerated == ["生成候補", "完全一致"])
        #expect(thenExact == ["完全一致", "生成候補"])
    }
}
