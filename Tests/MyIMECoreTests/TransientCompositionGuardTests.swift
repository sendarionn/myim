import Testing
@testable import MyIMECore

@Suite
struct TransientCompositionGuardTests {
    @Test
    func suppressesRepeatedCommitsAfterTransientReactivation() {
        var guardState = TransientCompositionGuard()
        guardState.recordActivation(
            resumingDeactivation: true,
            hasComposition: true,
            now: 10,
            gracePeriod: 0.35
        )

        let firstCommitIsSuppressed = guardState.consumeSystemCommitSuppression(
            now: 10.1,
            hasComposition: true
        )
        let secondCommitIsSuppressed = guardState.consumeSystemCommitSuppression(
            now: 10.2,
            hasComposition: true
        )

        #expect(firstCommitIsSuppressed)
        #expect(secondCommitIsSuppressed)
    }

    @Test
    func doesNotSuppressCommitAfterGracePeriod() {
        var guardState = TransientCompositionGuard()
        guardState.recordActivation(
            resumingDeactivation: true,
            hasComposition: true,
            now: 10,
            gracePeriod: 0.35
        )

        let commitIsSuppressed = guardState.consumeSystemCommitSuppression(
            now: 10.36,
            hasComposition: true
        )

        #expect(!commitIsSuppressed)
    }

    @Test
    func ordinaryActivationDoesNotSuppressCommit() {
        var guardState = TransientCompositionGuard()
        guardState.recordActivation(
            resumingDeactivation: false,
            hasComposition: true,
            now: 10,
            gracePeriod: 0.35
        )

        let commitIsSuppressed = guardState.consumeSystemCommitSuppression(
            now: 10.1,
            hasComposition: true
        )

        #expect(!commitIsSuppressed)
    }

    @Test
    func protectsImmediateSecondDeactivationAfterReactivation() {
        var guardState = TransientCompositionGuard()
        guardState.recordActivation(
            resumingDeactivation: true,
            hasComposition: true,
            now: 10,
            gracePeriod: 0.75
        )
        _ = guardState.consumeSystemCommitSuppression(
            now: 10.001,
            hasComposition: true
        )

        #expect(guardState.isProtectingTransientDeactivation(
            now: 10.002,
            hasComposition: true
        ))
        #expect(!guardState.isProtectingTransientDeactivation(
            now: 10.8,
            hasComposition: true
        ))
    }
}
