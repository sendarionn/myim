public enum CandidateRecencyOrderer {
    public static func ordered(
        _ candidates: [String],
        ranks: [String: Int]
    ) -> [String] {
        orderedIndices(candidates, ranks: ranks).map { candidates[$0] }
    }

    public static func orderedIndices(
        _ candidates: [String],
        ranks: [String: Int]
    ) -> [Int] {
        guard !candidates.isEmpty, !ranks.isEmpty else {
            return Array(candidates.indices)
        }

        var ranked: [(offset: Int, rank: Int)] = []
        var unranked: [Int] = []
        ranked.reserveCapacity(min(candidates.count, ranks.count))
        unranked.reserveCapacity(candidates.count)

        for (offset, candidate) in candidates.enumerated() {
            if let rank = ranks[candidate] {
                ranked.append((offset, rank))
            } else {
                unranked.append(offset)
            }
        }

        ranked.sort {
            $0.rank == $1.rank
                ? $0.offset < $1.offset
                : $0.rank > $1.rank
        }

        var result: [Int] = []
        result.reserveCapacity(candidates.count)
        result.append(contentsOf: ranked.map(\.offset))
        result.append(contentsOf: unranked)
        return result
    }
}
