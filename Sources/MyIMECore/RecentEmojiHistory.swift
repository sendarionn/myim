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
}
