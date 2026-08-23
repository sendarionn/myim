import Testing
@testable import MyIMECore

@Suite
struct RomajiTypoScorerTests {
    @Test
    func givesAdjacentKeySubstitutionLowerCost() {
        let adjacent = RomajiTypoScorer.cost(from: "r", to: "t")
        let unrelated = RomajiTypoScorer.cost(from: "r", to: "p")

        #expect(adjacent < unrelated)
    }

    @Test
    func givesMissingVowelLowerCostThanMissingConsonant() {
        let missingVowel = RomajiTypoScorer.cost(
            from: "susmete",
            to: "susumete"
        )
        let missingConsonant = RomajiTypoScorer.cost(
            from: "suumete",
            to: "susumete"
        )

        #expect(missingVowel < missingConsonant)
    }

    @Test
    func treatsAdjacentTranspositionAsLikelyTypo() {
        let transposition = RomajiTypoScorer.cost(
            from: "hiduek",
            to: "hiduke"
        )
        let substitutions = RomajiTypoScorer.cost(
            from: "hidaxx",
            to: "hiduke"
        )

        #expect(transposition < substitutions)
    }

    @Test
    func penalizesAddingVoicingToUnvoicedInput() {
        let addedVoicing = RomajiTypoScorer.cost(from: "kaku", to: "gaku")
        let ordinaryTypo = RomajiTypoScorer.cost(from: "ainai", to: "aimai")

        #expect(addedVoicing > ordinaryTypo)
    }
}
