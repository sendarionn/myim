import Testing
@testable import MyIMECore

struct CompoundDictionaryCandidateGeneratorTests {
    @Test func combinesCompleteDictionarySegments() {
        let generator = makeGenerator([
            ("keiou", "慶應"),
            ("daigaku", "大学")
        ])
        #expect(generator.candidates(for: "keioudaigaku") == ["慶應大学"])
    }

    @Test func prefersLongMatchOverShortPrefix() {
        let generator = makeGenerator([
            ("kei", "軽"),
            ("keiou", "慶應"),
            ("daigaku", "大学")
        ])
        #expect(generator.candidates(for: "keioudaigaku") == ["慶應大学"])
    }

    @Test func rejectsIncompleteCoverage() {
        let generator = makeGenerator([
            ("keiou", "慶應"),
            ("daigaku", "大学")
        ])
        #expect(generator.candidates(for: "keiouunknown") == [])
    }

    @Test func doesNotReplaceDirectDictionaryCandidates() {
        let generator = makeGenerator([
            ("tokyo", "東京"),
            ("tower", "タワー"),
            ("tokyotower", "東京タワー")
        ])
        #expect(generator.candidates(for: "tokyotower") == [])
    }

    @Test func keepsCompoundVariantsThatDifferFromDirectCandidates() {
        let generator = CompoundDictionaryCandidateGenerator(entries: [
            DictionaryEntry(reading: "keiou", candidates: ["京王", "慶応", "慶應"]),
            DictionaryEntry(reading: "daigaku", candidates: ["大学"]),
            DictionaryEntry(reading: "keioudaigaku", candidates: ["慶応大学"])
        ])
        let candidates = generator.candidates(for: "keioudaigaku")
        #expect(candidates.contains("慶應大学"))
        #expect(!candidates.contains("慶応大学"))
    }

    @Test func prefersFewerLongerSegments() {
        let generator = makeGenerator([
            ("to", "都"),
            ("kyo", "京"),
            ("tokyo", "東京"),
            ("tower", "タワー")
        ])
        #expect(generator.candidates(for: "tokyotower") == ["東京タワー"])
    }

    @Test func rejectsSingleCharacterOverSegmentation() {
        let generator = makeGenerator([
            ("a", "あ"),
            ("b", "び"),
            ("c", "し"),
            ("d", "ど")
        ])
        #expect(generator.candidates(for: "abcd") == [])
    }

    @Test func combinesCandidatesFromAnIndexedDictionaryLookup() {
        let generator = makeGenerator([
            ("daigaku", "大学")
        ])
        let candidates = generator.candidates(for: "keioudaigaku") {
            $0 == "keiou" ? ["慶應"] : []
        }
        #expect(candidates == ["慶應大学"])
    }

    private func makeGenerator(
        _ pairs: [(String, String)]
    ) -> CompoundDictionaryCandidateGenerator {
        CompoundDictionaryCandidateGenerator(entries: pairs.map {
            DictionaryEntry(reading: $0.0, candidates: [$0.1])
        })
    }
}
