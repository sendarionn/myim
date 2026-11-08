import Foundation
import Testing
@testable import MyIMECore

/// Runs the "もしかして" pipeline with the bundled dictionaries and an
/// imported SKK layer that contains abbrev headwords such as `hs` and `tom`
@Suite(.serialized)
struct BundledFuzzyCandidateTests {
    private struct Fixture: Sendable {
        let entries: [DictionaryEntry]
        let basic: ConversionEngine
        let system: IndexedDictionaryEngine
        let conjugations: VerbConjugationDictionary
        let repository: FuzzyEngineRepository
    }

    private static let fixture: Fixture? = {
        let resources = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Sources/MyIMEMacOS/Resources")
        guard let text = try? String(
                contentsOf: resources.appendingPathComponent("basic-dictionary.tsv"),
                encoding: .utf8
              ),
              let entries = try? DictionaryParser().parse(text),
              let verbText = try? String(
                contentsOf: resources.appendingPathComponent(
                    "mozc-verb-classes.tsv"
                ),
                encoding: .utf8
              ),
              let system = try? IndexedDictionaryEngine(
                contentsOf: resources.appendingPathComponent("mozc-dictionary.tsv")
              ) else {
            return nil
        }
        let conjugations = VerbConjugationDictionary(text: verbText)
        let repository = FuzzyEngineRepository()
        repository.prepare(
            for: entries + VerbInflectionCandidateGenerator.typoSearchEntries(
                from: entries,
                conjugations: conjugations
            )
        )
        return Fixture(
            entries: entries,
            basic: ConversionEngine(entries: entries),
            system: system,
            conjugations: conjugations,
            repository: repository
        )
    }()

    private static let importedSKK = LayeredConversionEngine(engines: [
        ConversionEngine(entries: [
            DictionaryEntry(reading: "hs", candidates: ["ハッシウム"]),
            DictionaryEntry(reading: "tom", candidates: ["トム"]),
            DictionaryEntry(reading: "ma", candidates: ["Massachusetts"]),
            DictionaryEntry(reading: "さい", candidates: ["際"]),
            DictionaryEntry(reading: "ま", candidates: ["魔"]),
            DictionaryEntry(reading: "ぎょ", candidates: ["魚"]),
            DictionaryEntry(reading: "うか", candidates: ["羽化"])
        ])
    ])

    @Test(arguments: [
        ("saihshin", "最新"),
        ("gyouka", "評価"),
        ("matomte", "まとめて")
    ])
    func ranksTheCorrectedReadingFirst(query: String, expected: String) async throws {
        let fuzzyCandidates = try await fuzzyCandidates(for: query)

        #expect(fuzzyCandidates.first == expected)
    }

    @Test(arguments: [
        ("saihshin", ["際ハッシウム品", "再ハッシウム品"]),
        ("gyouka", ["魚羽化", "ギョ羽化"]),
        ("matomte", ["魔トム手", "マトム手"])
    ])
    func doesNotGenerateSplitDictionaryCompounds(
        query: String,
        fragments: [String]
    ) async throws {
        let fuzzyCandidates = try await fuzzyCandidates(for: query)
        let page = fuzzyCandidates.prefix(4)

        #expect(fragments.allSatisfy { !page.contains($0) })
    }

