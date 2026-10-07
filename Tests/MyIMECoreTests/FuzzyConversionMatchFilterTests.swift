import Testing
@testable import MyIMECore

@Suite
struct FuzzyConversionMatchFilterTests {
    @Test
    func excludesOnlyCandidatesAlreadyVisibleInMainPanel() {
        let matches = [
            FuzzyConversionMatch(
                reading: "genninn",
                candidates: ["原因", "原人"],
                distance: 1
            ),
            FuzzyConversionMatch(
                reading: "genninns",
                candidates: ["別候補"],
                distance: 1
            ),
            FuzzyConversionMatch(
                reading: "genin",
                candidates: ["弱い候補"],
                distance: 2
            )
        ]

        let filtered = FuzzyConversionMatchFilter.filtered(
            matches,
            for: "genninn",
            excluding: ["原因"]
        )

        #expect(filtered == [
            FuzzyConversionMatch(
                reading: "genninn",
                candidates: ["原人"],
                distance: 1
            ),
            FuzzyConversionMatch(
                reading: "genninns",
                candidates: ["別候補"],
                distance: 1
            ),
            FuzzyConversionMatch(
                reading: "genin",
                candidates: ["弱い候補"],
                distance: 2
            )
        ])
    }

    @Test
    func retainsInsertionAndTwoEditCorrections() {
        let matches = [
            FuzzyConversionMatch(
                reading: "hitsuyou",
                candidates: ["必要"],
                distance: 2
            ),
            FuzzyConversionMatch(
                reading: "susumete",
                candidates: ["進めて"],
                distance: 1
            )
        ]

        #expect(FuzzyConversionMatchFilter.filtered(
            matches,
            for: "hitsuyou",
            excluding: []
        ) == matches)
    }

    @Test
    func typedLongVowelKeepsOnlyMatchingSurfaceNotation() {
        let matches = [
            FuzzyConversionMatch(
                reading: "byuu",
                candidates: ["ビュー", "別府"],
                distance: 1
            )
        ]

        #expect(FuzzyConversionMatchFilter.filtered(
            matches,
            for: "byu-",
            excluding: []
        ) == [
            FuzzyConversionMatch(
                reading: "byuu",
                candidates: ["ビュー"],
                distance: 1
            )
        ])
    }
}
