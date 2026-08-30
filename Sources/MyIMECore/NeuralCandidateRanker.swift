public enum NeuralCandidateRanker {
    public static func ordered(
        _ candidates: [String],
        neuralCandidates: [String],
        protectedPrefixCount: Int = 0
    ) -> [String] {
        guard !candidates.isEmpty, !neuralCandidates.isEmpty else {
            return candidates
        }
        let protectedCount = min(max(protectedPrefixCount, 0), candidates.count)
        let protected = Array(candidates.prefix(protectedCount))
        let remainder = Array(candidates.dropFirst(protectedCount))
        let available = Set(remainder)
        var seen = Set<String>()
        let preferred = neuralCandidates.filter {
            available.contains($0) && seen.insert($0).inserted
        }
        return protected + preferred + remainder.filter { !seen.contains($0) }
    }
}
