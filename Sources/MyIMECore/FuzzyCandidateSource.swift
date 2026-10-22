public struct FuzzyCandidateSource: Sendable {
    private let query: String
    private let visibleCandidates: Set<String>
    private let userDictionary: LayeredConversionEngine
    private let importedDictionary: LayeredConversionEngine
    private let basicDictionary: ConversionEngine
    private let mozcDictionary: IndexedDictionaryEngine
    private let fuzzyRepository: FuzzyEngineRepository
    private let learnedCompounds: [LearnedCompoundPrediction]

    public init(
        query: String,
        visibleCandidates: Set<String>,
        userDictionary: LayeredConversionEngine,
        importedDictionary: LayeredConversionEngine = LayeredConversionEngine(
            engines: []
        ),
        basicDictionary: ConversionEngine,
        mozcDictionary: IndexedDictionaryEngine,
        fuzzyRepository: FuzzyEngineRepository,
        learnedCompounds: [LearnedCompoundPrediction] = []
    ) {
        self.query = query
        self.visibleCandidates = visibleCandidates
        self.userDictionary = userDictionary
        self.importedDictionary = importedDictionary
        self.basicDictionary = basicDictionary
        self.mozcDictionary = mozcDictionary
        self.fuzzyRepository = fuzzyRepository
        self.learnedCompounds = learnedCompounds
    }

    public func matchTiers(
        includesTypoCorrections: Bool = true
    ) async -> [[FuzzyConversionMatch]] {
        await Task.detached(priority: .userInitiated) {
            let learnedMatches: [FuzzyConversionMatch] = learnedCompounds
                .compactMap { prediction in
                guard !visibleCandidates.contains(prediction.text) else {
                    return nil
                }
                return FuzzyConversionMatch(
                    reading: prediction.reading,
                    candidates: [prediction.text],
                    distance: 0,
                    isLearnable: false,
                    sourceTokens: prediction.sourceTokens,
                    sourceReadings: prediction.sourceReadings
                )
            }
            guard includesTypoCorrections else {
                return [learnedMatches]
            }
            let keyboardMatches =
                RomajiKeyboardTypoGenerator.dictionaryMatches(
                    for: query
                ) { reading in
                    userCandidates(for: reading)
                        + basicDictionary.candidates(for: reading)
                        + mozcDictionary.candidates(for: reading)
                }
            var seenReadings = Set<String>()
            let fuzzyMatches = fuzzyRepository.matches(
                for: query,
                limit: .max
            )
            let combined = (keyboardMatches + fuzzyMatches).filter {
                seenReadings.insert($0.reading).inserted
            }
            let filtered = Array(FuzzyConversionMatchFilter.filtered(
                combined,
                for: query,
                excluding: visibleCandidates
            ))
            // Several replaced keys are tried only when the ordinary search
            // found nothing, as for `z=tp`, so inputs it already corrects,
            // such as `denwq`, do not gather far corrections
            let multipleKeyMatches = filtered.isEmpty
                ? FuzzyConversionMatchFilter.filtered(
                    RomajiKeyboardTypoGenerator.multipleKeyDictionaryMatches(
                        for: query,
                        excludingReadings: seenReadings
                    ) { reading in
                        userCandidates(for: reading)
                            + basicDictionary.candidates(for: reading)
                            + mozcDictionary.candidates(for: reading)
                    },
                    for: query,
                    excluding: visibleCandidates
                )
                : []
            return [learnedMatches] + FuzzyCandidateTierBuilder.build(
                directTypoMatches: filtered,
                multipleKeyMatches: multipleKeyMatches
            )
        }.value
    }

    /// Imported dictionaries contribute only entries whose kana reading
    /// matches, so SKK abbrev headwords such as `hs` are not used as words
    private func userCandidates(for reading: String) -> [String] {
        RomajiCanonicalizer.legacyLongVowelLookupInputs(from: reading)
            .flatMap(userDictionary.candidates)
            + (RomajiConverter().hiragana(from: reading).map {
                importedDictionary.candidates(for: $0)
            } ?? [])
    }
}
