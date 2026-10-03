@preconcurrency import AppKit
import MyIMECore

final class InputLifecycleCoordinator {
    static let transientDeactivationDelay: TimeInterval = 0.75
    private static var generationTracker = InputLifecycleGenerationTracker()

    private(set) var session: InputControllerLifecycleSession
    private var pendingDeactivation: DispatchWorkItem?

    init(clientBundleIdentifier: String?) {
        session = InputControllerLifecycleSession(
            clientBundleIdentifier: clientBundleIdentifier
        )
    }

    deinit {
        pendingDeactivation?.cancel()
    }

    var clientBundleIdentifier: String? {
        session.clientBundleIdentifier
    }

    var participatesInInputSessionLifecycle: Bool {
        session.participatesInInputSessionLifecycle
    }

    var isActive: Bool {
        session.isActive
    }

    var applicationGeneration: UInt? {
        session.applicationGeneration
    }

    var globalGeneration: UInt? {
        session.globalGeneration
    }

    @discardableResult
    func updateClient(bundleIdentifier: String?) -> InputClientRole {
        session.updateClient(bundleIdentifier: bundleIdentifier)
    }

    func activate(
        now: TimeInterval,
        hasComposition: Bool
    ) -> InputControllerActivation {
        pendingDeactivation?.cancel()
        pendingDeactivation = nil
        return session.activate(
            now: now,
            hasComposition: hasComposition,
            transientDeactivationGracePeriod: Self.transientDeactivationDelay,
            tracker: &Self.generationTracker
        )
    }

    func beginDeactivation(
        hasComposition: Bool
    ) -> InputControllerDeactivation {
        session.beginDeactivation(
            now: ProcessInfo.processInfo.systemUptime,
            hasComposition: hasComposition,
            tracker: Self.generationTracker
        )
    }

    func consumeSystemCommitSuppression(hasComposition: Bool) -> Bool {
        session.consumeSystemCommitSuppression(
            now: ProcessInfo.processInfo.systemUptime,
            hasComposition: hasComposition
        )
    }

    func isWithinActivationKeyWindow() -> Bool {
        session.isWithinActivationKeyWindow(
            now: ProcessInfo.processInfo.systemUptime
        )
    }

    func clearActivationTime() {
        session.clearActivationTime()
    }

    func deferDeactivation(
        _ deactivation: InputControllerDeactivation,
        onOutcome: @escaping (InputControllerDeactivationOutcome) -> Void
    ) {
        pendingDeactivation?.cancel()
        session.deferDeactivation(
            startedAt: ProcessInfo.processInfo.systemUptime
        )
        let workItem = DispatchWorkItem { [weak self] in
            guard let self else { return }
            let outcome = session.outcome(
                of: deactivation,
                tracker: Self.generationTracker,
                frontmostApplication: NSWorkspace.shared
                    .frontmostApplication?.bundleIdentifier
            )
            guard outcome != .ignored else { return }
            onOutcome(outcome)
            clearPendingDeactivation()
        }
        pendingDeactivation = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.transientDeactivationDelay,
            execute: workItem
        )
    }

    func clearPendingDeactivation() {
        pendingDeactivation = nil
        session.clearPendingDeactivation()
    }

    func close() -> InputControllerClosure {
        pendingDeactivation?.cancel()
        pendingDeactivation = nil
        return session.close(tracker: Self.generationTracker)
    }
}
