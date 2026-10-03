public struct CandidateAssembly: Sendable {
    public struct Input: Sendable {
        public let reading: String
        public let kana: [String]
        public let userExact: [String]
        public let learnedExact: [String]
        public let dateTime: [String]
        public let numericPrefix: [String]
        public let javaScript: [String]
        public let symbolExact: [String]
        public let basicExact: [String]
        public let systemExact: [String]
        public let importedExact: [String]
        public let importedSpelling: [String]
        public let inflection: [String]
        public let particle: [String]
        public let generatedParticles: Set<String>
        public let userPrefix: [String]
        public let learnedCompletion: [String]
        public let external: [Candidate]
        public let symbolPrefix: [String]
        public let systemPrefix: [String]
        public let basicPrefix: [String]
        public let importedPrefix: [String]
        public let english: [String]
        public let uppercase: [String]
        public let recencyRanks: [String: Int]
        public let contextualCandidates: [String]
        public let prioritizeKana: Bool
        public let includeAutomaticKanaCandidates: Bool

        public init(
            reading: String,
            kana: [String],
            userExact: [String],
            learnedExact: [String],
            dateTime: [String],
            numericPrefix: [String],
            javaScript: [String],
            symbolExact: [String],
            basicExact: [String],
            systemExact: [String],
            importedExact: [String] = [],
            importedSpelling: [String] = [],
            inflection: [String],
            particle: [String],
            generatedParticles: Set<String>,
            userPrefix: [String],
            learnedCompletion: [String],
            external: [Candidate],
            symbolPrefix: [String],
            systemPrefix: [String],
            basicPrefix: [String],
            importedPrefix: [String] = [],
            english: [String],
            uppercase: [String],
            recencyRanks: [String: Int],
            contextualCandidates: [String],
            prioritizeKana: Bool,
            includeAutomaticKanaCandidates: Bool = true
        ) {
            self.reading = reading
            self.kana = kana
            self.userExact = userExact
            self.learnedExact = learnedExact
            self.dateTime = dateTime
            self.numericPrefix = numericPrefix
            self.javaScript = javaScript
            self.symbolExact = symbolExact
            self.basicExact = basicExact
            self.systemExact = systemExact
            self.importedExact = importedExact
            self.importedSpelling = importedSpelling
            self.inflection = inflection
            self.particle = particle
            self.generatedParticles = generatedParticles
            self.userPrefix = userPrefix
            self.learnedCompletion = learnedCompletion
            self.external = external
            self.symbolPrefix = symbolPrefix
            self.systemPrefix = systemPrefix
            self.basicPrefix = basicPrefix
            self.importedPrefix = importedPrefix
            self.english = english
            self.uppercase = uppercase
            self.recencyRanks = recencyRanks
            self.contextualCandidates = contextualCandidates
            self.prioritizeKana = prioritizeKana
            self.includeAutomaticKanaCandidates =
                includeAutomaticKanaCandidates
        }
    }

    public init() {}

    public func candidates(from input: Input) -> [Candidate] {
        let preserveLongVowel: CandidateOrigin.Attributes = [
            .preservesLongVowelNotation
        ]
        let direct = makeCandidates(
            input.userExact,
            source: .userDictionary,
            reading: input.reading,
            attributes: preserveLongVowel
        ) + makeCandidates(
            input.learnedExact,
            source: .selectionHistory,
            reading: input.reading
        ) + makeCandidates(
            input.dateTime,
            source: .dateTime,
            reading: input.reading
        ) + makeCandidates(
            input.numericPrefix,
            source: .numericPrefix,
            reading: input.reading
        ) + makeCandidates(
            input.javaScript,
            source: .javaScriptExtension,
            reading: input.reading
        ) + makeCandidates(
            input.symbolExact,
            source: .symbolDictionary,
            reading: input.reading,
            attributes: preserveLongVowel
        ) + makeCandidates(
            input.basicExact,
            source: .basicDictionary,
            reading: input.reading,
            attributes: preserveLongVowel
        ) + makeCandidates(
            input.systemExact,
            source: .systemDictionary,
            reading: input.reading,
            attributes: preserveLongVowel
        ) + makeCandidates(
            input.importedExact,
            source: .importedDictionary,
            reading: input.reading,
            attributes: preserveLongVowel
        ) + makeCandidates(
            input.inflection,
            source: .verbInflection,
            reading: input.reading
        )
        let other = makeCandidates(
            input.importedSpelling,
            source: .importedDictionary,
            reading: input.reading
        ) + makeCandidates(
            input.userPrefix,
            source: .userDictionary,
            reading: input.reading,
            attributes: preserveLongVowel
        ) + makeCandidates(
            input.learnedCompletion,
            source: .selectionHistory,
            reading: input.reading
        ) + input.external + makeCandidates(
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
                secondary: input.particle.map {
                    Candidate(
                        storageText: $0,
                        source: .particleComposition,
                        reading: input.reading,
                        isLearnable: input.generatedParticles.contains($0),
                        attributes: input.generatedParticles.contains($0)
                            ? [.generated]
                            : []
                    )
                },
                other: other,
                english: makeCandidates(
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
                contextualCandidates: input.contextualCandidates,
                prioritizeKana: input.prioritizeKana,
                includeAutomaticKanaCandidates:
                    input.includeAutomaticKanaCandidates
            )
        )
        let visibleTexts = SingleLetterDictionaryCandidateFilter.candidates(
            ordered.map(\.storageText),
            for: input.reading
        )
        let byText = Dictionary(
            ordered.map { ($0.storageText, $0) },
            uniquingKeysWith: { first, _ in first }
        )
        return visibleTexts.compactMap { byText[$0] }
    }

    private func makeCandidates(
        _ values: [String],
        source: CandidateSourceKind,
        reading: String,
        attributes: CandidateOrigin.Attributes = []
    ) -> [Candidate] {
        values.map {
            Candidate(
                storageText: $0,
                source: source,
                reading: reading,
                attributes: attributes
            )
        }
    }
}
