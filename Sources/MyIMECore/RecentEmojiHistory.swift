public struct RecentEmojiHistory: Equatable, Sendable {
    public static let maximumCount = 10

    public private(set) var emojis: [String]

    public init(emojis: [String] = []) {
        var seen = Set<String>()
        self.emojis = Array(emojis.filter {
            !$0.isEmpty && seen.insert($0).inserted
        }.prefix(Self.maximumCount))
    }

    public mutating func record(_ emoji: String) {
        guard !emoji.isEmpty else { return }
        emojis.removeAll { $0 == emoji }
        emojis.insert(emoji, at: 0)
        if emojis.count > Self.maximumCount {
            emojis.removeLast(emojis.count - Self.maximumCount)
        }
    }

    /// Removes one emoji from the history; using it again records it anew
    @discardableResult
    public mutating func remove(_ emoji: String) -> Bool {
        guard emojis.contains(emoji) else { return false }
        emojis.removeAll { $0 == emoji }
        return true
    }

    /// The recent emoji to select after the one at `index` is removed: the
    /// next one in its place, or the previous one when it was the last
    public static func selectionAfterRemoving(
        at index: Int,
        remainingCount: Int
    ) -> Int? {
        guard remainingCount > 0 else { return nil }
        return min(index, remainingCount - 1)
    }
}
