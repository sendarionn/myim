import Foundation

public struct TransientCompositionGuard: Sendable {
    private var suppressionDeadline: TimeInterval?

    public init() {}

    public mutating func recordActivation(
        resumingDeactivation: Bool,
        hasComposition: Bool,
        now: TimeInterval,
        gracePeriod: TimeInterval
    ) {
        suppressionDeadline = resumingDeactivation && hasComposition
            ? now + max(gracePeriod, 0)
            : nil
    }

    public mutating func consumeSystemCommitSuppression(
        now: TimeInterval,
        hasComposition: Bool
    ) -> Bool {
        guard let suppressionDeadline else { return false }
        guard hasComposition, now <= suppressionDeadline else {
            self.suppressionDeadline = nil
            return false
        }
        return true
    }

    public func isProtectingTransientDeactivation(
        now: TimeInterval,
        hasComposition: Bool
    ) -> Bool {
        guard let suppressionDeadline else { return false }
        return hasComposition && now <= suppressionDeadline
    }

    public mutating func reset() {
        suppressionDeadline = nil
    }
}
