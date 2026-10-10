public struct StandardConversionCandidateContext: Sendable {
    public let input: String
    public let conversionReading: String
    public let javaScriptCandidates: [String]
    public let externalCandidates: [Candidate]
    public let englishCandidates: [String]
    public let selectionHistory: CandidateSelectionHistory
    public let contextualCandidates: [String]
    public let learningEnabled: Bool

    public init(
        input: String,
        conversionReading: String,
        javaScriptCandidates: [String] = [],
        externalCandidates: [Candidate] = [],
        englishCandidates: [String] = [],
        selectionHistory: CandidateSelectionHistory =
            CandidateSelectionHistory(),
        contextualCandidates: [String] = [],
        learningEnabled: Bool = true
    ) {
        self.input = input
        self.conversionReading = conversionReading
        self.javaScriptCandidates = javaScriptCandidates
        self.externalCandidates = externalCandidates
        self.englishCandidates = englishCandidates
        self.selectionHistory = selectionHistory
        self.contextualCandidates = contextualCandidates
        self.learningEnabled = learningEnabled
    }
}

public struct StandardConversionCandidateSource: Sendable {
    private let userEngine: LayeredConversionEngine
    private let importedEngine: LayeredConversionEngine
    private let basicEngine: ConversionEngine
    private let symbolEngine: ConversionEngine
    private let systemEngine: IndexedDictionaryEngine
    private let deferredSystemCandidates: DeferredSystemCandidates
    private let verbConjugations: VerbConjugationDictionary
    private let verbConjugationGenerator: VerbConjugationCandidateGenerator
    private let verbInflectionGenerator: VerbInflectionCandidateGenerator
    private let maximumSystemPrefixCandidates: Int
    private let romajiConverter = RomajiConverter()

    /// `userEngine` holds only the user's own registrations so that bulk
    /// imported dictionaries do not share their priority
    public init(
        userEngine: LayeredConversionEngine,
        importedEngine: LayeredConversionEngine,
        basicEngine: ConversionEngine,
        symbolEngine: ConversionEngine,
        systemEngine: IndexedDictionaryEngine,
        verbInflectionGenerator: VerbInflectionCandidateGenerator,
        deferredSystemCandidates: DeferredSystemCandidates =
            DeferredSystemCandidates(),
        verbConjugations: VerbConjugationDictionary =
            VerbConjugationDictionary(),
        maximumSystemPrefixCandidates: Int = 2048
    ) {
        self.userEngine = userEngine
        self.importedEngine = importedEngine
        self.basicEngine = basicEngine
        self.symbolEngine = symbolEngine
        self.systemEngine = systemEngine
        self.deferredSystemCandidates = deferredSystemCandidates
        self.verbConjugations = verbConjugations
        verbConjugationGenerator = VerbConjugationCandidateGenerator(
            dictionary: verbConjugations
        )
        self.verbInflectionGenerator = verbInflectionGenerator
        self.maximumSystemPrefixCandidates = maximumSystemPrefixCandidates
    }

