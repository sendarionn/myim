public struct CandidateSelectionHistory: Equatable, Sendable {
    public private(set) var ranks: [String: Int]

    private let maximumEntryCount: Int
    private var nextRank: Int

    public init(
        ranks: [String: Int] = [:],
        maximumEntryCount: Int = 4_096
    ) {
        self.maximumEntryCount = max(1, maximumEntryCount)
        let recentRanks = Self.compacted(
            ranks,
            limit: self.maximumEntryCount
        )
        self.ranks = recentRanks
        self.nextRank = (recentRanks.values.max() ?? 0) + 1
    }

    public mutating func record(_ candidate: String) {
        guard !candidate.isEmpty else {
            return
        }
        ranks[candidate] = nextRank
        nextRank += 1
        guard ranks.count > maximumEntryCount else {
            return
        }
        ranks = Self.compacted(ranks, limit: maximumEntryCount)
        nextRank = (ranks.values.max() ?? 0) + 1
    }

    private static func compacted(
        _ ranks: [String: Int],
        limit: Int
    ) -> [String: Int] {
        let recent = ranks.sorted {
            $0.value == $1.value
                ? $0.key < $1.key
                : $0.value > $1.value
        }.prefix(limit)
        return Dictionary(uniqueKeysWithValues: recent.enumerated().map {
            ($0.element.key, recent.count - $0.offset)
        })
    }
}
