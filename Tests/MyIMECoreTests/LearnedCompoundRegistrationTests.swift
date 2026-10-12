import Foundation
import Testing
@testable import MyIMECore

/// A learned phrase is only recommended until the user commits it from
/// the fuzzy candidates, which saves its full reading
@Suite
struct LearnedCompoundRegistrationTests {
    @Test(arguments: ["toukyouto", "toukyoutonaka"])
    func committingTheLearnedPhraseRegistersItsFullReading(
        query: String
    ) async throws {
        let learning = learnedTokyoNakano()
        let suggestion = try #require(
            await suggestions(for: query, learning: learning).first {
                $0.candidate == "東京都中野区"
            }
        )

        #expect(suggestion.userDictionaryEntry == UserDictionaryRegistration(
            reading: "toukyoutonakanoku",
            candidate: "東京都中野区"
        ))
    }

    @Test
    func learningAndShowingThePhraseLeaveTheDictionaryUnchanged() async {
        let store = UserDictionaryStore(entries: []) { _ in }
        let learning = learnedTokyoNakano()

        let shown = await suggestions(for: "toukyouto", learning: learning)

        #expect(shown.contains { $0.candidate == "東京都中野区" })
        #expect(store.entries.isEmpty)
    }

    @Test
    func registeredPhraseBecomesAStandardCandidateOnce() async throws {
        let store = UserDictionaryStore(entries: []) { _ in }
        let learning = learnedTokyoNakano()
        let entry = try #require(
            await suggestions(for: "toukyoutonaka", learning: learning).first {
                $0.candidate == "東京都中野区"
            }?.userDictionaryEntry
        )

        for _ in 0..<2 {
            try store.add(reading: entry.reading, candidate: entry.candidate)
        }

        #expect(store.entries.count == 1)
        #expect(store.entries.first?.candidates == ["東京都中野区"])
        #expect(normalCandidates(
            for: "toukyoutonakanoku",
            userEntries: store.entries
        ).contains("東京都中野区"))
    }

    @Test
    func phraseRemovedFromTheDictionaryIsSuggestedAndRegisteredAgain()
        async throws {
        let store = UserDictionaryStore(entries: []) { _ in }
        let learning = learnedTokyoNakano()
        let entry = try #require(
            await suggestions(for: "toukyouto", learning: learning).first {
                $0.candidate == "東京都中野区"
            }?.userDictionaryEntry
        )
        try store.add(reading: entry.reading, candidate: entry.candidate)

        try store.remove(
            candidate: entry.candidate,
            matchingReadings: [entry.reading]
        )
        let again = await suggestions(for: "toukyouto", learning: learning)
            .first { $0.candidate == "東京都中野区" }

        #expect(store.entries.isEmpty)
        #expect(again?.userDictionaryEntry == entry)
    }

    @Test
    func phraseWithAMissingReadingIsNotRegistered() {
        let suggestion = FuzzyCandidate(
            candidate: "東京都中野区",
            reading: "toukyouto",
            distance: 0,
            isLearnable: false,
            sourceTokens: ["東京都", "中野区"],
            sourceReadings: ["toukyouto", nil]
        )

        #expect(suggestion.userDictionaryEntry == nil)
    }

    @Test
    func phraseWhoseTokensDoNotFormTheTextIsNotRegistered() {
        let suggestion = FuzzyCandidate(
            candidate: "東京都中野区",
            reading: "toukyoutonakanoku",
            distance: 0,
            isLearnable: false,
            sourceTokens: ["東京都", "中野"],
            sourceReadings: ["toukyouto", "nakano"]
        )

        #expect(suggestion.userDictionaryEntry == nil)
    }

    @Test
    func ordinarySpellingSuggestionsKeepTheirRegistration() {
        let correction = FuzzyCandidate(
            candidate: "最新",
            reading: "saishin",
            distance: 1
        )
        let notLearnable = FuzzyCandidate(
            candidate: "際ハッシウム品",
            reading: "saihshin",
            distance: 1,
            isLearnable: false
        )

        #expect(correction.userDictionaryEntry == UserDictionaryRegistration(
            reading: "saishin",
            candidate: "最新"
        ))
        #expect(notLearnable.userDictionaryEntry == nil)
    }

    /// 東京都 typed and 中野区 picked from the next-input suggestions
    /// often enough for the pair to be learned
    private func learnedTokyoNakano() -> NextInputCandidateCoordinator {
        let coordinator = NextInputCandidateCoordinator(
            predictionModel: NextInputPredictionModel(),
            writer: DeferredJSONFileWriter(
                fileURL: FileManager.default.temporaryDirectory
                    .appendingPathComponent(UUID().uuidString)
                    .appendingPathComponent("next-input.json"),
                delay: 60,
                queueLabel: "myim.learned-compound-registration-test"
            )
        )
        for _ in 0..<NextInputPredictionModel.minimumDirectSequenceCount {
            for (text, reading) in [
                ("東京都", "toukyouto"),
                ("中野区", "nakanoku"),
                ("。", ".")
            ] {
                _ = coordinator.learnedCandidateModels(
                    after: text,
                    committedTokens: [
                        NextInputLearningToken(text: text, reading: reading)
                    ],
                    learningSource: .directInput,
                    predictionEnabled: true,
                    learningEnabled: true,
                    breakPreviousSequence: false,
                    limit: 16
                )
            }
        }
        return coordinator
    }

    private func suggestions(
        for query: String,
        learning: NextInputCandidateCoordinator
    ) async -> [FuzzyCandidate] {
        let visible: Set<String> = ["東京都"]
        let repository = FuzzyEngineRepository()
        repository.prepare(for: [])
        let source = FuzzyCandidateSource(
            query: query,
            visibleCandidates: visible,
            userDictionary: LayeredConversionEngine(engines: []),
            basicDictionary: ConversionEngine(entries: []),
            mozcDictionary: IndexedDictionaryEngine(),
            compoundGenerator: CompoundDictionaryCandidateGenerator(
                entries: []
            ),
            fuzzyRepository: repository,
            learnedCompounds: learning.learnedCompoundPredictions(
                matchingPrefix: query,
                excluding: visible
            )
        )
        var coordinator = FuzzyCandidateSession()
        coordinator.replace(
            matchTiers: await source.matchTiers(),
            recencyRanks: [:]
        )
        return coordinator.candidates
    }

    private func normalCandidates(
        for input: String,
        userEntries: [DictionaryEntry]
    ) -> [String] {
        StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: [
                ConversionEngine(entries: userEntries)
            ]),
            importedEngine: LayeredConversionEngine(engines: []),
            basicEngine: ConversionEngine(entries: []),
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: IndexedDictionaryEngine(),
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: []
            )
        ).candidates(for: .init(input: input, conversionReading: input))
            .map(\.storageText)
    }
}
