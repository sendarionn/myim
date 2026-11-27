public struct CandidateAssembly: Sendable {
    public struct Input: Sendable {
        public let reading: String
        public let kana: [String]
        public let userExact: [String]
        public let learnedExact: [String]
        public let dateTime: [JavaScriptExtensionCandidate]
        public let numericPrefix: [String]
        public let javaScript: [String]
        public let supplementaryJavaScript: [String]
        public let symbolExact: [String]
        public let basicExact: [String]
        public let systemExact: [String]
        public let deferredSystemExact: [String]
        public let importedExact: [String]
        public let importedSpelling: [String]
        public let inflection: [String]
        public let generatedInflections: [GeneratedInflectionCandidate]
        public let adjectiveInflection: [String]
        public let generatedAdjectiveInflections: [GeneratedInflectionCandidate]
        public let particle: [String]
        public let generatedParticles: Set<String>
        /// The words each composition is made from
        public let particleBases: [String: [CandidateBaseWord]]
        public let userPrefix: [String]
        public let learnedCompletion: [String]
        public let symbolPrefix: [String]
        public let systemPrefix: [String]
        public let basicPrefix: [String]
        public let importedPrefix: [String]
        public let english: [String]
        /// English words for the Japanese reading, before the completions
        public let japaneseEnglish: [String]
        public let uppercase: [String]
        public let recencyRanks: [String: Int]
        /// Ranks ordering generated candidates without moving them ahead of
        /// exact candidates
        public let secondaryRanks: [String: Int]?
        public let inflectionBaseRanks: [String: Int]
        public let contextualCandidates: [String]
        public let prioritizeKana: Bool
        public let includeAutomaticKanaCandidates: Bool
        public let longVowelNotationProtectedCandidates: Set<String>

        public init(
            reading: String,
            kana: [String],
            userExact: [String],
            learnedExact: [String],
            dateTime: [JavaScriptExtensionCandidate],
            numericPrefix: [String],
            javaScript: [String],
            supplementaryJavaScript: [String] = [],
            symbolExact: [String],
            basicExact: [String],
            systemExact: [String],
            deferredSystemExact: [String] = [],
            importedExact: [String] = [],
            importedSpelling: [String] = [],
            inflection: [String],
            generatedInflections: [GeneratedInflectionCandidate] = [],
            adjectiveInflection: [String] = [],
            generatedAdjectiveInflections: [GeneratedInflectionCandidate] = [],
            particle: [String],
            generatedParticles: Set<String>,
            particleBases: [String: [CandidateBaseWord]] = [:],
            userPrefix: [String],
            learnedCompletion: [String],
            symbolPrefix: [String],
            systemPrefix: [String],
            basicPrefix: [String],
            importedPrefix: [String] = [],
            english: [String],
            japaneseEnglish: [String] = [],
            uppercase: [String],
            recencyRanks: [String: Int],
            secondaryRanks: [String: Int]? = nil,
            inflectionBaseRanks: [String: Int] = [:],
            contextualCandidates: [String],
            prioritizeKana: Bool,
            includeAutomaticKanaCandidates: Bool = true,
            longVowelNotationProtectedCandidates: Set<String> = []
        ) {
            self.reading = reading
            self.kana = kana
            self.userExact = userExact
            self.learnedExact = learnedExact
            self.dateTime = dateTime
            self.numericPrefix = numericPrefix
            self.javaScript = javaScript
            self.supplementaryJavaScript = supplementaryJavaScript
            self.symbolExact = symbolExact
            self.basicExact = basicExact
            self.systemExact = systemExact
            self.deferredSystemExact = deferredSystemExact
            self.importedExact = importedExact
            self.importedSpelling = importedSpelling
            self.inflection = inflection
            self.generatedInflections = generatedInflections
            self.adjectiveInflection = adjectiveInflection
            self.generatedAdjectiveInflections = generatedAdjectiveInflections
            self.particle = particle
            self.generatedParticles = generatedParticles
            self.particleBases = particleBases
            self.userPrefix = userPrefix
            self.learnedCompletion = learnedCompletion
            self.symbolPrefix = symbolPrefix
            self.systemPrefix = systemPrefix
            self.basicPrefix = basicPrefix
            self.importedPrefix = importedPrefix
            self.english = english
            self.japaneseEnglish = japaneseEnglish
            self.uppercase = uppercase
            self.recencyRanks = recencyRanks
            self.secondaryRanks = secondaryRanks
            self.inflectionBaseRanks = inflectionBaseRanks
            self.contextualCandidates = contextualCandidates
            self.prioritizeKana = prioritizeKana
            self.includeAutomaticKanaCandidates =
                includeAutomaticKanaCandidates
            self.longVowelNotationProtectedCandidates =
                longVowelNotationProtectedCandidates
        }
    }

    public init() {}

    public func candidates(from input: Input) -> [Candidate] {
        let direct = makeCandidates(
            input.userExact,
            source: .userDictionary,
            reading: input.reading,
            attributes: [.preservesLongVowelNotation]
        ) + makeCandidates(
            input.learnedExact,
            source: .selectionHistory,
            reading: input.reading
        ) + input.dateTime.map {
            Candidate(
                storageText: $0.value,
                source: .dateTime,
                reading: input.reading,
                contextualMetadata: $0.preferenceID.map {
                    [Candidate.dynamicPreferenceIDMetadataKey: $0]
                } ?? [:]
            )
        } + makeCandidates(
            input.javaScript,
            source: .javaScriptExtension,
            reading: input.reading
        ) + makeCandidates(
            input.symbolExact,
            source: .symbolDictionary,
            reading: input.reading,
            preservingLongVowelNotation:
                input.longVowelNotationProtectedCandidates
        ) + makeCandidates(
            input.basicExact,
            source: .basicDictionary,
            reading: input.reading,
            preservingLongVowelNotation:
                input.longVowelNotationProtectedCandidates
        ) + makeCandidates(
            input.systemExact,
            source: .systemDictionary,
            reading: input.reading,
            preservingLongVowelNotation:
                input.longVowelNotationProtectedCandidates
        ) + makeCandidates(
            input.deferredSystemExact,
            source: .systemDictionary,
            reading: input.reading,
            preservingLongVowelNotation:
                input.longVowelNotationProtectedCandidates
        ) + makeCandidates(
            input.importedExact,
            source: .importedDictionary,
            reading: input.reading,
            preservingLongVowelNotation:
                input.longVowelNotationProtectedCandidates
        ) + makeCandidates(
            input.importedSpelling,
            source: .importedDictionary,
            reading: input.reading
        ) + makeCandidates(
            input.supplementaryJavaScript,
            source: .javaScriptExtension,
            reading: input.reading
        )
        let other = makeCandidates(
            input.userPrefix,
            source: .userDictionary,
            reading: input.reading,
            preservingLongVowelNotation:
                input.longVowelNotationProtectedCandidates
        ) + makeCandidates(
            input.learnedCompletion,
            source: .selectionHistory,
            reading: input.reading,
            attributes: [.preservesLongVowelNotation]
        ) + makeCandidates(
            input.symbolPrefix,
            source: .symbolDictionary,
            reading: input.reading
        ) + makeCandidates(
            input.systemPrefix,
            source: .systemDictionary,
            reading: input.reading
        ) + makeCandidates(
            input.basicPrefix,
            source: .basicDictionary,
            reading: input.reading
        ) + makeCandidates(
            input.importedPrefix,
            source: .importedDictionary,
            reading: input.reading
        )
        let ordered = CandidatePipeline().candidates(
            from: CandidatePipeline.StructuredInput(
                kana: makeCandidates(
                    input.kana,
                    source: .automaticKana,
                    reading: input.reading
                ),
                direct: direct,
                secondary: makeCandidates(
                    input.numericPrefix,
                    source: .numericPrefix,
                    reading: input.reading
                ) + makeCandidates(
                    input.inflection,
                    source: .verbInflection,
                    reading: input.reading
                ) + makeInflectionCandidates(
                    input.generatedInflections,
                    source: .verbInflection,
                    reading: input.reading
                ) + makeCandidates(
                    input.adjectiveInflection,
                    source: .adjectiveInflection,
                    reading: input.reading
                ) + makeInflectionCandidates(
                    input.generatedAdjectiveInflections,
                    source: .adjectiveInflection,
                    reading: input.reading
                ) + input.particle.map {
                    Candidate(
                        storageText: $0,
                        source: .particleComposition,
                        reading: input.reading,
                        isLearnable: input.generatedParticles.contains($0),
                        attributes: input.generatedParticles.contains($0)
                            ? [.generated]
                            : [],
                        baseWords: input.particleBases[$0] ?? []
                    )
                },
                other: other,
                english: makeCandidates(
                    input.japaneseEnglish,
                    source: .japaneseEnglishDictionary,
                    reading: input.reading
                ) + makeCandidates(
                    input.english,
                    source: .englishCompletion,
                    reading: input.reading
                ),
                trailing: makeCandidates(
                    input.uppercase,
                    source: .uppercase,
                    reading: input.reading
                ),
                recencyRanks: input.recencyRanks,
                secondaryRanks: input.secondaryRanks,
                inflectionBaseRanks: input.inflectionBaseRanks,
                contextualCandidates: input.contextualCandidates,
                prioritizeKana: input.prioritizeKana,
                includeAutomaticKanaCandidates:
                    input.includeAutomaticKanaCandidates
            )
        )
        // The ordered candidates are already unique, so only the filter for
        // single letters, when it applies, removes any
        guard SingleLetterDictionaryCandidateFilter.applies(to: input.reading) else {
            return ordered
        }
        let visibleTexts = Set(SingleLetterDictionaryCandidateFilter.candidates(
            ordered.map(\.storageText),
            for: input.reading,
            keeping: Set(ordered.filter {
                $0.hasSource(.javaScriptExtension) || $0.hasSource(.dateTime)
            }.map(\.storageText))
        ))
        return ordered.filter { visibleTexts.contains($0.storageText) }
    }

    private func makeCandidates(
        _ values: [String],
        source: CandidateSourceKind,
        reading: String,
        attributes: CandidateOrigin.Attributes = [],
        preservingLongVowelNotation: Set<String> = []
    ) -> [Candidate] {
        values.map {
            Candidate(
                storageText: $0,
                source: source,
                reading: reading,
                attributes: preservingLongVowelNotation.contains($0)
                    ? attributes.union(.preservesLongVowelNotation)
                    : attributes
            )
        }
    }

    private func makeInflectionCandidates(
        _ values: [GeneratedInflectionCandidate],
        source: CandidateSourceKind,
        reading: String
    ) -> [Candidate] {
        values.flatMap { value in
            if value.bases.isEmpty {
                return [Candidate(
                    storageText: value.text,
                    source: source,
                    reading: reading
                )]
            }
            return value.bases.map {
                Candidate(
                    storageText: value.text,
                    source: source,
                    reading: reading,
                    inflectionBase: $0
                )
            }
        }
    }
}
