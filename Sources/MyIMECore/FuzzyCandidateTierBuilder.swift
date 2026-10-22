public enum FuzzyCandidateTierBuilder {
    /// Keeps close corrections ahead of more distant whole-reading matches,
    /// and words reached by replacing several keys after both, so they
    /// never push the ordinary corrections down
    public static func build(
        directTypoMatches: [FuzzyConversionMatch],
        multipleKeyMatches: [FuzzyConversionMatch] = []
    ) -> [[FuzzyConversionMatch]] {
        return [
            directTypoMatches.filter { $0.distance <= 1 },
            directTypoMatches.filter { $0.distance > 1 },
            multipleKeyMatches
        ]
    }
}
