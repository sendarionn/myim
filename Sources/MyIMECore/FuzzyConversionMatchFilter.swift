public enum FuzzyConversionMatchFilter {
    public static func filtered(
        _ matches: [FuzzyConversionMatch],
        for input: String,
        excluding visibleCandidates: Set<String>
    ) -> [FuzzyConversionMatch] {
        matches.compactMap { match in
            let notationMatches = LongVowelNotationCandidateFilter.candidates(
                match.candidates,
                for: input
            )
            let candidates = notationMatches.filter {
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
