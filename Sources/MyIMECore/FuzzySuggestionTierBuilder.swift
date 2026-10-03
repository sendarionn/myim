public enum FuzzySuggestionTierBuilder {
    /// Segments shorter than this are fragments such as `ma` or `gyo`,
    /// which split almost any input into some dictionary entries
    public static let wordSegmentLength = 4

    /// Orders whole-word splits, close corrections of the whole reading,
    /// splits that rely on short fragments, distant corrections, and
    /// splits that also correct a typo
    public static func build(
        directTypoMatches: [FuzzyConversionMatch],
        compounds: [CompoundDictionaryCandidate]
    ) -> [[FuzzyConversionMatch]] {
        let exactCompounds = compounds.filter { $0.typoDistance == 0 }
        let wordCompounds = exactCompounds.filter {
            $0.minimumSegmentLength >= wordSegmentLength
        }
        let fragmentCompounds = exactCompounds.filter {
            $0.minimumSegmentLength < wordSegmentLength
        }
        let typoCompounds = compounds.filter { $0.typoDistance > 0 }
        return [
            matches(wordCompounds),
            directTypoMatches.filter { $0.distance <= 1 },
            matches(fragmentCompounds),
            directTypoMatches.filter { $0.distance > 1 },
            matches(typoCompounds)
        ]
    }

    private static func matches(
        _ compounds: [CompoundDictionaryCandidate]
    ) -> [FuzzyConversionMatch] {
        compounds.map {
            FuzzyConversionMatch(
                reading: $0.reading,
                candidates: [$0.text],
                distance: $0.typoDistance
            )
        }
    }
}
