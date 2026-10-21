import Testing
@testable import MyIMECore

@Suite
struct InputPanelDismissalPolicyTests {
    @Test
    func emptyInputPreservesNoPanels() {
        #expect(!InputPanelDismissalPolicy.inputBecameEmpty
            .preservesExternalInformation)
        #expect(!InputPanelDismissalPolicy.inputBecameEmpty.preservesCalendar)
        #expect(!InputPanelDismissalPolicy.inputBecameEmpty.preservesTime)
        #expect(InputPanelDismissalPolicy.inputBecameEmpty.panelsToDismiss
            == Set(InputPanelKind.allCases))
    }

    /// Deleting the whole emoji search keeps the panel open, so it shows
    /// its initial emojis again, while the candidate panels still close
    @Test
    func clearedEmojiSearchKeepsOnlyTheEmojiPanel() {
        let policy = InputPanelDismissalPolicy.emojiSearchBecameEmpty

        #expect(policy.panelsToDismiss
            == Set(InputPanelKind.allCases).subtracting([.emoji]))
        #expect(!InputPanelDismissalPolicy.inputBecameEmpty.preservesEmoji)
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
        let time = InputPanelDismissalPolicy.deactivation(
            isExternalInformationInteractionActive: false,
            isCalendarInteractionActive: false,
            isTimeInteractionActive: true
        )

        #expect(external.preservesExternalInformation)
        #expect(!external.preservesCalendar)
        #expect(!calendar.preservesExternalInformation)
        #expect(calendar.preservesCalendar)
        #expect(!calendar.cancelsCalendarWork)
        #expect(external.cancelsCalendarWork)
        #expect(external.panelsToDismiss.contains(.translationCandidates))
        #expect(external.panelsToDismiss.contains(.primaryCandidatePanel))
        #expect(!external.panelsToDismiss.contains(.externalInformation))
        #expect(calendar.panelsToDismiss.contains(.translationCandidates))
        #expect(!calendar.panelsToDismiss.contains(.primaryCandidatePanel))
        #expect(!calendar.panelsToDismiss.contains(.calendar))
        #expect(time.preservesTime)
        #expect(!time.cancelsTimeWork)
        #expect(!time.panelsToDismiss.contains(.time))
        #expect(!time.panelsToDismiss.contains(.primaryCandidatePanel))
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
