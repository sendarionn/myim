import Testing
@testable import MyIMECore

@Suite
struct ArtificialKeyboardTypoEvaluationTests {
    private let cases: [(reading: String, typo: String)] = [
        ("deetabeesu", "de=tab0su"),
        ("deetabeesu", "de_tab0su"),
        ("deetabeesu", "de^tab0su"),
        ("konnichiha", "jonnichiga"),
        ("konnichiha", "konncihia"),
        ("hitsuyou", "htsuyuo"),
        ("susumete", "susmwte")
    ]

    @Test
    func recoversArtificialCompoundTyposWithinTheTopThree() {
        let engine = FuzzyConversionEngine(entries: cases.map {
            DictionaryEntry(reading: $0.reading, candidates: [$0.reading])
        })
        let hitCount = cases.filter { sample in
            engine.matches(for: sample.typo, limit: 3).contains {
                $0.reading == sample.reading
            }
        }.count

        #expect(hitCount == cases.count)
    }

    @Test
    func doesNotReturnCandidatesForUnrelatedArtificialInput() {
        let engine = FuzzyConversionEngine(entries: cases.map {
            DictionaryEntry(reading: $0.reading, candidates: [$0.reading])
        })

        #expect(engine.matches(for: "qx-zvbnm").isEmpty)
        #expect(engine.matches(for: "12345678").isEmpty)
    }

    @Test
    func longNoisyInputStillHonorsTheRequestedResultLimit() {
        let engine = FuzzyConversionEngine(entries: cases.map {
            DictionaryEntry(reading: $0.reading, candidates: [$0.reading])
        })
        let input = String(repeating: "de=tab0su", count: 20)

        #expect(engine.matches(for: input, limit: 3).count <= 3)
    }
}
