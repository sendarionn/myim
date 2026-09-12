public enum FuzzySuggestionTierBuilder {
    public static func build(
        directTypoMatches: [FuzzyConversionMatch],
        compoundMatches: [FuzzyConversionMatch]
    ) -> [[FuzzyConversionMatch]] {
        let exactCompounds = compoundMatches.filter { $0.distance == 0 }
        let typoCompounds = compoundMatches.filter { $0.distance > 0 }
        return [exactCompounds, directTypoMatches, typoCompounds]
    }
}
