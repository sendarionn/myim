import Testing
@testable import MyIMECore

@Suite
struct CandidateFilterInputSessionTests {
    @Test
    func ownsDraftEditingAndStageTransitions() {
        var session = CandidateFilterInputSession()

        session.beginDraft()
        session.appendToDraft("ki")
        session.enterFilterStage()

        #expect(session.draft?.input == "ki")
        #expect(session.draft?.stage == .filter)
        let deletedDuringFilter = session.deleteBackwardFromDraft()
        let returnedToConversion = session.returnToConversionStage()
        let deletedDuringConversion = session.deleteBackwardFromDraft()
        #expect(!deletedDuringFilter)
        #expect(returnedToConversion)
        #expect(deletedDuringConversion)
        #expect(session.draft?.input == "k")
    }

    @Test
    func wrapsDraftSelectionWithoutLeakingIndexManagement() {
        var session = CandidateFilterInputSession()
        session.beginDraft()
        session.updateDraftChoices([
            .input("木"),
            .input("気")
        ])

        let movedBackward = session.moveDraftSelection(by: -1)
        #expect(movedBackward)
        #expect(session.draft?.selectedIndex == 1)
        let movedForward = session.moveDraftSelection(by: 1)
        #expect(movedForward)
        #expect(session.draft?.selectedIndex == 0)
    }

    @Test
    func selectingConvertedInputKeepsTheOriginalReading() {
        var session = CandidateFilterInputSession()
        session.beginDraft()
        session.appendToDraft("ki")
        session.updateDraftChoices([.input("木")])
        _ = session.moveDraftSelection(by: 1)

        let result = session.applySelectedChoice()

        #expect(result == .convertedInput(value: "木", reading: "ki"))
        #expect(session.draft?.input == "木")
        #expect(session.draft?.stage == .filter)
        #expect(session.draft?.selectedIndex == nil)
    }

    @Test
    func appliesAndRemovesConditionsAsOneStateTransition() {
        var session = CandidateFilterInputSession()
        session.beginDraft()
        session.updateDraftChoices([
            .filter(.apply(.contains("木")))
        ])
        _ = session.moveDraftSelection(by: 1)

        #expect(session.applySelectedChoice() == .conditionsChanged)
        #expect(session.conditions == [.contains("木")])
        #expect(session.draft == nil)

        session.beginDraft()
        session.updateDraftChoices([
            .filter(.remove(index: 0, label: "「木」を含む"))
        ])
        _ = session.moveDraftSelection(by: 1)

        #expect(session.applySelectedChoice() == .conditionsChanged)
        #expect(session.conditions.isEmpty)
    }

    @Test
    func resetClearsDraftAndConditionsTogether() {
        var session = CandidateFilterInputSession()
        session.beginDraft()
        session.updateDraftChoices([
            .filter(.apply(.characterCount(2)))
        ])
        _ = session.moveDraftSelection(by: 1)
        _ = session.applySelectedChoice()
        session.beginDraft()

        session.reset()

        #expect(session.conditions.isEmpty)
        #expect(session.draft == nil)
    }
}