    public func candidates(
        for context: StandardConversionCandidateContext
    ) -> [Candidate] {
        let lookupReadings = RomajiCanonicalizer.dictionaryLookupInputs(
            from: context.conversionReading
        )
        let userLookupReadings = RomajiCanonicalizer.dictionaryLookupInputs(
            from: UserDictionaryLookupReading.resolve(
                conversionReading: context.conversionReading,
                originalInput: context.input
            )
        )
        let notationPreservingReadings = RomajiCanonicalizer
            .longVowelNotationPreservingLookupInputs(
                from: context.conversionReading
            )
        let notationPreservingUserReadings = RomajiCanonicalizer
            .longVowelNotationPreservingLookupInputs(
                from: UserDictionaryLookupReading.resolve(
                    conversionReading: context.conversionReading,
                    originalInput: context.input
                )
            )
        let user = mergedGroups(
            readings: userLookupReadings,
            lookup: { userEngine.candidateGroups(matching: $0) }
        )
        let imported = importedGroups(
            readings: lookupReadings,
            spellings: userLookupReadings
        )
        let basic = mergedGroups(
            readings: lookupReadings,
            lookup: { basicEngine.candidateGroups(matching: $0) }
        )
        let symbols = mergedGroups(
            readings: lookupReadings,
            lookup: { symbolEngine.candidateGroups(matching: $0) }
        )
        let system = mergedGroups(readings: lookupReadings) {
            systemEngine.candidateGroups(
                matching: $0,
                limit: maximumSystemPrefixCandidates
            )
        }
        let longVowelNotationProtectedCandidates = Set(
            mergedGroups(
                readings: notationPreservingUserReadings,
                lookup: { userEngine.candidateGroups(matching: $0) }
            ).all
            + mergedCandidates(
                readings: notationPreservingReadings,
                lookup: symbolEngine.candidates
            )
            + mergedCandidates(
                readings: notationPreservingReadings,
                lookup: basicEngine.candidates
            )
            + mergedCandidates(
                readings: notationPreservingReadings,
                lookup: systemEngine.candidates
            )
            + importedGroups(
                readings: notationPreservingReadings,
                spellings: []
            ).reading.exact
        )
        let deferredSystemExact = system.exact.filter { candidate in
            lookupReadings.contains {
                deferredSystemCandidates.contains(
                    reading: RomajiCanonicalizer.canonicalInput(from: $0),
                    candidate: candidate
                )
            }
        }
        let particles = particleCandidates(
            for: context.conversionReading
        )
        let generatedParticles = JapaneseParticleCandidateGenerator
            .generatedOnlyCandidates(
                generated: particles,
                exactDictionaryCandidates: user.exact
                    + basic.exact
                    + system.exact
            )
        let learnedExact = context.selectionHistory.candidates(
            for: lookupReadings
        ).filter {
            !generatedParticles.contains($0)
        }
        let kana = [
            romajiConverter.hiragana(from: context.conversionReading),
            romajiConverter.katakana(from: context.conversionReading)
        ].compactMap { $0 }
        let caseCandidates = context.input == context.conversionReading
            ? EnglishCandidateCaseRestorer.caseCandidates(
                for: context.conversionReading
            )
            : []
        let conjugations = verbConjugationGenerator.candidates(
            for: context.conversionReading
        )
        let inflections = mergedCandidates(
            readings: lookupReadings
        ) { reading in
            verbInflectionGenerator.candidates(
                for: reading,
                conjugations: verbConjugations
            ) + VerbInflectionCandidateGenerator.candidates(
                for: reading,
                conjugations: verbConjugations,
                lookup: systemEngine.candidates
            )
        }
        return CandidateAssembly().candidates(from: .init(
            reading: context.conversionReading,
            kana: kana,
            userExact: user.exact,
            learnedExact: learnedExact,
            dateTime: [],
            numericPrefix: numericPrefixCandidates(
                for: context.conversionReading,
                history: context.selectionHistory,
                learningEnabled: context.learningEnabled
            ),
            javaScript: context.javaScriptCandidates,
            symbolExact: symbols.exact,
            basicExact: basic.exact,
            systemExact: system.exact.filter {
                !deferredSystemExact.contains($0)
            },
            deferredSystemExact: deferredSystemExact,
            importedExact: imported.reading.exact,
            importedSpelling: imported.spelling.exact,
            inflection: Self.removingDuplicates(conjugations + inflections),
            particle: particles,
            generatedParticles: generatedParticles,
            userPrefix: user.prefix,
            learnedCompletion: context.selectionHistory.completions(
                for: context.conversionReading,
                limit: 8
            ),
            external: context.externalCandidates,
            symbolPrefix: symbols.prefix,
            systemPrefix: system.prefix,
            basicPrefix: basic.prefix,
            importedPrefix: imported.reading.prefix + imported.spelling.prefix,
            english: context.englishCandidates,
            uppercase: caseCandidates,
            recencyRanks: recencyRanks(
                for: context.conversionReading,
                history: context.selectionHistory,
                learningEnabled: context.learningEnabled
            ),
            contextualCandidates: context.contextualCandidates,
            prioritizeKana: kana.first?.count == 1,
            longVowelNotationProtectedCandidates:
                longVowelNotationProtectedCandidates
        ))
    }

