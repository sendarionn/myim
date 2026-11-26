import Foundation

/// Text committed by myim, newest first, kept in memory for the process
/// only, to be inserted again from the input history panel
public final class InputHistoryStore {
    public static let defaultMaximumCount = 10
    public static let allowedCounts = 1...100

    public private(set) var entries: [String] = []

    /// Entries beyond it, the oldest, are dropped
    public var maximumCount: Int {
        didSet {
            maximumCount = Self.clamped(maximumCount)
            trim()
        }
    }

    public init(maximumCount: Int = defaultMaximumCount) {
        self.maximumCount = Self.clamped(maximumCount)
    }

    /// One commit; the same text as the newest is not added again, and
    /// empty text is not kept
    public func record(text: String) {
        guard !text.isEmpty, entries.first != text else { return }
        entries.insert(text, at: 0)
        trim()
    }

    public func clear() {
        entries.removeAll()
    }

    public static func clamped(_ count: Int) -> Int {
        min(max(count, allowedCounts.lowerBound), allowedCounts.upperBound)
    }

    private func trim() {
        if entries.count > maximumCount {
            entries.removeLast(entries.count - maximumCount)
        }
    }
}
