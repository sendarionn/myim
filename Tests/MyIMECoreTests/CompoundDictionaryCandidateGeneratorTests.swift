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

    @Test func correctsOneTypoInsideACompoundPath() {
        let generator = makeGenerator([
            ("keiou", "慶應"),
            ("daigaku", "大学")
        ])
        let candidates = generator.candidates(
            for: "keioudaigku",
            typoMatches: { input in
                input == "daigku"
                    ? [FuzzyConversionMatch(
                        reading: "daigaku",
                        candidates: ["大学"],
                        distance: 1
                    )]
                    : []
            }
        )
        #expect(candidates == ["慶應大学"])
    }

    @Test func combinesSegmentsUsingTheActualTypoEngine() {
        let entries = [
            DictionaryEntry(reading: "keiou", candidates: ["慶應"]),
            DictionaryEntry(reading: "daigaku", candidates: ["大学"])
        ]
        let generator = CompoundDictionaryCandidateGenerator(entries: entries)
        let typoEngine = FuzzyConversionEngine(entries: entries)
        let candidates = generator.candidates(
            for: "keioudaigku",
            typoMatches: {
                typoEngine.matches(
                    for: $0,
                    maximumDistance: 1,
                    limit: 4
                )
            }
        )
        #expect(candidates == ["慶應大学"])
    }

    @Test func exposesCorrectedReadingForTypoCompound() throws {
        let generator = makeGenerator([
            ("keiou", "慶應"),
            ("daigaku", "大学")
        ])
        let matches = generator.matches(
            for: "keioudaigku",
            typoMatches: { input in
                input == "daigku"
                    ? [FuzzyConversionMatch(
                        reading: "daigaku",
                        candidates: ["大学"],
                        distance: 1
                    )]
                    : []
            }
        )

        let match = try #require(matches.first)
        #expect(match.text == "慶應大学")
        #expect(match.reading == "keioudaigaku")
        #expect(match.typoDistance == 1)
    }

    @Test func prefersAnExactCompoundPathOverATypoPath() {
        let generator = makeGenerator([
            ("keiou", "慶應"),
            ("daigku", "大具"),
            ("daigaku", "大学")
        ])
        let candidates = generator.candidates(
            for: "keioudaigku",
            typoMatches: { input in
                input == "daigku"
                    ? [FuzzyConversionMatch(
                        reading: "daigaku",
                        candidates: ["大学"],
                        distance: 1
                    )]
                    : []
            }
        )
        #expect(candidates == ["慶應大具"])
    }

    @Test func rejectsTwoCorrectedSegments() {
        let generator = makeGenerator([
            ("keiou", "慶應"),
            ("daigaku", "大学")
        ])
        let candidates = generator.candidates(
            for: "keiudaigku",
            typoMatches: { input in
                switch input {
                case "keiu":
                    [FuzzyConversionMatch(
                        reading: "keiou",
                        candidates: ["慶應"],
                        distance: 1
                    )]
                case "daigku":
                    [FuzzyConversionMatch(
                        reading: "daigaku",
                        candidates: ["大学"],
                        distance: 1
                    )]
                default:
                    []
                }
            }
        )
        #expect(candidates.isEmpty)
    }

    @Test func doesNotCorrectVeryShortSegments() {
        let generator = makeGenerator([
            ("keiou", "慶應"),
            ("to", "と")
        ])
        let candidates = generator.candidates(
            for: "keiouta",
            typoMatches: { input in
                input == "ta"
                    ? [FuzzyConversionMatch(
                        reading: "to",
                        candidates: ["と"],
                        distance: 1
                    )]
                    : []
            }
        )
        #expect(candidates.isEmpty)
    }

    private func makeGenerator(
        _ pairs: [(String, String)]
    ) -> CompoundDictionaryCandidateGenerator {
        CompoundDictionaryCandidateGenerator(entries: pairs.map {
            DictionaryEntry(reading: $0.0, candidates: [$0.1])
        })
    }
}
