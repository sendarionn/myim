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
            excluding: []
        ) == matches)
    }
}
