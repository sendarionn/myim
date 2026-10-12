import Testing
@testable import MyIMECore

@Suite
struct FuzzyCandidateSessionTests {
    @Test
    func buildsSuggestionsInTierOrderAndRemovesDuplicateCandidates() {
        var coordinator = FuzzyCandidateSession()

        let changed = coordinator.replace(
            matchTiers: [
                [FuzzyConversionMatch(
                    reading: "tuujou",
                    candidates: ["通用候補"],
                    distance: 1
                )],
                [
                    FuzzyConversionMatch(
                        reading: "tsuujou",
                        candidates: ["通常候補"],
                        distance: 0
                    ),
                    FuzzyConversionMatch(
                        reading: "duplicate",
                        candidates: ["通用候補"],
                        distance: 2
                    )
                ]
            ],
            recencyRanks: [:]
        )

        #expect(changed)
        #expect(coordinator.candidates.map(\.candidate)
            == ["通用候補", "通常候補"])
    }

    @Test
    func wrapsSelectionAndExposesTheSelectedSuggestion() {
        var coordinator = FuzzyCandidateSession(candidates: [
            FuzzyCandidate(candidate: "候補1", reading: "1", distance: 1),
            FuzzyCandidate(candidate: "候補2", reading: "2", distance: 1)
        ])

        let lastIndex = coordinator.index(after: -1)
        _ = coordinator.select(index: lastIndex)

        #expect(coordinator.selectedIndex == 1)
        #expect(coordinator.selectedCandidate?.candidate == "候補2")
    }

    @Test
    func alignsMovementWithTheVisibleRowInBothPanels() {
        var coordinator = FuzzyCandidateSession(candidates: (0..<6).map {
            FuzzyCandidate(
                candidate: "候補\($0)",
                reading: "\($0)",
                distance: 1
            )
        })

        let fuzzyIndex = coordinator.indexAlignedWithStandardCandidate(
            standardSelectedIndex: 6,
            maximumCount: 4
        )
        _ = coordinator.select(index: fuzzyIndex)
        let normalIndex = coordinator.standardCandidateIndexAlignedWithSelection(
            standardCandidateCount: 7,
            currentNormalIndex: 5,
            maximumCount: 4
        )

        #expect(fuzzyIndex == 2)
        #expect(normalIndex == 6)
    }

    @Test
    func createsInitialAndSelectedPages() {
        var coordinator = FuzzyCandidateSession(candidates: (0..<6).map {
            FuzzyCandidate(
                candidate: "候補\($0)",
                reading: "\($0)",
                distance: 1
            )
        })

        let initial = coordinator.initialPage(maximumCount: 4)
        _ = coordinator.select(index: 5)
        let selected = coordinator.selectedPage(maximumCount: 4)

        #expect(initial?.candidates.map(\.candidate)
            == ["候補0", "候補1", "候補2", "候補3"])
        #expect(initial?.selectedIndex == nil)
        #expect(selected?.candidates.map(\.candidate)
            == ["候補4", "候補5"])
        #expect(selected?.selectedIndex == 1)
    }

    @Test
    func replacesSelectionByCandidateName() {
        var coordinator = FuzzyCandidateSession(candidates: [
            FuzzyCandidate(candidate: "候補1", reading: "1", distance: 1),
            FuzzyCandidate(candidate: "候補2", reading: "2", distance: 1)
        ])

        let selected = coordinator.select(candidate: "候補2")

        #expect(selected?.candidate == "候補2")
        #expect(coordinator.selectedIndex == 1)
    }

    @Test
    func preservesLearnedCompoundBoundariesAndDoesNotMarkItLearnable() {
        var coordinator = FuzzyCandidateSession()
        coordinator.replace(
            matchTiers: [[FuzzyConversionMatch(
                reading: "toukyoutonakanoku",
                candidates: ["東京都中野区"],
                distance: 0,
                isLearnable: false,
                sourceTokens: ["東京都", "中野区"],
                sourceReadings: ["toukyouto", "nakanoku"]
            )]],
            recencyRanks: [:]
        )

        let suggestion = coordinator.select(index: 0)

        #expect(suggestion?.isLearnable == false)
        #expect(suggestion?.sourceTokens == ["東京都", "中野区"])
        #expect(suggestion?.sourceReadings == ["toukyouto", "nakanoku"])
    }
}
