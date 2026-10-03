public struct FuzzySuggestionSource: Sendable {
    private let query: String
    private let visibleCandidates: Set<String>
    private let userDictionary: LayeredConversionEngine
    private let importedDictionary: LayeredConversionEngine
    private let basicDictionary: ConversionEngine
    private let mozcDictionary: IndexedDictionaryEngine
    private let compoundGenerator: CompoundDictionaryCandidateGenerator
    private let fuzzyRepository: FuzzyEngineRepository

    public init(
        query: String,
        visibleCandidates: Set<String>,
        userDictionary: LayeredConversionEngine,
        importedDictionary: LayeredConversionEngine = LayeredConversionEngine(
            engines: []
        ),
        basicDictionary: ConversionEngine,
        mozcDictionary: IndexedDictionaryEngine,
        compoundGenerator: CompoundDictionaryCandidateGenerator,
        fuzzyRepository: FuzzyEngineRepository
    ) {
        self.query = query
        self.visibleCandidates = visibleCandidates
        self.userDictionary = userDictionary
        self.importedDictionary = importedDictionary
        self.basicDictionary = basicDictionary
        self.mozcDictionary = mozcDictionary
        self.compoundGenerator = compoundGenerator
        self.fuzzyRepository = fuzzyRepository
    }

    public func matchTiers() async -> [[FuzzyConversionMatch]] {
        await Task.detached(priority: .userInitiated) {
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
                excluding: visibleCandidates
            ))
            let compounds = compoundGenerator
                .matches(for: query) {
                    userCandidates(for: $0)
                        + mozcDictionary.candidates(for: $0)
                } typoMatches: { segment in
                    var seenReadings = Set<String>()
                    let keyboardMatches =
                        RomajiKeyboardTypoGenerator.dictionaryMatches(
                            for: segment
                        ) { reading in
                            userCandidates(for: reading)
                                + basicDictionary.candidates(for: reading)
                                + mozcDictionary.candidates(for: reading)
                        }
                    let fuzzyMatches = fuzzyRepository.matches(
                        for: segment,
                        maximumDistance: 1,
                        limit: 4
                    )
                    return (keyboardMatches + fuzzyMatches).filter {
                        seenReadings.insert($0.reading).inserted
                    }
                }
                .filter { !visibleCandidates.contains($0.text) }
            return FuzzySuggestionTierBuilder.build(
                directTypoMatches: filtered,
                compounds: compounds
            )
        }.value
    }

    /// Imported dictionaries contribute only entries whose kana reading
    /// matches, so SKK abbrev headwords such as `hs` are not used as words
    private func userCandidates(for reading: String) -> [String] {
        userDictionary.candidates(for: reading)
            + (RomajiConverter().hiragana(from: reading).map {
                importedDictionary.candidates(for: $0)
            } ?? [])
    }
}
