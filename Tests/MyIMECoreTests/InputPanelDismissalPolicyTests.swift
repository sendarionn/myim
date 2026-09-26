import Testing
@testable import MyIMECore

@Suite
struct InputPanelDismissalPolicyTests {
    @Test
    func emptyInputPreservesNoPanels() {
        #expect(!InputPanelDismissalPolicy.inputBecameEmpty
            .preservesExternalInformation)
        #expect(!InputPanelDismissalPolicy.inputBecameEmpty.preservesCalendar)
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
    }
}
