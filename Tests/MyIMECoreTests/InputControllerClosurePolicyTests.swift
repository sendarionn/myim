import Testing
@testable import MyIMECore

@Suite struct InputControllerClosurePolicyTests {
    @Test func staleControllerNeverCommitsDuringDelayedClose() {
        #expect(!InputControllerClosurePolicy.shouldCommitComposition(
            deactivationWasPending: true,
            sessionWasSuperseded: true
        ))
    }

    @Test func legitimatePendingDeactivationStillCommits() {
        #expect(InputControllerClosurePolicy.shouldCommitComposition(
            deactivationWasPending: true,
            sessionWasSuperseded: false
        ))
    }

    @Test func closeWithoutDeactivationDoesNotInventACommit() {
        #expect(!InputControllerClosurePolicy.shouldCommitComposition(
            deactivationWasPending: false,
            sessionWasSuperseded: false
        ))
    }
}
