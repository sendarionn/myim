import Testing
@testable import MyIMECore

struct FuzzySuggestionTierBuilderTests {
    @Test func placesExactCompoundBeforeDirectAndCompoundTypos() {
        let directTypo = FuzzyConversionMatch(
            reading: "tuuyoukouho",
            candidates: ["通用候補"],
            distance: 1
        )
        let exactCompound = FuzzyConversionMatch(
            reading: "tuujoukouho",
            candidates: ["通常候補"],
            distance: 0
        )
        let typoCompound = FuzzyConversionMatch(
            reading: "tuujoukouho",
            candidates: ["通常広報"],
            distance: 1
        )

        let tiers = FuzzySuggestionTierBuilder.build(
            directTypoMatches: [directTypo],
            compoundMatches: [typoCompound, exactCompound]
        )

        #expect(tiers.map { $0.map(\.candidates) } == [
            [["通常候補"]],
            [["通用候補"]],
            [["通常広報"]]
        ])
    }
}
