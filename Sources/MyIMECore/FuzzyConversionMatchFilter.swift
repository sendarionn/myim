public enum FuzzyConversionMatchFilter {
    public static func filtered(
        _ matches: [FuzzyConversionMatch],
        excluding visibleCandidates: Set<String>
    ) -> [FuzzyConversionMatch] {
        matches.compactMap { match in
            let candidates = match.candidates.filter {
                !visibleCandidates.contains($0)
            }
            guard !candidates.isEmpty else {
                return nil
            }
            return FuzzyConversionMatch(
                reading: match.reading,
                candidates: candidates,
                distance: match.distance
            )
        }
    }
}
