import Testing
@testable import MyIMECore

@Suite
struct InformationPanelInteractionPolicyTests {
    @Test
    func visiblePanelTreatsAuxiliaryFocusAsInteraction() {
        #expect(InformationPanelInteractionPolicy.shouldBeginInteraction(
            isPresentingInformation: true,
            frontmostClientRole: .auxiliaryApplication
        ))
    }

    @Test
    func ordinaryApplicationFocusIsNotPanelInteraction() {
        #expect(!InformationPanelInteractionPolicy.shouldBeginInteraction(
            isPresentingInformation: true,
            frontmostClientRole: .sourceApplication
        ))
    }

    @Test
    func hiddenPanelDoesNotPreserveComposition() {
        #expect(!InformationPanelInteractionPolicy.shouldBeginInteraction(
            isPresentingInformation: false,
            frontmostClientRole: .auxiliaryApplication
        ))
    }
}
