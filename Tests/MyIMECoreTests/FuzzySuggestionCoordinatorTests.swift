import Testing
@testable import MyIMECore

@Suite
struct FuzzySuggestionCoordinatorTests {
    @Test
    func buildsSuggestionsInTierOrderAndRemovesDuplicateCandidates() {
        var coordinator = FuzzySuggestionCoordinator()

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
        #expect(coordinator.suggestions.map(\.candidate)
            == ["通用候補", "通常候補"])
    }

    @Test
    func wrapsSelectionAndExposesTheSelectedSuggestion() {
        var coordinator = FuzzySuggestionCoordinator(suggestions: [
            FuzzySuggestion(candidate: "候補1", reading: "1", distance: 1),
            FuzzySuggestion(candidate: "候補2", reading: "2", distance: 1)
        ])

        let lastIndex = coordinator.index(after: -1)
        _ = coordinator.select(index: lastIndex)

        #expect(coordinator.selectedIndex == 1)
        #expect(coordinator.selectedSuggestion?.candidate == "候補2")
    }

    @Test
    func alignsMovementWithTheVisibleRowInBothPanels() {
        var coordinator = FuzzySuggestionCoordinator(suggestions: (0..<6).map {
            FuzzySuggestion(
                candidate: "候補\($0)",
                reading: "\($0)",
                distance: 1
            )
        })

        let fuzzyIndex = coordinator.indexAlignedWithNormalCandidate(
            normalSelectedIndex: 6,
            maximumCount: 4
        )
        _ = coordinator.select(index: fuzzyIndex)
        let normalIndex = coordinator.normalCandidateIndexAlignedWithSelection(
            normalCandidateCount: 7,
            currentNormalIndex: 5,
            maximumCount: 4
        )

        #expect(fuzzyIndex == 2)
        #expect(normalIndex == 6)
    }

    @Test
    func createsInitialAndSelectedPages() {
        var coordinator = FuzzySuggestionCoordinator(suggestions: (0..<6).map {
            FuzzySuggestion(
                candidate: "候補\($0)",
                reading: "\($0)",
                distance: 1
            )
        })

        let initial = coordinator.initialPage(maximumCount: 4)
        _ = coordinator.select(index: 5)
        let selected = coordinator.selectedPage(maximumCount: 4)

        #expect(initial?.suggestions.map(\.candidate)
            == ["候補0", "候補1", "候補2", "候補3"])
        #expect(initial?.selectedIndex == nil)
        #expect(selected?.suggestions.map(\.candidate)
            == ["候補4", "候補5"])
        #expect(selected?.selectedIndex == 1)
    }

    @Test
    func replacesSelectionByCandidateName() {
        var coordinator = FuzzySuggestionCoordinator(suggestions: [
            FuzzySuggestion(candidate: "候補1", reading: "1", distance: 1),
            FuzzySuggestion(candidate: "候補2", reading: "2", distance: 1)
        ])

        let selected = coordinator.select(candidate: "候補2")

        #expect(selected?.candidate == "候補2")
        #expect(coordinator.selectedIndex == 1)
    }
}
