/// Orders particle compositions by how recently their base candidate was
/// chosen in ordinary conversion, so 私は follows the choice of 私 over
/// わたし for `watashi`
public enum ParticleCompositionRanking {
    /// Recency ranks for the candidates of the particle group: the base
    /// candidate's last selection first, then the composition's own, as
    /// `CandidateRecencyOrderer` expects
    public static func ranks(
        for candidates: [String],
        compositions: [ParticleComposition],
        history: CandidateSelectionHistory,
        compositionRanks: [String: Int]
    ) -> [String: Int] {
        let compositionByText = Dictionary(
            compositions.map { ($0.text, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        // Ranks from one query over every base reading follow the last
        // selection across those readings, so bases of different readings
        // compare; a base counts only under the reading it was chosen for
        let baseReadings = Array(Set(compositions.map(\.baseReading)))
        let lookupsByReading = Dictionary(uniqueKeysWithValues: baseReadings.map {
            ($0, RomajiCanonicalizer.dictionaryLookupInputs(from: $0))
        })
        let combinedBaseRanks = history.ranks(
            for: lookupsByReading.values.flatMap { $0 }
        )
        let baseRanksByReading = lookupsByReading.mapValues {
            history.ranks(for: $0)
        }
        func baseRank(_ text: String) -> Int? {
            guard let composition = compositionByText[text],
                  baseRanksByReading[composition.baseReading]?[
                    composition.base
                  ] != nil else { return nil }
            return combinedBaseRanks[composition.base]
        }
        let ranked = candidates.enumerated().compactMap {
            offset, text -> (offset: Int, base: Int?, own: Int?)? in
            let base = baseRank(text)
            let own = compositionRanks[text]
            guard base != nil || own != nil else { return nil }
            return (offset, base, own)
        }.sorted {
            if $0.base != $1.base { return ($0.base ?? 0) > ($1.base ?? 0) }
            if $0.own != $1.own { return ($0.own ?? 0) > ($1.own ?? 0) }
            return $0.offset < $1.offset
        }
        return Dictionary(
            ranked.enumerated().map {
                (candidates[$0.element.offset], ranked.count - $0.offset)
            },
            uniquingKeysWith: max
        )
    }
}
