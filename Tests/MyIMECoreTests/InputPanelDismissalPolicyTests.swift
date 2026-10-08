import Testing
@testable import MyIMECore

@Suite
struct InputPanelDismissalPolicyTests {
    @Test
    func emptyInputPreservesNoPanels() {
        #expect(!InputPanelDismissalPolicy.inputBecameEmpty
            .preservesExternalInformation)
        #expect(!InputPanelDismissalPolicy.inputBecameEmpty.preservesCalendar)
        #expect(InputPanelDismissalPolicy.inputBecameEmpty.panelsToDismiss
            == Set(InputPanelKind.allCases))
    }

    @Test
    func deactivationPreservesOnlyThePanelBeingInteractedWith() {
        let external = InputPanelDismissalPolicy.deactivation(
            isExternalInformationInteractionActive: true,
            isCalendarInteractionActive: false
        )
        let calendar = InputPanelDismissalPolicy.deactivation(
            isExternalInformationInteractionActive: false,
            isCalendarInteractionActive: true
        )

        #expect(external.preservesExternalInformation)
        #expect(!external.preservesCalendar)
        #expect(!calendar.preservesExternalInformation)
        #expect(calendar.preservesCalendar)
        #expect(!calendar.cancelsCalendarWork)
        #expect(external.cancelsCalendarWork)
        #expect(external.panelsToDismiss.contains(.translationCandidates))
        #expect(external.panelsToDismiss.contains(.candidate))
        #expect(!external.panelsToDismiss.contains(.externalInformation))
        #expect(calendar.panelsToDismiss.contains(.translationCandidates))
        #expect(!calendar.panelsToDismiss.contains(.candidate))
        #expect(!calendar.panelsToDismiss.contains(.calendar))
    }

    @Test
    func staleControllerCannotDismissAnotherControllersSharedPanel() {
        #expect(!SharedPanelDismissalPolicy.shouldDismiss(
            ownerID: "new-controller",
            requestingControllerID: "old-controller"
        ))
        #expect(SharedPanelDismissalPolicy.shouldDismiss(
            ownerID: "current-controller",
            requestingControllerID: "current-controller"
        ))
        #expect(SharedPanelDismissalPolicy.shouldDismiss(
            ownerID: nil,
            requestingControllerID: "current-controller"
        ))
    }
}
