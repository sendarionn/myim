import Testing
@testable import MyIMECore

@Suite
struct CandidateListInsertionTests {
    @Test
    func insertedCandidatesFollowTheFirstPage() {
        let result = CandidateListInsertion.inserting(
            ["🍣"],
            into: ["寿司", "酸し", "鮨", "寿し", "図示"],
            afterFirst: 4
        )

        #expect(result == ["寿司", "酸し", "鮨", "寿し", "🍣", "図示"])
    }

    @Test
    func shortListsEndWithTheInsertedCandidates() {
        #expect(CandidateListInsertion.inserting(["🐱"], into: ["猫"], afterFirst: 4)
            == ["猫", "🐱"])
        #expect(CandidateListInsertion.inserting([], into: ["猫"], afterFirst: 4)
            == ["猫"])
    }
}
