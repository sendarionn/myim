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
            DictionaryEntry(input: "byuu", candidates: ["ビュー", "別府"])
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
