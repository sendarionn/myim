import Testing
@testable import MyIMECore

@Suite
struct CandidateFilterCoordinatorTests {
    @Test
    func buildsConversionChoicesAndEntersFilterStageAfterSelection() {
        var coordinator = CandidateFilterCoordinator()
        coordinator.beginDraft()
        coordinator.appendToDraft("ki")
        coordinator.refreshChoices(
            queryVariants: { _ in ["ki", "木", "気", "木"] },
            choiceGenerator: CandidateFilterChoiceGenerator()
        )

        #expect(coordinator.draft?.choices == [.input("木"), .input("気")])
        _ = coordinator.moveDraftSelection(by: 1)
        let result = coordinator.applySelectedChoice()

        #expect(result == .convertedInput(value: "木", reading: "ki"))
        #expect(coordinator.draft?.stage == .filter)
    }

    @Test
    func confirmsUnconvertedInputOnlyWhenItHasNoAlternatives() {
        var coordinator = CandidateFilterCoordinator()
        coordinator.beginDraft()
        coordinator.appendToDraft("2")

        let entered = coordinator.enterFilterStageForDirectInput(
            queryVariants: ["2"]
        )

        #expect(entered)
        #expect(coordinator.draft?.stage == .filter)
    }

    @Test
    func escapeReturnsToConversionBeforeRemovingACondition() {
        var coordinator = CandidateFilterCoordinator()
        coordinator.beginDraft()
        coordinator.appendToDraft("木")
        _ = coordinator.enterFilterStageForDirectInput(queryVariants: ["木"])

        #expect(coordinator.escape(hasUnfilteredCandidates: true)
            == .refreshDraftChoices)
        #expect(coordinator.draft?.stage == .conversion)
        #expect(coordinator.escape(hasUnfilteredCandidates: true)
            == .restoreUnfilteredCandidates)
    }

    @Test
    func removesConditionsInReverseOrder() {
        var coordinator = CandidateFilterCoordinator()
        coordinator.beginDraft()
        coordinator.appendToDraft("木")
        _ = coordinator.enterFilterStageForDirectInput(queryVariants: ["木"])
        coordinator.refreshChoices(
            queryVariants: { _ in [] },
            choiceGenerator: CandidateFilterChoiceGenerator()
        )
        _ = coordinator.moveDraftSelection(by: 1)
        #expect(coordinator.applySelectedChoice() == .conditionsChanged)

        #expect(coordinator.removeLastCondition(hasUnfilteredCandidates: true)
            == .restoreUnfilteredCandidates)
        #expect(coordinator.conditions.isEmpty)
    }

    @Test
    func calculatesTheVisiblePageWithoutExposingPageOffsets() {
        var coordinator = CandidateFilterCoordinator()
        coordinator.beginDraft()
        coordinator.appendToDraft("x")
        coordinator.refreshChoices(
            queryVariants: { _ in ["x", "1", "2", "3", "4", "5"] },
            choiceGenerator: CandidateFilterChoiceGenerator()
        )
        for _ in 0..<5 {
            _ = coordinator.moveDraftSelection(by: 1)
        }

        let page = coordinator.visibleDraftPage(maximumCount: 4)

        #expect(page?.choices == [.input("5")])
        #expect(page?.selectedIndex == 0)
    }

    @Test
    func filtersUsingTheCurrentlyAppliedConditions() {
        var coordinator = CandidateFilterCoordinator()
        coordinator.beginDraft()
        coordinator.appendToDraft("2")
        _ = coordinator.enterFilterStageForDirectInput(queryVariants: ["2"])
        coordinator.refreshChoices(
            queryVariants: { _ in [] },
            choiceGenerator: CandidateFilterChoiceGenerator()
        )
        _ = coordinator.moveDraftSelection(by: 1)
        _ = coordinator.applySelectedChoice()

        let filtered = coordinator.filteredCandidates(
            ["木", "森林", "abc"],
            using: CandidateFilter()
        )

        #expect(filtered == ["森林"])
    }
}
