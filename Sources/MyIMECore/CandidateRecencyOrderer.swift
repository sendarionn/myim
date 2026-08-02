public enum CandidateRecencyOrderer {
    public static func ordered(
        _ candidates: [String],
        ranks: [String: Int]
    ) -> [String] {
        guard !candidates.isEmpty, !ranks.isEmpty else {
            return candidates
        }

        var ranked: [(offset: Int, candidate: String, rank: Int)] = []
        var unranked: [String] = []
        ranked.reserveCapacity(min(candidates.count, ranks.count))
        unranked.reserveCapacity(candidates.count)

        for (offset, candidate) in candidates.enumerated() {
            if let rank = ranks[candidate] {
                ranked.append((offset, candidate, rank))
            } else {
                unranked.append(candidate)
            }
        }

        ranked.sort {
            $0.rank == $1.rank
                ? $0.offset < $1.offset
                : $0.rank > $1.rank
        }

        var result: [String] = []
        result.reserveCapacity(candidates.count)
        result.append(contentsOf: ranked.map(\.candidate))
        result.append(contentsOf: unranked)
        return result
    }
}
