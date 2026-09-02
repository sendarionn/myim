public enum TieredCandidateOrderer {
    public static func orderedIndices(
        for tiers: [[String]],
        ranks: [String: Int]
    ) -> [[Int]] {
        tiers.map {
            CandidateRecencyOrderer.orderedIndices($0, ranks: ranks)
        }
    }
}
