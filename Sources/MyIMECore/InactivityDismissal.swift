import Foundation

/// Closes a panel after a period without user operations
///
/// User operations restart the countdown, while background updates only
/// start it when none is running, so they never keep the panel open
public final class InactivityDismissal {
    /// Runs `action` after the interval and returns a function cancelling it
    public typealias Schedule = (
        _ interval: TimeInterval,
        _ action: @escaping () -> Void
    ) -> () -> Void

    public let interval: TimeInterval
    private let schedule: Schedule
    private var cancelPending: (() -> Void)?
    private var generation = 0

    public init(interval: TimeInterval, schedule: @escaping Schedule) {
        self.interval = interval
        self.schedule = schedule
    }

    public var isScheduled: Bool {
        cancelPending != nil
    }

    /// Starts the countdown again from now, for a newly shown panel or a
    /// user operation on it
    public func restart(onDismiss: @escaping () -> Void) {
        cancel()
        generation += 1
        let scheduled = generation
        cancelPending = schedule(interval) { [weak self] in
            // A countdown cancelled or replaced after it fired does nothing
            guard let self, generation == scheduled else { return }
            cancelPending = nil
            onDismiss()
        }
    }

    /// Keeps a running countdown, so content added in the background does
    /// not extend how long the panel stays
    public func startIfIdle(onDismiss: @escaping () -> Void) {
        guard !isScheduled else { return }
        restart(onDismiss: onDismiss)
    }

    public func cancel() {
        generation += 1
        cancelPending?()
        cancelPending = nil
    }
}