    private func numericPrefixCandidates(
        for input: String,
        history: CandidateSelectionHistory,
        learningEnabled: Bool
    ) -> [String] {
        guard let parts = NumericPrefixCandidateComposer.parts(of: input) else {
            return []
        }
        let readings = RomajiCanonicalizer.dictionaryLookupInputs(
            from: parts.reading
        )
        let user = mergedGroups(
            readings: readings,
            lookup: { userEngine.candidateGroups(matching: $0) }
        ).exact
        let system = mergedGroups(readings: readings) {
            systemEngine.candidateGroups(
                matching: $0,
                limit: maximumSystemPrefixCandidates
            )
        }.exact
        let basic = mergedGroups(
            readings: readings,
            lookup: { basicEngine.candidateGroups(matching: $0) }
        ).exact
        let kana = [
            romajiConverter.hiragana(from: parts.reading),
            romajiConverter.katakana(from: parts.reading)
        ].compactMap { $0 }
        let converted = CandidateRecencyOrderer.ordered(
            user + system + basic + kana,
            ranks: recencyRanks(
                for: parts.reading,
                history: history,
                learningEnabled: learningEnabled
            )
        )
        return NumericPrefixCandidateComposer.candidates(
            for: input,
            convertedReadings: converted
        )
    }

    private func particleCandidates(for input: String) -> [String] {
        JapaneseParticleCandidateGenerator.candidates(for: input) { reading in
            let readings = RomajiCanonicalizer.dictionaryLookupInputs(
                from: reading
            )
            return mergedCandidates(
                readings: readings,
                lookup: userEngine.candidates
            ) + mergedCandidates(
                readings: readings,
                lookup: basicEngine.candidates
            ) + mergedCandidates(
                readings: readings,
                lookup: systemEngine.candidates
            ) + importedGroups(readings: readings, spellings: []).reading.exact
        }
    }

    /// Splits imported matches by quality: `reading` matches the kana of
    /// the input, while `spelling` only matches the typed letters, such as
    /// SKK abbrev headwords that are English spellings
    private func importedGroups(
        readings: [String],
        spellings: [String]
    ) -> (reading: DictionaryCandidateGroups, spelling: DictionaryCandidateGroups) {
        var seenKana = Set<String>()
        let kanaReadings = readings.compactMap {
            romajiConverter.hiragana(from: $0)
        }.filter { seenKana.insert($0).inserted }
        let reading = mergedGroups(readings: kanaReadings) {
            importedEngine.candidateGroups(
                matching: $0,
                limit: maximumSystemPrefixCandidates
            )
        }
        guard !spellings.isEmpty else {
            return (reading, DictionaryCandidateGroups())
        }
        let readingMatches = Set(reading.exact + reading.prefix)
        let typed = mergedGroups(readings: spellings) {
            importedEngine.candidateGroups(
                matching: $0,
                limit: maximumSystemPrefixCandidates
            )
        }
        return (
            reading,
            DictionaryCandidateGroups(
                exact: typed.exact.filter { !readingMatches.contains($0) },
                prefix: typed.prefix.filter { !readingMatches.contains($0) }
            )
        )
    }

    private static func removingDuplicates(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values.filter { seen.insert($0).inserted }
    }

    private func recencyRanks(
        for reading: String,
        history: CandidateSelectionHistory,
        learningEnabled: Bool
    ) -> [String: Int] {
        guard learningEnabled else { return [:] }
        return history.ranks(
            for: RomajiCanonicalizer.dictionaryLookupInputs(from: reading)
        )
    }

    private func mergedCandidates(
        readings: [String],
        lookup: (String) -> [String]
    ) -> [String] {
        var seen = Set<String>()
        return readings.flatMap(lookup).filter {
            seen.insert($0).inserted
        }
    }

    private func mergedGroups(
        readings: [String],
        lookup: (String) -> DictionaryCandidateGroups
    ) -> DictionaryCandidateGroups {
        var exact: [String] = []
        var prefix: [String] = []
        var exactSet = Set<String>()
        var prefixSet = Set<String>()
        for reading in readings {
            let groups = lookup(reading)
            for candidate in groups.exact
            where exactSet.insert(candidate).inserted {
                exact.append(candidate)
            }
            for candidate in groups.prefix
            where prefixSet.insert(candidate).inserted {
                prefix.append(candidate)
            }
        }
        prefix.removeAll { exactSet.contains($0) }
        return DictionaryCandidateGroups(exact: exact, prefix: prefix)
    }
}
