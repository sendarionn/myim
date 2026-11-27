import Foundation

/// The last few texts myim committed, newest first, to insert again from
/// the input history panel. Kept in memory for the process only
public final class InputHistoryStore {
    /// As many as the candidate panel shows at once
    public static let maximumCount = 4

    public private(set) var entries: [String] = []

    public init() {}

    /// One commit; the same text as the newest is not added again, and
    /// empty text is not kept
    public func record(text: String) {
        guard !text.isEmpty, entries.first != text else { return }
        entries.insert(text, at: 0)
        if entries.count > Self.maximumCount {
            entries.removeLast(entries.count - Self.maximumCount)
        }
    }

    public func clear() {
        entries.removeAll()
    }
}
