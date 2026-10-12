import Foundation
import Testing
@testable import MyIMECore

@Suite
struct FuzzySuggestionSourceTests {
    @Test
    func generatesTypoCorrectedCompoundTiers() async {
        let entries = [
            DictionaryEntry(input: "keiou", candidates: ["慶應"]),
            DictionaryEntry(input: "daigaku", candidates: ["大学"])
        ]
        let repository = FuzzyEngineRepository()
        repository.prepare(for: entries)
        let source = makeSource(
            query: "keioudaigku",
            entries: entries,
            repository: repository
        )

        let candidates = await source.matchTiers()
            .flatMap { $0 }
            .flatMap(\.candidates)

        #expect(candidates.contains("慶應大学"))
    }

    @Test
    func excludesCandidatesAlreadyVisibleInTheMainPanel() async {
        let entries = [
            DictionaryEntry(input: "kouho", candidates: ["候補"])
        ]
        let repository = FuzzyEngineRepository()
        repository.prepare(for: entries)
        let source = makeSource(
            query: "kougo",
            entries: entries,
            repository: repository,
            visibleCandidates: ["候補"]
        )

        let candidates = await source.matchTiers()
            .flatMap { $0 }
            .flatMap(\.candidates)

        #expect(!candidates.contains("候補"))
    }

    @Test
    func typedLongVowelDoesNotSuggestUnrelatedExpandedReadingCandidate() async {
        let entries = [
            DictionaryEntry(input: "byu-", candidates: ["ビュー"]),
            DictionaryEntry(input: "byuu", candidates: ["別府"])
        ]
        let repository = FuzzyEngineRepository()
        repository.prepare(for: entries)
        let source = makeSource(
            query: "byu-",
            entries: entries,
            repository: repository
        )

        let candidates = await source.matchTiers()
            .flatMap { $0 }
            .flatMap(\.candidates)

        #expect(!candidates.contains("別府"))
    }

    @Test
    func excludesCompoundContainingAHiraganaSegment() async {
        let entries = [
            DictionaryEntry(input: "tokyo", candidates: ["東京"]),
            DictionaryEntry(input: "to", candidates: ["と"])
        ]
        let repository = FuzzyEngineRepository()
        repository.prepare(for: entries)
        let source = makeSource(
            query: "tokyoto",
            entries: entries,
            repository: repository
        )

        let candidates = await source.matchTiers()
            .flatMap { $0 }
            .flatMap(\.candidates)

        #expect(!candidates.contains("東京と"))
    }

    @Test
    func combinesLongVowelSegmentsThroughTheFuzzySource() async {
        let entries = [
            DictionaryEntry(input: "yu-za-", candidates: ["ユーザー"]),
            DictionaryEntry(input: "jisho", candidates: ["辞書"])
        ]
        let repository = FuzzyEngineRepository()
        repository.prepare(for: entries)
        let source = makeSource(
            query: "yu-za-jisho",
            entries: entries,
            repository: repository
        )

        let candidates = await source.matchTiers()
            .flatMap { $0 }
            .flatMap(\.candidates)

        #expect(candidates.contains("ユーザー辞書"))
    }

    @Test
    func placesLearnedCompoundInFuzzySuggestionsBesideNormalCandidates() async {
        let repository = FuzzyEngineRepository()
        repository.prepare(for: [])
        let learned = LearnedCompoundPrediction(
            text: "東京都中野区",
            reading: "toukyoutonakanoku",
            sourceTokens: ["東京都", "中野区"],
            sourceReadings: ["toukyouto", "nakanoku"]
        )
        let source = FuzzySuggestionSource(
            query: "toukyoutonaka",
            visibleCandidates: ["東京都"],
            userDictionary: LayeredConversionEngine(engines: []),
            basicDictionary: ConversionEngine(entries: []),
            mozcDictionary: IndexedDictionaryEngine(),
            compoundGenerator: CompoundDictionaryCandidateGenerator(
                entries: []
            ),
            fuzzyRepository: repository,
            learnedCompounds: [learned]
        )

        let match = await source.matchTiers().first?.first

        #expect(match?.candidates == ["東京都中野区"])
        #expect(match?.isLearnable == false)
        #expect(match?.sourceTokens == ["東京都", "中野区"])
    }

    @Test
    func excludesLearnedCompoundAlreadyVisibleAsANormalCandidate() async {
        let repository = FuzzyEngineRepository()
        repository.prepare(for: [])
        let learned = LearnedCompoundPrediction(
            text: "東京都中野区",
            reading: "toukyoutonakanoku",
            sourceTokens: ["東京都", "中野区"],
            sourceReadings: ["toukyouto", "nakanoku"]
        )
        let source = FuzzySuggestionSource(
            query: "toukyouto",
            visibleCandidates: ["東京都中野区"],
            userDictionary: LayeredConversionEngine(engines: []),
            basicDictionary: ConversionEngine(entries: []),
            mozcDictionary: IndexedDictionaryEngine(),
            compoundGenerator: CompoundDictionaryCandidateGenerator(
                entries: []
            ),
            fuzzyRepository: repository,
            learnedCompounds: [learned]
        )

        let candidates = await source.matchTiers()
            .flatMap { $0 }
            .flatMap(\.candidates)

        #expect(!candidates.contains("東京都中野区"))
    }

    private func makeSource(
        query: String,
        entries: [DictionaryEntry],
        repository: FuzzyEngineRepository,
        visibleCandidates: Set<String> = []
    ) -> FuzzySuggestionSource {
        FuzzySuggestionSource(
            query: query,
            visibleCandidates: visibleCandidates,
            userDictionary: LayeredConversionEngine(engines: []),
            basicDictionary: ConversionEngine(entries: entries),
            mozcDictionary: IndexedDictionaryEngine(),
            compoundGenerator: CompoundDictionaryCandidateGenerator(
                entries: entries
            ),
            fuzzyRepository: repository
        )
    }
}
