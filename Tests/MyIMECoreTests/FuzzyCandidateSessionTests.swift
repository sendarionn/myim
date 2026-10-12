import Testing
@testable import MyIMECore

@Suite
struct FuzzyCandidateSessionTests {
    @Test
    func buildsCandidatesInTierOrderAndRemovesDuplicateCandidates() {
        var session = FuzzyCandidateSession()

        let changed = session.replace(
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
        #expect(session.candidates.map(\.storageText)
            == ["通用候補", "通常候補"])
    }

    @Test
    func wrapsSelectionAndExposesTheSelectedCandidate() {
        var session = FuzzyCandidateSession(candidates: [
            FuzzyCandidate(storageText: "候補1", reading: "1", distance: 1),
            FuzzyCandidate(storageText: "候補2", reading: "2", distance: 1)
        ])

        let lastIndex = session.index(after: -1)
        _ = session.select(index: lastIndex)

        #expect(session.selectedIndex == 1)
        #expect(session.selectedCandidate?.storageText == "候補2")
    }

    @Test
    func alignsMovementWithTheVisibleRowInBothPanels() {
        var session = FuzzyCandidateSession(candidates: (0..<6).map {
            FuzzyCandidate(
                storageText: "候補\($0)",
                reading: "\($0)",
                distance: 1
            )
        })

        let fuzzyIndex = session.indexAlignedWithStandardCandidate(
            standardSelectedIndex: 6,
            maximumCount: 4
        )
        _ = session.select(index: fuzzyIndex)
        let standardIndex = session.standardCandidateIndexAlignedWithSelection(
            standardCandidateCount: 7,
            currentNormalIndex: 5,
            maximumCount: 4
        )

        #expect(fuzzyIndex == 2)
        #expect(standardIndex == 6)
    }

    @Test
    func createsInitialAndSelectedPages() {
        var session = FuzzyCandidateSession(candidates: (0..<6).map {
            FuzzyCandidate(
                storageText: "候補\($0)",
                reading: "\($0)",
                distance: 1
            )
        })

        let initial = session.initialPage(maximumCount: 4)
        _ = session.select(index: 5)
        let selected = session.selectedPage(maximumCount: 4)

        #expect(initial?.candidates.map(\.storageText)
            == ["候補0", "候補1", "候補2", "候補3"])
        #expect(initial?.selectedIndex == nil)
        #expect(selected?.candidates.map(\.storageText)
            == ["候補4", "候補5"])
        #expect(selected?.selectedIndex == 1)
    }

    @Test
    func replacesSelectionByCandidateName() {
        var session = FuzzyCandidateSession(candidates: [
            FuzzyCandidate(storageText: "候補1", reading: "1", distance: 1),
            FuzzyCandidate(storageText: "候補2", reading: "2", distance: 1)
        ])

        let selected = session.select(candidate: "候補2")

        #expect(selected?.storageText == "候補2")
        #expect(session.selectedIndex == 1)
    }

    @Test
    func preservesLearnedCompoundBoundariesAndDoesNotMarkItLearnable() {
        var session = FuzzyCandidateSession()
        session.replace(
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

        let fuzzyCandidate = session.select(index: 0)

        #expect(fuzzyCandidate?.isLearnable == false)
        #expect(fuzzyCandidate?.sourceTokens == ["東京都", "中野区"])
        #expect(fuzzyCandidate?.sourceReadings == ["toukyouto", "nakanoku"])
    }
}
