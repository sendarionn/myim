import Testing
@testable import MyIMECore

/// The state InputController keeps while moving between the primary and
/// secondary candidate panels with the left and right arrows
@Suite
struct PanelNavigationTests {
    private let pageSize = 4

    @Test
    func enteringTheSecondaryPanelSelectsTheSameRow() {
        let session = fuzzySession(count: 6)

        #expect(session.indexAlignedWithStandardCandidate(
            standardSelectedIndex: 6,
            maximumCount: pageSize
        ) == 2)
    }

    @Test
    func returningToThePrimaryPanelKeepsItsPageAndRow() {
        var session = fuzzySession(count: 6)
        session.select(index: 1)

        #expect(session.standardCandidateIndexAlignedWithSelection(
            standardCandidateCount: 10,
            currentNormalIndex: 5,
            maximumCount: pageSize
        ) == 5)
    }

    @Test
    func returningLeavesTheSecondaryPanelWithoutAHighlight() {
        var session = fuzzySession(count: 6)
        session.select(index: 5)

        session.select(index: nil)
        let redrawn = session.initialPage(maximumCount: pageSize)

        #expect(session.selectedIndex == nil)
        #expect(redrawn?.selectedIndex == nil)
        #expect(redrawn?.candidates.map(\.storageText)
            == ["候補0", "候補1", "候補2", "候補3"])
    }

    @Test
    func keysActOnThePrimaryPanelAfterReturning() {
        let whileSecondary = InputInteractionState.resolve(
            hasInput: true,
            isRegisteringDictionary: false,
            hasSelectedCandidate: true,
            hasSelectedFuzzyCandidate: true,
            hasSelectedNextInput: false
        )
        let afterReturning = InputInteractionState.resolve(
            hasInput: true,
            isRegisteringDictionary: false,
            hasSelectedCandidate: true,
            hasSelectedFuzzyCandidate: false,
            hasSelectedNextInput: false
        )

        #expect(whileSecondary == .selectingFuzzyCandidate)
        #expect(afterReturning == .selectingCandidate)
    }

    @Test
    func reenteringAfterReturningStartsFromTheAlignedRowAgain() {
        var session = fuzzySession(count: 6)
        session.select(index: 3)
        session.select(index: nil)

        let index = session.indexAlignedWithStandardCandidate(
            standardSelectedIndex: 1,
            maximumCount: pageSize
        )
        let selected = index.flatMap { session.select(index: $0) }

        #expect(selected?.storageText == "候補1")
        #expect(session.selectedIndex == 1)
    }

    private func fuzzySession(count: Int) -> FuzzyCandidateSession {
        FuzzyCandidateSession(candidates: (0..<count).map {
            FuzzyCandidate(storageText: "候補\($0)", reading: "kouho", distance: 1)
        })
    }
}
