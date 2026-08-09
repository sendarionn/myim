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
            recencyRanks: ["機会": 9]
        )
        #expect(result == ["き", "キ", "気", "木", "機会", "昨日"])
    }

    @Test
    func removesDuplicatesAcrossPriorityGroups() {
        let result = CandidatePriorityOrderer.ordered(
            kana: ["かな", "カナ"],
            direct: ["かな", "仮名"],
            others: ["仮名", "金物", "カナ"],
            recencyRanks: [:]
        )
        #expect(result == ["かな", "カナ", "仮名", "金物"])
    }
}
