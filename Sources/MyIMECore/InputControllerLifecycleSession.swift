import Foundation

public struct InputControllerActivation: Equatable, Sendable {
    public let resumesTransientDeactivation: Bool
    public let deactivationDuration: TimeInterval?
    public let globalGeneration: UInt
}

public struct InputControllerDeactivation: Equatable, Sendable {
    public let lifecycleGeneration: UInt
    public let application: String?
    public let applicationGeneration: UInt?
    public let globalGeneration: UInt
    public let protectsTransientDeactivation: Bool
}

public enum InputControllerDeactivationOutcome: Equatable, Sendable {
    case ignored
    case superseded
    case transientFollowUp
    case commit
}

public struct InputControllerClosure: Equatable, Sendable {
    public let deactivationWasPending: Bool
    public let sessionWasSuperseded: Bool

    public var commitsComposition: Bool {
        InputControllerClosurePolicy.shouldCommitComposition(
            deactivationWasPending: deactivationWasPending,
            sessionWasSuperseded: sessionWasSuperseded
        )
    }
}

public struct InputControllerLifecycleSession: Equatable, Sendable {
    public private(set) var clientBundleIdentifier: String?
    public private(set) var clientRole: InputClientRole
    public private(set) var isActive = false
    public private(set) var applicationGeneration: UInt?
    public private(set) var globalGeneration: UInt?
    public private(set) var pendingDeactivationStartedAt: TimeInterval?
    private var lifecycleGeneration: UInt = 0

    public init(clientBundleIdentifier: String? = nil) {
        self.clientBundleIdentifier = clientBundleIdentifier
        clientRole = InputClientRole.resolve(
            bundleIdentifier: clientBundleIdentifier
        )
    }

    public var participatesInInputSessionLifecycle: Bool {
        clientRole.participatesInInputSessionLifecycle
    }

    public var hasPendingDeactivation: Bool {
        pendingDeactivationStartedAt != nil
    }

    @discardableResult
    public mutating func updateClient(
        bundleIdentifier: String?
    ) -> InputClientRole {
        clientBundleIdentifier = bundleIdentifier
        clientRole = InputClientRole.resolve(bundleIdentifier: bundleIdentifier)
        return clientRole
    }

    public mutating func activate(
        now: TimeInterval,
        tracker: inout InputLifecycleGenerationTracker
    ) -> InputControllerActivation {
        let resumesTransientDeactivation = hasPendingDeactivation
        let deactivationDuration = pendingDeactivationStartedAt.map {
            max(now - $0, 0)
        }
        lifecycleGeneration &+= 1
        pendingDeactivationStartedAt = nil
        isActive = true
        let globalGeneration: UInt
        if let clientBundleIdentifier {
            applicationGeneration = tracker.recordActivation(
                for: clientBundleIdentifier
            )
            globalGeneration = tracker.globalGeneration
        } else {
            applicationGeneration = nil
            globalGeneration = tracker.recordAnonymousActivation()
        }
        self.globalGeneration = globalGeneration
        return InputControllerActivation(
            resumesTransientDeactivation: resumesTransientDeactivation,
            deactivationDuration: deactivationDuration,
            globalGeneration: globalGeneration
        )
    }

    public mutating func beginDeactivation(
        protectsTransientDeactivation: Bool,
        tracker: InputLifecycleGenerationTracker
    ) -> InputControllerDeactivation {
        lifecycleGeneration &+= 1
        isActive = false
        return InputControllerDeactivation(
            lifecycleGeneration: lifecycleGeneration,
            application: clientBundleIdentifier,
            applicationGeneration: applicationGeneration,
            globalGeneration: globalGeneration ?? tracker.globalGeneration,
            protectsTransientDeactivation: protectsTransientDeactivation
        )
    }

    public mutating func deferDeactivation(startedAt: TimeInterval) {
        pendingDeactivationStartedAt = startedAt
    }

    public mutating func clearPendingDeactivation() {
        pendingDeactivationStartedAt = nil
    }

    public func outcome(
        of deactivation: InputControllerDeactivation,
        tracker: InputLifecycleGenerationTracker,
        frontmostApplication: String?
    ) -> InputControllerDeactivationOutcome {
        guard !isActive,
              lifecycleGeneration == deactivation.lifecycleGeneration else {
            return .ignored
        }
        let globalSessionWasSuperseded = tracker.shouldRetireController(
            globalGeneration: deactivation.globalGeneration
        )
        let applicationSessionWasSuperseded: Bool
        if let application = deactivation.application,
           let applicationGeneration = deactivation.applicationGeneration {
            applicationSessionWasSuperseded = tracker.shouldRetireController(
                application: application,
                generation: applicationGeneration,
                globalGeneration: deactivation.globalGeneration
            )
        } else {
            applicationSessionWasSuperseded = false
        }
        if globalSessionWasSuperseded || applicationSessionWasSuperseded {
            return .superseded
        }
        if deactivation.protectsTransientDeactivation,
           let application = deactivation.application,
           frontmostApplication == application
            || InputClientRole.resolve(
                bundleIdentifier: frontmostApplication
            ) == .auxiliaryApplication {
            return .transientFollowUp
        }
        return .commit
    }

    public mutating func close(
        tracker: InputLifecycleGenerationTracker
    ) -> InputControllerClosure {
        lifecycleGeneration &+= 1
        let deactivationWasPending = hasPendingDeactivation
        let sessionWasSuperseded = globalGeneration.map {
            tracker.shouldRetireController(
                application: clientBundleIdentifier,
                applicationGeneration: applicationGeneration,
                globalGeneration: $0
            )
        } ?? false
        pendingDeactivationStartedAt = nil
        isActive = false
        return InputControllerClosure(
            deactivationWasPending: deactivationWasPending,
            sessionWasSuperseded: sessionWasSuperseded
        )
    }
}
