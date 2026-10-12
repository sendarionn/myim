public enum FuzzyCandidateTierBuilder {
    /// Keeps close corrections ahead of more distant whole-reading matches
    public static func build(
        directTypoMatches: [FuzzyConversionMatch]
    ) -> [[FuzzyConversionMatch]] {
        return [
            directTypoMatches.filter { $0.distance <= 1 },
            directTypoMatches.filter { $0.distance > 1 }
        ]
    }
}
