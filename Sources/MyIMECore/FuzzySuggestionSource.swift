public struct FuzzySuggestionSource: Sendable {
    private let query: String
    private let visibleCandidates: Set<String>
    private let userDictionary: LayeredConversionEngine
    private let basicDictionary: ConversionEngine
    private let mozcDictionary: IndexedDictionaryEngine
    private let compoundGenerator: CompoundDictionaryCandidateGenerator
    private let fuzzyRepository: FuzzyEngineRepository

    public init(
        query: String,
        visibleCandidates: Set<String>,
        userDictionary: LayeredConversionEngine,
        basicDictionary: ConversionEngine,
        mozcDictionary: IndexedDictionaryEngine,
        compoundGenerator: CompoundDictionaryCandidateGenerator,
        fuzzyRepository: FuzzyEngineRepository
    ) {
        self.query = query
        self.visibleCandidates = visibleCandidates
        self.userDictionary = userDictionary
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
                    userDictionary.candidates(for: reading)
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
            let compoundMatches = compoundGenerator
                .matches(for: query) {
                    userDictionary.candidates(for: $0)
                        + mozcDictionary.candidates(for: $0)
                } typoMatches: { segment in
                    var seenReadings = Set<String>()
                    let keyboardMatches =
                        RomajiKeyboardTypoGenerator.dictionaryMatches(
                            for: segment
                        ) { reading in
                            userDictionary.candidates(for: reading)
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
                .map {
                    FuzzyConversionMatch(
                        reading: $0.reading,
                        candidates: [$0.text],
                        distance: $0.typoDistance
                    )
                }
            return FuzzySuggestionTierBuilder.build(
                directTypoMatches: filtered,
                compoundMatches: compoundMatches
            )
        }.value
    }
}
