public struct StandardConversionCandidateContext: Sendable {
    public let input: String
    public let conversionReading: String
    public let javaScriptCandidates: [JavaScriptExtensionCandidate]
    public let englishCandidates: [String]
    public let selectionHistory: CandidateSelectionHistory
    public let contextualCandidates: [String]
    public let learningEnabled: Bool

    public init(
        input: String,
        conversionReading: String,
        javaScriptCandidates: [JavaScriptExtensionCandidate] = [],
        englishCandidates: [String] = [],
        selectionHistory: CandidateSelectionHistory =
            CandidateSelectionHistory(),
        contextualCandidates: [String] = [],
        learningEnabled: Bool = true
    ) {
        self.input = input
        self.conversionReading = conversionReading
        self.javaScriptCandidates = javaScriptCandidates
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
    private let adjectiveDictionary: JapaneseAdjectiveDictionary
    private let adjectiveInflectionGenerator:
        JapaneseAdjectiveInflectionCandidateGenerator
    private let verbConjugationGenerator: VerbConjugationCandidateGenerator
    private let verbInflectionGenerator: VerbInflectionCandidateGenerator
    private let maximumSystemPrefixCandidates: Int
    private let derivedExclusions: DerivedCandidateExclusions
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
        adjectiveDictionary: JapaneseAdjectiveDictionary =
            JapaneseAdjectiveDictionary(),
        maximumSystemPrefixCandidates: Int = 2048,
        derivedExclusions: DerivedCandidateExclusions = DerivedCandidateExclusions()
    ) {
        self.derivedExclusions = derivedExclusions
        self.userEngine = userEngine
        self.importedEngine = importedEngine
        self.basicEngine = basicEngine
        self.symbolEngine = symbolEngine
        self.systemEngine = systemEngine
        self.deferredSystemCandidates = deferredSystemCandidates
        self.verbConjugations = verbConjugations
        self.adjectiveDictionary = adjectiveDictionary
        adjectiveInflectionGenerator =
            JapaneseAdjectiveInflectionCandidateGenerator(
                dictionary: adjectiveDictionary
            )
        verbConjugationGenerator = VerbConjugationCandidateGenerator(
            dictionary: verbConjugations
        )
        self.verbInflectionGenerator = verbInflectionGenerator
        self.maximumSystemPrefixCandidates = maximumSystemPrefixCandidates
    }

    public func candidates(
        for context: StandardConversionCandidateContext
    ) -> [Candidate] {
        // Generated candidates the user removed are left out once every
        // source is merged, whichever made them
        let candidates = derivedExclusions.filtering(
            assembledCandidates(for: context),
            reading: context.conversionReading
        )
        // A time is committed as typed without choosing a candidate, so
        // only its formats are offered
        guard TimeShapedInput.matches(context.input) else { return candidates }
        return candidates.filter { $0.storageText != context.input }
    }

