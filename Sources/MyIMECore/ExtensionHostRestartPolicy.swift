import Foundation

/// Stops restarting the extension host for a while when it keeps exceeding
/// its time limit, as it does while the whole system is slow; extension
/// candidates are only an addition to the input itself
public struct ExtensionHostRestartPolicy: Equatable, Sendable {
    public let maximumTimeouts: Int
    public let window: TimeInterval
    public let pause: TimeInterval
    private var timeouts: [TimeInterval] = []
    private var pausedUntil: TimeInterval?

    public init(
        maximumTimeouts: Int = 3,
        window: TimeInterval = 30,
        pause: TimeInterval = 30
    ) {
        self.maximumTimeouts = maximumTimeouts
        self.window = window
        self.pause = pause
    }

    public func allowsRequest(now: TimeInterval) -> Bool {
        guard let pausedUntil else { return true }
        return now >= pausedUntil
    }

    /// Returns whether this timeout started a pause
    @discardableResult
    public mutating func recordTimeout(now: TimeInterval) -> Bool {
        timeouts = timeouts.filter { now - $0 <= window } + [now]
        guard timeouts.count >= maximumTimeouts else { return false }
        timeouts.removeAll()
        pausedUntil = now + pause
        return true
    }

    public mutating func recordResponse() {
        timeouts.removeAll()
        pausedUntil = nil
    }
}