    @Test
    func keepsCompoundVerbInStandardCandidatesWithoutMechanicalSplits()
        async throws {
        let fixture = try #require(Self.fixture)
        let standard = StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: Self.importedSKK,
            basicEngine: fixture.basic,
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: fixture.system,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: fixture.entries
            ),
            verbConjugations: fixture.conjugations
        ).candidates(for: .init(
            input: "yobaretemo",
            conversionReading: "yobaretemo"
        )).map(\.storageText)
        let fuzzy = try await fuzzyCandidates(for: "yobaretemo")

        #expect(standard.contains("呼ばれても"))
        #expect(!fuzzy.contains("世場レテ藻"))
        #expect(!fuzzy.contains("世場レテ喪"))
    }

    @Test(arguments: [
        ("kaigii", "会議"),
        ("denwq", "電話"),
        ("keisna", "計算"),
        ("benkuo", "勉強"),
        ("tegmai", "手紙")
    ])
    func handlesOtherSingleCharacterTypos(query: String, expected: String) async throws {
        let fuzzyCandidates = try await fuzzyCandidates(for: query)

        #expect(fuzzyCandidates.prefix(4).contains(expected))
    }

    @Test
    func findsDatabaseFromMultipleRomajiErrors() async throws {
        let fuzzyCandidates = try await fuzzyCandidates(for: "de-tsb-su")

        #expect(fuzzyCandidates.prefix(4).contains("データベース"))
    }

    @Test
    func findsDatabaseFromNearbyNumberAndSymbolKeys() async throws {
        let fuzzyCandidates = try await fuzzyCandidates(for: "de=tab0su")

        #expect(fuzzyCandidates.prefix(3).contains("データベース"))
    }

    /// InputController searches with the resolved reading and excludes the
    /// standard candidates, which the typo leaves empty
    @Test(arguments: ["de=tab0su", "de-tsb-su"])
    func suggestsDatabaseWhenTheTypoLeavesNoStandardCandidate(
        input: String
    ) async throws {
        let fixture = try #require(Self.fixture)
        let reading = ConversionReadingResolver.resolve(input)
        let standard = StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: Self.importedSKK,
            basicEngine: fixture.basic,
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: fixture.system,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: []
            )
        ).candidates(for: .init(input: input, conversionReading: reading))

        let fuzzyCandidates = try await fuzzyCandidates(
            for: reading,
            visibleCandidates: Set(standard.map(\.storageText))
        )

        #expect(reading == input)
        #expect(standard.isEmpty)
        #expect(fuzzyCandidates.prefix(4).contains("データベース"))
    }

    @Test(arguments: ["de=tab0su", "de-tsb-su"])
    func learnedExactInputKeepsDatabaseFuzzyCandidateWithoutDuplicatingIt(
        input: String
    ) async throws {
        let fixture = try #require(Self.fixture)
        let learned = try #require(UnselectedInputLearningPolicy.entry(
            originalInput: input,
            hasSelectedCandidate: false
        ))
        let learnedEntry = DictionaryEntry(
            reading: learned.reading,
            candidates: [learned.candidate]
        )
        let userDictionary = LayeredConversionEngine(engines: [
            ConversionEngine(entries: [learnedEntry])
        ])
        let repository = FuzzyEngineRepository()
        repository.prepare(
            baseEntries: fixture.entries
                + VerbInflectionCandidateGenerator.typoSearchEntries(
                    from: fixture.entries,
                    conjugations: fixture.conjugations
                ),
            baseKey: "learned-exact-input-test",
            userEntries: [learnedEntry]
        )
        let standard = StandardConversionCandidateSource(
            userEngine: userDictionary,
            importedEngine: Self.importedSKK,
            basicEngine: fixture.basic,
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: fixture.system,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: []
            )
        ).candidates(for: .init(input: input, conversionReading: input))
        let source = FuzzyCandidateSource(
            query: input,
            visibleCandidates: Set(standard.map(\.storageText)),
            userDictionary: userDictionary,
            importedDictionary: Self.importedSKK,
            basicDictionary: fixture.basic,
            mozcDictionary: fixture.system,
            fuzzyRepository: repository
        )
        let fuzzyCandidates = await source.matchTiers()
            .flatMap { $0 }
            .flatMap(\.candidates)

        #expect(standard.map(\.storageText).contains(input))
        #expect(fuzzyCandidates.contains("データベース"))
        #expect(!fuzzyCandidates.contains(input))
    }

    @Test(arguments: [
        ("10=", "10="),
        ("2026nen", "2026nen"),
        ("de=", "de"),
        ("kana", "kana")
    ])
    func keepsTheReadingOfOrdinaryDigitAndSymbolInput(
        input: String,
        reading: String
    ) {
        #expect(ConversionReadingResolver.resolve(input) == reading)
    }

    /// `=`, `+`, and `_` sit on or beside the `-` key on the US layout,
    /// so the whole input is searched and the long vowel restored
    @Test(arguments: [
        ("a=to", "アート"), ("a_to", "アート"), ("a+to", "アート"),
        ("de=tab0su", "データベース"), ("de_tab0su", "データベース")
    ])
    func correctsSymbolsAroundTheLongVowelKey(
        input: String,
        expected: String
    ) async throws {
        let query = FuzzyQueryResolver.resolve(
            input: input,
            conversionReading: ConversionReadingResolver.resolve(input)
        )
        let fuzzyCandidates = try await fuzzyCandidates(for: query)

        #expect(query == input)
        #expect(fuzzyCandidates.prefix(3).contains(expected))
    }

    /// Symbols typed on purpose are not corrected into words: `a=b` is too
    /// short to be searched whole, and `foo=bar` and `x+y` reach no word
    @Test(arguments: ["a=b", "foo=bar", "x+y"])
    func doesNotCorrectIntendedSymbols(input: String) async throws {
        let reading = ConversionReadingResolver.resolve(input)
        let query = FuzzyQueryResolver.resolve(
            input: input,
            conversionReading: reading
        )
        let fuzzyCandidates = try await fuzzyCandidates(for: input)

        #expect(query == reading || query == input)
        #expect(fuzzyCandidates.isEmpty)
    }

    /// Mirrors InputController: the standard candidates come from the
    /// reading `a`, which completes to アート among thousands of words, and
    /// must not hide アート corrected from the whole input
    @Test(arguments: [("a=to", "アート"), ("a_to", "アート")])
    func showsTheWholeInputCorrectionBesideStandardCompletions(
        input: String,
        expected: String
    ) async throws {
        let fixture = try #require(Self.fixture)
        let reading = ConversionReadingResolver.resolve(input)
        let query = FuzzyQueryResolver.resolve(
            input: input,
            conversionReading: reading
        )
        // Committed as typed once, as the unselected input learning does
        let userDictionary = LayeredConversionEngine(engines: [
            ConversionEngine(entries: [
                DictionaryEntry(reading: input, candidates: [input])
            ])
        ])
        let standard = StandardConversionCandidateSource(
            userEngine: userDictionary,
            importedEngine: Self.importedSKK,
            basicEngine: fixture.basic,
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: fixture.system,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: []
            )
        ).candidates(for: .init(input: input, conversionReading: reading))
            .map(\.storageText)

        let fuzzyCandidates = try await fuzzyCandidates(
            for: query,
            visibleCandidates: FuzzyQueryResolver.duplicateCandidates(
                standardCandidates: standard,
                query: query,
                conversionReading: reading
            )
        )
        let suffix = FuzzyQueryResolver.suffix(
            input: input,
            query: query,
            conversionReading: reading,
            conversionSuffix: ConversionReadingSuffix.resolve(
                conversionReading: reading,
                originalInput: input
            )
        )

        #expect(standard.contains(expected))
        #expect(fuzzyCandidates.prefix(3).contains(expected))
        #expect(suffix.isEmpty)
    }

    /// When the reading itself is searched, standard candidates are still
    /// not repeated as fuzzy candidates
    @Test
    func stillExcludesStandardCandidatesForTheSameReading() {
        #expect(FuzzyQueryResolver.duplicateCandidates(
            standardCandidates: ["データベース"],
            query: "de-tsb-su",
            conversionReading: "de-tsb-su"
        ) == ["データベース"])
        #expect(FuzzyQueryResolver.suffix(
            input: "watashiha=",
            query: "watashiha",
            conversionReading: "watashiha",
            conversionSuffix: "="
        ) == "=")
    }

    /// Three keys beside the intended ones, `z`, `=`, and `p` for `a`,
    /// `-`, and `o`, still reach the word when nothing closer is found
    @Test
    func correctsSeveralAdjacentKeysWhenNothingCloserIsFound() async throws {
        let input = "z=tp"
        let reading = ConversionReadingResolver.resolve(input)
        let query = FuzzyQueryResolver.resolve(
            input: input,
            conversionReading: reading
        )
        let fixture = try #require(Self.fixture)
        let tiers = await FuzzyCandidateSource(
            query: query,
            visibleCandidates: [],
            userDictionary: LayeredConversionEngine(engines: []),
            importedDictionary: Self.importedSKK,
            basicDictionary: fixture.basic,
            mozcDictionary: fixture.system,
            fuzzyRepository: fixture.repository
        ).matchTiers()

        #expect(query == input)
        #expect(tiers.dropLast().allSatisfy { $0.isEmpty })
        #expect(tiers.last?.first?.candidates.contains("アート") == true)
        let candidates = try await fuzzyCandidates(for: query)
        #expect(candidates.prefix(3).contains("アート"))
        #expect(FuzzyQueryResolver.suffix(
            input: input,
            query: query,
            conversionReading: reading,
            conversionSuffix: ""
        ).isEmpty)
    }

    /// Inputs the ordinary search corrects keep their candidates and order,
    /// and gather no corrections of several keys
    @Test(arguments: [
        ("kaigii", "会議"), ("denwq", "電話"), ("keisna", "計算"),
        ("hiruyou", "必要"), ("konncihia", "こんにちは"), ("susmete", "進めて")
    ])
    func keepsOrdinaryCorrectionsWithoutSeveralKeyCorrections(
        query: String,
        expected: String
    ) async throws {
        let fixture = try #require(Self.fixture)
        let tiers = await FuzzyCandidateSource(
            query: query,
            visibleCandidates: [],
            userDictionary: LayeredConversionEngine(engines: []),
            importedDictionary: Self.importedSKK,
            basicDictionary: fixture.basic,
            mozcDictionary: fixture.system,
            fuzzyRepository: fixture.repository
        ).matchTiers()

        #expect(tiers.last?.isEmpty == true)
        let candidates = try await fuzzyCandidates(for: query)
        #expect(candidates.prefix(4).contains(expected))
    }

    private func standardSource() throws -> StandardConversionCandidateSource {
        let fixture = try #require(Self.fixture)
        return StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: Self.importedSKK,
            basicEngine: fixture.basic,
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: fixture.system,
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: fixture.entries
            ),
            verbConjugations: fixture.conjugations
        )
    }

    private func firstPanel(
        _ reading: String,
        history: CandidateSelectionHistory
    ) throws -> String? {
        try standardSource().candidates(for: .init(
            input: reading,
            conversionReading: reading,
            selectionHistory: history
        )).first?.storageText
    }

    private func secondPanelMatch(
        _ query: String,
        reading: String,
        history: CandidateSelectionHistory
    ) async throws -> FuzzyConversionMatch? {
        let fixture = try #require(Self.fixture)
        let tiers = await FuzzyCandidateSource(
            query: query,
            visibleCandidates: [],
            userDictionary: LayeredConversionEngine(engines: []),
            importedDictionary: Self.importedSKK,
            basicDictionary: fixture.basic,
            mozcDictionary: fixture.system,
            fuzzyRepository: fixture.repository,
            ranking: FuzzyCandidateRanking(
                standardSource: try standardSource(),
                selectionHistory: history
            )
        ).matchTiers()
        return tiers.flatMap { $0 }.first { $0.reading == reading }
    }

    /// `ahite` corrected to `shite` offers what the first panel puts first
    /// for `shite`, with no history and after either word is learned
    @Test(arguments: [String?.none, "して", "仕手"])
    func correctedReadingOffersTheFirstPanelsFirstCandidate(
        learned: String?
    ) async throws {
        var history = CandidateSelectionHistory()
        if let learned {
            history.record(learned, reading: "shite")
            history.record(learned, reading: "shite")
        }

        let first = try firstPanel("shite", history: history)
        let match = try await secondPanelMatch(
            "ahite",
            reading: "shite",
            history: history
        )

        if let learned {
            #expect(first == learned)
        }
        #expect(match?.candidates.first == first)
    }

    @Test
    func correctedReadingUsesCompoundVerbGeneration() throws {
        let ranked = FuzzyCandidateRanking(
            standardSource: try standardSource(),
            selectionHistory: CandidateSelectionHistory()
        ).ranked(
            [[FuzzyConversionMatch(
                reading: "tsukaenakunatta",
                candidates: ["つかえなくなった"],
                distance: 1
            )]],
            for: "tsukaenakunattq",
            excluding: []
        )

        #expect(ranked.first?.first?.candidates == ["使えなくなった"])
    }

    /// Choosing して in the second panel records it for `shite` too, as
    /// InputController does, so the first panel puts it first once chosen
    /// twice as kana always needs, also after the history is saved and read
    @Test
    func secondPanelChoiceReachesTheFirstPanel() throws {
        var history = CandidateSelectionHistory()
        history.record("して", readings: ["ahite", "shite"])
        #expect(try firstPanel("shite", history: history) != "して")

        history.record("して", readings: ["ahite", "shite"])
        history = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: JSONEncoder().encode(history)
        )

        #expect(try firstPanel("shite", history: history) == "して")
    }

    /// A corrected typo is not added to the user dictionary, whether it is
    /// generated kana or a dictionary word
    @Test(arguments: ["して", "仕手"])
    func correctedTyposAreNotAddedToTheUserDictionary(
        learned: String
    ) async throws {
        var history = CandidateSelectionHistory()
        history.record(learned, reading: "shite")
        history.record(learned, reading: "shite")
        let match = try #require(try await secondPanelMatch(
            "ahite",
            reading: "shite",
            history: history
        ))
        var session = FuzzyCandidateSession()
        session.replace(matchTiers: [[match]], recencyRanks: [:])
        let candidate = try #require(session.candidates.first)

        #expect(candidate.storageText == learned)
        #expect(candidate.origin == .typoCorrection)
        #expect(candidate.userDictionaryEntry == nil)
    }

    /// Committing the corrected typo learns it for `shite`, not `ahite`, and
    /// the first panel of `shite` follows it; nothing is learned for `ahite`
    @Test
    func correctedTypoIsLearnedForTheCorrectedReadingOnly() async throws {
        let match = try #require(try await secondPanelMatch(
            "ahite",
            reading: "shite",
            history: CandidateSelectionHistory()
        ))
        var session = FuzzyCandidateSession()
        session.replace(matchTiers: [[match]], recencyRanks: [:])
        let candidate = try #require(session.candidates.first)
        var history = CandidateSelectionHistory()

        for _ in 0..<2 {
            history.record(
                "仕手",
                readings: FuzzySelectionLearning.historyReadings(
                    for: FuzzyCandidate(
                        storageText: "仕手",
                        reading: candidate.reading,
                        distance: candidate.distance,
                        origin: candidate.origin
                    ),
                    query: "ahite"
                )
            )
        }
        history = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: JSONEncoder().encode(history)
        )

        #expect(history.candidates(for: ["shite"]).contains("仕手"))
        #expect(history.candidates(for: ["ahite"]).isEmpty)
        #expect(try firstPanel("shite", history: history) == "仕手")
        let next = try await secondPanelMatch(
            "ahite",
            reading: "shite",
            history: history
        )
        #expect(next?.candidates.first == "仕手")
    }

    /// The corrections and their order of readings stay as before
    @Test(arguments: [
        ("kaigii", "会議"), ("denwq", "電話"), ("keisna", "計算"),
        ("saihshin", "最新"), ("susmete", "進めて"), ("z=tp", "アート")
    ])
    func keepsTheCorrectionsWhenRanked(query: String, expected: String)
        async throws {
        let fixture = try #require(Self.fixture)
        let source = { (ranking: FuzzyCandidateRanking?) in
            FuzzyCandidateSource(
                query: query,
                visibleCandidates: [],
                userDictionary: LayeredConversionEngine(engines: []),
                importedDictionary: Self.importedSKK,
                basicDictionary: fixture.basic,
                mozcDictionary: fixture.system,
                fuzzyRepository: fixture.repository,
                ranking: ranking
            )
        }
        let plain = await source(nil).matchTiers()
        let ranked = await source(FuzzyCandidateRanking(
            standardSource: try standardSource(),
            selectionHistory: CandidateSelectionHistory()
        )).matchTiers()

        #expect(ranked.map { $0.map(\.reading) }
            == plain.map { $0.map(\.reading) })
        var session = FuzzyCandidateSession()
        session.replace(matchTiers: ranked, recencyRanks: [:])
        #expect(session.candidates.prefix(4).map(\.storageText)
            .contains(expected))
    }

    private func fuzzyCandidates(
        for query: String,
        visibleCandidates: Set<String> = []
    ) async throws -> [String] {
        let fixture = try #require(Self.fixture)
        let source = FuzzyCandidateSource(
            query: query,
            visibleCandidates: visibleCandidates,
            userDictionary: LayeredConversionEngine(engines: []),
            importedDictionary: Self.importedSKK,
            basicDictionary: fixture.basic,
            mozcDictionary: fixture.system,
            fuzzyRepository: fixture.repository
        )
        var session = FuzzyCandidateSession()
        session.replace(
            matchTiers: await source.matchTiers(),
            recencyRanks: [:]
        )
        return session.candidates.map(\.storageText)
    }
}
