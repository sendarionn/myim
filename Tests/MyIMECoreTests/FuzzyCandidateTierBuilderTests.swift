import Testing
@testable import MyIMECore

struct FuzzyCandidateTierBuilderTests {
    @Test func placesCloseWholeReadingCorrectionsBeforeDistantOnes() {
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

        let tiers = FuzzyCandidateTierBuilder.build(
            directTypoMatches: [distant, close]
        )

        #expect(tiers.flatMap { $0.flatMap(\.candidates) } == [
            "評価", "漁港"
        ])
    }
}
