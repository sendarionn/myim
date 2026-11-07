/// Orders the candidates of a corrected reading as the first panel orders
/// them for that reading typed directly, with the same generation and the
/// same selection history, so `ahite` corrected to `shite` offers して
/// wherever して comes first for `shite`
///
/// Only the readings shown first are generated again; each still gives one
/// candidate to the second panel
public struct FuzzyCandidateRanking: Sendable {
    public static let defaultMaximumRankedReadings = 8

    private let standardSource: StandardConversionCandidateSource
    private let selectionHistory: CandidateSelectionHistory
    private let learningEnabled: Bool
    private let maximumRankedReadings: Int

    public init(
        standardSource: StandardConversionCandidateSource,
        selectionHistory: CandidateSelectionHistory,
        learningEnabled: Bool = true,
        maximumRankedReadings: Int = Self.defaultMaximumRankedReadings
    ) {
        self.standardSource = standardSource
        self.selectionHistory = selectionHistory
        self.learningEnabled = learningEnabled
        self.maximumRankedReadings = maximumRankedReadings
    }

    /// Keeps the tiers and the order of readings; only the candidate each
    /// reading offers changes. Learned phrases are left as they are
    public func ranked(
        _ tiers: [[FuzzyConversionMatch]],
        for query: String,
        excluding visibleCandidates: Set<String>
    ) -> [[FuzzyConversionMatch]] {
        var remaining = maximumRankedReadings
        var offered = Set<String>()
        var rankedReadings = Set<String>()
        return tiers.map { matches in
            matches.map { match in
                guard match.sourceTokens.isEmpty,
                      remaining > 0,
                      rankedReadings.insert(match.reading).inserted else {
                    return match
                }
                remaining -= 1
                guard let ranked = rankedMatch(
                    match,
                    for: query,
                    excluding: visibleCandidates.union(offered)
                ) else {
                    return match
                }
                if let first = ranked.candidates.first {
                    offered.insert(first)
                }
                return ranked
            }
        }
    }

    private func rankedMatch(
        _ match: FuzzyConversionMatch,
        for query: String,
        excluding excluded: Set<String>
    ) -> FuzzyConversionMatch? {
        let candidates = standardSource.candidates(for: .init(
            input: match.reading,
            conversionReading: match.reading,
            selectionHistory: selectionHistory,
            learningEnabled: learningEnabled
        ))
        let shown = Set(LongVowelNotationCandidateFilter.candidates(
            candidates.map(\.storageText),
            for: query
        ))
        guard let first = candidates.first(where: {
            shown.contains($0.storageText)
                && !excluded.contains($0.storageText)
        }) else {
            return nil
        }
        return FuzzyConversionMatch(
            reading: match.reading,
            candidates: [first.storageText],
            distance: match.distance,
            isLearnable: match.isLearnable,
            registersInUserDictionary: Self.isDictionaryWord(first)
        )
    }

    /// Words found in a dictionary are added to the user dictionary as
    /// before; kana and forms generated for the reading are not
    private static func isDictionaryWord(_ candidate: Candidate) -> Bool {
        [
            .userDictionary, .basicDictionary, .systemDictionary,
            .importedDictionary, .symbolDictionary
        ].contains(where: candidate.hasSource)
    }
}
