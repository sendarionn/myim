import Testing
@testable import MyIMECore

struct FuzzySuggestionTierBuilderTests {
    @Test func placesExactCompoundBeforeDirectAndCompoundTypos() {
        let directTypo = FuzzyConversionMatch(
            reading: "tuuyoukouho",
            candidates: ["通用候補"],
            distance: 1
        )
        let exactCompound = CompoundDictionaryCandidate(
            text: "通常候補",
            reading: "tuujoukouho",
            typoDistance: 0,
            minimumSegmentLength: 5
        )
        let typoCompound = CompoundDictionaryCandidate(
            text: "通常広報",
            reading: "tuujoukouho",
            typoDistance: 1,
            minimumSegmentLength: 5
        )

        let tiers = FuzzySuggestionTierBuilder.build(
            directTypoMatches: [directTypo],
            compounds: [typoCompound, exactCompound]
        )

        #expect(tiers.flatMap { $0.flatMap(\.candidates) } == [
            "通常候補", "通用候補", "通常広報"
        ])
    }

    @Test func placesCloseWholeReadingCorrectionsBeforeFragmentSplits() {
        let close = FuzzyConversionMatch(
            reading: "hyouka",
            candidates: ["評価"],
            distance: 1
        )
        let distant = FuzzyConversionMatch(
            reading: "gyokou",
            candidates: ["漁港"],
            distance: 2
        )
        let fragmentSplit = CompoundDictionaryCandidate(
            text: "魚羽化",
            reading: "gyouka",
            typoDistance: 0,
            minimumSegmentLength: 3
        )

        let tiers = FuzzySuggestionTierBuilder.build(
            directTypoMatches: [close, distant],
            compounds: [fragmentSplit]
        )

        #expect(tiers.flatMap { $0.flatMap(\.candidates) } == [
            "評価", "魚羽化", "漁港"
        ])
    }
}
