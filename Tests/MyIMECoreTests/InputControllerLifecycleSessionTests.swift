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
        _ = session.activate(now: 1, tracker: &tracker)
        _ = session.beginDeactivation(
            protectsTransientDeactivation: false,
            tracker: tracker
        )
        session.deferDeactivation(startedAt: 2)

        let activation = session.activate(now: 2.5, tracker: &tracker)

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
        _ = session.activate(now: 0, tracker: &tracker)
        let deactivation = session.beginDeactivation(
            protectsTransientDeactivation: false,
            tracker: tracker
        )
        session.deferDeactivation(startedAt: 0)
        _ = session.activate(now: 0.1, tracker: &tracker)

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
        _ = session.activate(now: 0, tracker: &tracker)
        let older = session.beginDeactivation(
            protectsTransientDeactivation: false,
            tracker: tracker
        )
        let newer = session.beginDeactivation(
            protectsTransientDeactivation: false,
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
        _ = controllerA.activate(now: 0, tracker: &tracker)
        let deactivation = controllerA.beginDeactivation(
            protectsTransientDeactivation: false,
            tracker: tracker
        )
        var controllerB = InputControllerLifecycleSession(
            clientBundleIdentifier: "com.microsoft.VSCode"
        )
        _ = controllerB.activate(now: 0.1, tracker: &tracker)

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
        _ = session.activate(now: 0, tracker: &tracker)
        let deactivation = session.beginDeactivation(
            protectsTransientDeactivation: true,
            tracker: tracker
        )

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
        _ = session.activate(now: 0, tracker: &tracker)

        #expect(!session.close(tracker: tracker).commitsComposition)

        _ = session.activate(now: 1, tracker: &tracker)
        _ = session.beginDeactivation(
            protectsTransientDeactivation: false,
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
        _ = controllerA.activate(now: 0, tracker: &tracker)
        _ = controllerA.beginDeactivation(
            protectsTransientDeactivation: false,
            tracker: tracker
        )
        controllerA.deferDeactivation(startedAt: 0)
        var controllerB = InputControllerLifecycleSession(
            clientBundleIdentifier: application
        )
        _ = controllerB.activate(now: 0.1, tracker: &tracker)

        let closure = controllerA.close(tracker: tracker)

        #expect(closure.sessionWasSuperseded)
        #expect(!closure.commitsComposition)
    }

    @Test
    func anonymousClientsAdvanceTheGlobalGeneration() {
        var tracker = InputLifecycleGenerationTracker()
        var session = InputControllerLifecycleSession()

        let first = session.activate(now: 0, tracker: &tracker)
        let second = session.activate(now: 1, tracker: &tracker)

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
}