    private func assembledCandidates(
        for context: StandardConversionCandidateContext
    ) -> [Candidate] {
        let lookupReadings = RomajiCanonicalizer.dictionaryLookupInputs(
            from: context.conversionReading
        )
        let userLookupReadings = RomajiCanonicalizer.legacyLongVowelLookupInputs(
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
        // Exact words for an `n` read as ん, such as 順位 for `juni`, follow
        // every exact word of the reading as typed; prefixes and
        // compositions keep to the reading as typed
        let moraicNExact = mergedCandidates(
            readings: RomajiCanonicalizer.moraicNBeforeVowelLookupInputs(
                from: context.conversionReading
            ),
            lookup: { reading in
                userEngine.candidates(for: reading)
                    + basicEngine.candidates(for: reading)
                    + systemEngine.candidates(for: reading)
            }
        )
        let particleCompositions = particleCompositions(
            for: context.conversionReading
        )
        let particles = particleCompositions.map(\.text)
        let fullReadingRanks = recencyRanks(
            for: context.conversionReading,
            history: context.selectionHistory,
            learningEnabled: context.learningEnabled
        )
        var dynamicPreferenceRanks: [String: Int] = [:]
        if context.learningEnabled {
            for candidate in context.javaScriptCandidates {
                guard candidate.kind == .dynamicDateTime,
                      let preferenceID = candidate.preferenceID,
                      let rank = context.selectionHistory.ranks[preferenceID]
                else { continue }
                dynamicPreferenceRanks[candidate.value] = max(
                    dynamicPreferenceRanks[candidate.value] ?? 0,
                    rank
                )
            }
        }
        let combinedDirectRanks = fullReadingRanks.merging(
            dynamicPreferenceRanks,
            uniquingKeysWith: max
        )
        // The kana of `ny` read as ん + や行 follow those of the reading as
        // typed, so シンヤ is offered for `shinya` beside シニャ
        var kana: [String] = []
        let kanaReadings = [context.conversionReading]
            + [RomajiCanonicalizer.moraicNBeforeYKanaInput(
                from: context.conversionReading
            )].compactMap { $0 }
        for reading in kanaReadings {
            for value in [
                romajiConverter.hiragana(from: reading),
                romajiConverter.katakana(from: reading)
            ].compactMap({ $0 }) where !kana.contains(value) {
                kana.append(value)
            }
        }
        let caseCandidates = context.input == context.conversionReading
            ? EnglishCandidateCaseRestorer.caseCandidates(
                for: context.conversionReading
            )
            : []
        let conjugations = verbConjugationGenerator.generatedCandidates(
            for: context.conversionReading
        )
        let adjectiveInflections = adjectiveInflectionGenerator
            .generatedCandidates(
                for: context.conversionReading
            )
        let inflections = Self.mergingGeneratedInflections(
            lookupReadings.flatMap { reading in
                verbInflectionGenerator.generatedCandidates(
                    for: reading,
                    conjugations: verbConjugations
                ) + VerbInflectionCandidateGenerator.generatedCandidates(
                    for: reading,
                    conjugations: verbConjugations,
                    lookup: systemEngine.candidates
                )
            }
        )
        let generatedVerbInflections = Self.mergingGeneratedInflections(
            conjugations + inflections
        )
        let generatedVerbInflectionTexts = generatedVerbInflections.map(\.text)
        let adjectiveInflectionTexts = adjectiveInflections.map(\.text)
        let numericPrefixes = numericPrefixCandidates(
            for: context.conversionReading,
            history: context.selectionHistory,
            learningEnabled: context.learningEnabled
        )
        let exactDictionaryCandidates = user.exact
            + symbols.exact
            + basic.exact
            + system.exact
            + moraicNExact
            + imported.reading.exact
            + imported.spelling.exact
        let generatedParticles = JapaneseParticleCandidateGenerator
            .generatedOnlyCandidates(
                generated: particles,
                exactDictionaryCandidates: exactDictionaryCandidates
            )
        let generatedOnlyCandidates = Set(
            kana + numericPrefixes + generatedVerbInflectionTexts
                + adjectiveInflectionTexts + particles
        ).subtracting(exactDictionaryCandidates)
        // Selection history changes ranking without reclassifying candidates
        // that are generated for the current input as whole-input exact matches
        let learnedExact = context.selectionHistory.candidates(
            for: lookupReadings
        ).filter {
            !generatedOnlyCandidates.contains($0)
        }
        // Particle compositions also follow the selection of their base
        // candidates before established full-input selection takes precedence
        let secondaryRanks = context.learningEnabled
            ? ParticleCompositionRanking.ranks(
                for: numericPrefixes + generatedVerbInflectionTexts
                    + adjectiveInflectionTexts + particles,
                compositions: particleCompositions,
                history: context.selectionHistory,
                compositionRanks: fullReadingRanks
            )
            : nil
        return CandidateAssembly().candidates(from: .init(
            reading: context.conversionReading,
            kana: kana,
            userExact: user.exact,
            learnedExact: learnedExact,
            dateTime: context.javaScriptCandidates.filter {
                $0.kind == .dynamicDateTime
            },
            numericPrefix: numericPrefixes,
            javaScript: context.javaScriptCandidates.filter {
                $0.kind == .staticValue
            }.map(\.value),
            supplementaryJavaScript: context.javaScriptCandidates.filter {
                $0.kind == .supplementary
            }.map(\.value),
            symbolExact: symbols.exact,
            basicExact: basic.exact,
            systemExact: system.exact.filter {
                !deferredSystemExact.contains($0)
            } + moraicNExact,
            deferredSystemExact: deferredSystemExact,
            importedExact: imported.reading.exact,
            importedSpelling: imported.spelling.exact,
            inflection: [],
            generatedInflections: generatedVerbInflections,
            generatedAdjectiveInflections: adjectiveInflections,
            particle: particles,
            generatedParticles: generatedParticles,
            userPrefix: user.prefix,
            learnedCompletion: context.selectionHistory.completions(
                for: context.conversionReading,
                limit: 8
            ),
            symbolPrefix: symbols.prefix,
            systemPrefix: system.prefix,
            basicPrefix: basic.prefix,
            importedPrefix: imported.reading.prefix + imported.spelling.prefix,
            english: context.englishCandidates,
            uppercase: caseCandidates,
            recencyRanks: combinedDirectRanks,
            secondaryRanks: secondaryRanks,
            inflectionBaseRanks: context.learningEnabled
                ? context.selectionHistory.inflectionBaseRanks
                : [:],
            contextualCandidates: context.contextualCandidates,
            prioritizeKana: kana.first?.count == 1,
            longVowelNotationProtectedCandidates:
                longVowelNotationProtectedCandidates
        ))
    }

    private static func mergingGeneratedInflections(
        _ candidates: [GeneratedInflectionCandidate]
    ) -> [GeneratedInflectionCandidate] {
        var order: [String] = []
        var basesByText: [String: Set<InflectionBaseIdentity>] = [:]
        for candidate in candidates {
            if basesByText[candidate.text] == nil {
                order.append(candidate.text)
            }
            basesByText[candidate.text, default: []].formUnion(candidate.bases)
        }
        return order.map { text in
            GeneratedInflectionCandidate(
                text: text,
                bases: (basesByText[text] ?? []).sorted {
                    $0.historyKey < $1.historyKey
                }
            )
        }
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
        let userReadings = RomajiCanonicalizer.legacyLongVowelLookupInputs(
            from: parts.reading
        )
        let user = mergedGroups(
            readings: userReadings,
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

    private func particleCompositions(
        for input: String
    ) -> [ParticleComposition] {
        JapaneseParticleCandidateGenerator.compositions(
            for: input,
            adjectiveDictionary: adjectiveDictionary
        ) { reading in
            let readings = RomajiCanonicalizer.dictionaryLookupInputs(
                from: reading
            )
            let userReadings = RomajiCanonicalizer
                .legacyLongVowelLookupInputs(from: reading)
            return mergedCandidates(
                readings: userReadings,
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
        return history.lastUsedRanks(
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
