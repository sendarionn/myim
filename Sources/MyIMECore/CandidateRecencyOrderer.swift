public enum CandidateRecencyOrderer {
    public static func ordered(
        _ candidates: [String],
        ranks: [String: Int]
    ) -> [String] {
        candidates.enumerated().sorted {
            let leftRank = ranks[$0.element] ?? Int.min
            let rightRank = ranks[$1.element] ?? Int.min
            return leftRank == rightRank
                ? $0.offset < $1.offset
                : leftRank > rightRank
        }
        .map(\.element)
    }
}
