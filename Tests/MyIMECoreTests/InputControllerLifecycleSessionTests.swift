import Testing
@testable import MyIMECore

@Suite
struct InputControllerLifecycleSessionTests {
    private let application = "com.apple.TextEdit"

    @Test
    func resumesAPendingDeactivationAndReportsItsDuration() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = activate(&session, now: 1, hasComposition: false, tracker: &tracker)
        _ = session.beginDeactivation(
            now: 0,
            hasComposition: false,
            tracker: tracker
        )
        session.deferDeactivation(startedAt: 2)

        let activation = activate(&session, now: 2.5, hasComposition: false, tracker: &tracker)

        #expect(activation.resumesTransientDeactivation)
        #expect(activation.deactivationDuration == 0.5)
        #expect(session.isActive)
        #expect(!session.hasPendingDeactivation)
    }

    @Test
    func ignoresADeactivationAfterReactivation() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = activate(&session, now: 0, hasComposition: false, tracker: &tracker)
        let deactivation = session.beginDeactivation(
            now: 0,
            hasComposition: false,
            tracker: tracker
        )
        session.deferDeactivation(startedAt: 0)
        _ = activate(&session, now: 0.1, hasComposition: false, tracker: &tracker)

        #expect(session.outcome(
            of: deactivation,
            tracker: tracker,
            frontmostApplication: nil
        ) == .ignored)
    }

    @Test
    func ignoresAnOlderDeactivationAfterANewerOne() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = activate(&session, now: 0, hasComposition: false, tracker: &tracker)
        let older = session.beginDeactivation(
            now: 0,
            hasComposition: false,
            tracker: tracker
        )
        let newer = session.beginDeactivation(
            now: 0,
            hasComposition: false,
            tracker: tracker
        )

        #expect(session.outcome(
            of: older,
            tracker: tracker,
            frontmostApplication: nil
        ) == .ignored)
        #expect(session.outcome(
            of: newer,
            tracker: tracker,
            frontmostApplication: nil
        ) == .commit)
    }

    @Test
    func retiresADeactivationSupersededByAnotherController() {
        var tracker = InputLifecycleGenerationTracker()
        var controllerA = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = activate(&controllerA, now: 0, hasComposition: false, tracker: &tracker)
        let deactivation = controllerA.beginDeactivation(
            now: 0,
            hasComposition: false,
            tracker: tracker
        )
        var controllerB = InputControllerLifecycleSession(
            clientBundleIdentifier: "com.microsoft.VSCode"
        )
        _ = activate(&controllerB, now: 0.1, hasComposition: false, tracker: &tracker)

        #expect(controllerA.outcome(
            of: deactivation,
            tracker: tracker,
            frontmostApplication: "com.microsoft.VSCode"
        ) == .superseded)
    }

    @Test
    func keepsTheCompositionForATransientFollowUpDeactivation() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = activate(&session, now: 0, hasComposition: true, tracker: &tracker)
        _ = session.beginDeactivation(now: 1, hasComposition: true, tracker: tracker)
        session.deferDeactivation(startedAt: 1)
        _ = activate(&session, now: 1.1, hasComposition: true, tracker: &tracker)
        let deactivation = session.beginDeactivation(
            now: 1.2,
            hasComposition: true,
            tracker: tracker
        )

        #expect(deactivation.protectsTransientDeactivation)
        #expect(session.outcome(
            of: deactivation,
            tracker: tracker,
            frontmostApplication: application
        ) == .transientFollowUp)
        #expect(session.outcome(
            of: deactivation,
            tracker: tracker,
            frontmostApplication: "io.github.sendarionn.myim.external-browser"
        ) == .transientFollowUp)
        #expect(session.outcome(
            of: deactivation,
            tracker: tracker,
            frontmostApplication: "com.microsoft.VSCode"
        ) == .commit)
    }

    @Test
    func commitsOnCloseOnlyWhileADeactivationIsPending() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = activate(&session, now: 0, hasComposition: false, tracker: &tracker)

        #expect(!session.close(tracker: tracker).commitsComposition)

        _ = activate(&session, now: 1, hasComposition: false, tracker: &tracker)
        _ = session.beginDeactivation(
            now: 0,
            hasComposition: false,
            tracker: tracker
        )
        session.deferDeactivation(startedAt: 1)

        let closure = session.close(tracker: tracker)

        #expect(closure.deactivationWasPending)
        #expect(!closure.sessionWasSuperseded)
        #expect(closure.commitsComposition)
        #expect(!session.isActive)
    }

    @Test
    func delayedCloseFromASupersededControllerDoesNotCommit() {
        var tracker = InputLifecycleGenerationTracker()
        var controllerA = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = activate(&controllerA, now: 0, hasComposition: false, tracker: &tracker)
        _ = controllerA.beginDeactivation(
            now: 0,
            hasComposition: false,
            tracker: tracker
        )
        controllerA.deferDeactivation(startedAt: 0)
        var controllerB = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = activate(&controllerB, now: 0.1, hasComposition: false, tracker: &tracker)

        let closure = controllerA.close(tracker: tracker)

        #expect(closure.sessionWasSuperseded)
        #expect(!closure.commitsComposition)
    }

    @Test
    func anonymousClientsAdvanceTheGlobalGeneration() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession()

        let first = activate(&session, now: 0, hasComposition: false, tracker: &tracker)
        let second = activate(&session, now: 1, hasComposition: false, tracker: &tracker)

        #expect(second.globalGeneration == first.globalGeneration + 1)
        #expect(session.applicationGeneration == nil)
    }

    @Test
    func auxiliaryClientsDoNotParticipateInTheLifecycle() {
        var session = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )

        let role = session.updateClient(
            bundleIdentifier: "io.github.sendarionn.myim.external-browser"
        )

        #expect(role == .auxiliaryApplication)
        #expect(!session.participatesInInputSessionLifecycle)
    }

    @Test
    func protectsAResumedCompositionUntilTheGracePeriodEnds() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = activate(&session, now: 0, hasComposition: true, tracker: &tracker)
        _ = session.beginDeactivation(now: 1, hasComposition: true, tracker: tracker)
        session.deferDeactivation(startedAt: 1)
        _ = activate(&session, now: 1.2, hasComposition: true, tracker: &tracker)

        let suppressed1 = session.consumeSystemCommitSuppression(now: 1.5, hasComposition: true)
        #expect(suppressed1)

        let deactivation = session.beginDeactivation(
            now: 1.6,
            hasComposition: true,
            tracker: tracker
        )
        #expect(deactivation.protectsTransientDeactivation)
        let suppressed2 = session.consumeSystemCommitSuppression(now: 2.0, hasComposition: true)
        #expect(!suppressed2)
        #expect(!session.beginDeactivation(
            now: 2.1,
            hasComposition: true,
            tracker: tracker
        ).protectsTransientDeactivation)
    }

    @Test
    func doesNotProtectAFreshActivationOrAnEmptyComposition() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = activate(&session, now: 0, hasComposition: true, tracker: &tracker)

        let suppressed3 = session.consumeSystemCommitSuppression(now: 0.1, hasComposition: true)
        #expect(!suppressed3)

        _ = session.beginDeactivation(now: 1, hasComposition: false, tracker: tracker)
        session.deferDeactivation(startedAt: 1)
        _ = activate(&session, now: 1.1, hasComposition: false, tracker: &tracker)

        let suppressed4 = session.consumeSystemCommitSuppression(now: 1.2, hasComposition: true)
        #expect(!suppressed4)
    }

    @Test
    func closingDropsTheTransientCommitProtection() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = session.beginDeactivation(now: 0, hasComposition: true, tracker: tracker)
        session.deferDeactivation(startedAt: 0)
        _ = activate(&session, now: 0.1, hasComposition: true, tracker: &tracker)

        _ = session.close(tracker: tracker)

        let suppressed5 = session.consumeSystemCommitSuppression(now: 0.2, hasComposition: true)
        #expect(!suppressed5)
    }

    @Test
    func tracksTheActivationKeyWindowUntilCleared() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        #expect(!session.isWithinActivationKeyWindow(now: 0))

        _ = activate(&session, now: 10, hasComposition: false, tracker: &tracker)

        #expect(session.isWithinActivationKeyWindow(now: 10.1))
        #expect(!session.isWithinActivationKeyWindow(now: 10.3))

        session.clearActivationTime()

        #expect(!session.isWithinActivationKeyWindow(now: 10.1))
    }

    private func activate(
        _ session: inout InputControllerLifecycleSession,
        now: Double,
        hasComposition: Bool,
        tracker: inout InputLifecycleGenerationTracker
    ) -> InputControllerActivation {
        session.activate(
            now: now,
            hasComposition: hasComposition,
            transientDeactivationGracePeriod: 0.75,
            tracker: &tracker
        )
    }
}
