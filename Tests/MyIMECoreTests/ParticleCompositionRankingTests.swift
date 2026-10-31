import Foundation
import Testing
@testable import MyIMECore

/// Particle compositions follow the ordinary conversion choices of the
/// candidate before the particle
@Suite
struct ParticleCompositionRankingTests {
    private let source = StandardConversionCandidateSource(
        userEngine: LayeredConversionEngine(engines: []),
        importedEngine: LayeredConversionEngine(engines: []),
        basicEngine: ConversionEngine(entries: [
            DictionaryEntry(reading: "watashi", candidates: ["私", "渡し", "わたし"])
        ]),
        symbolEngine: ConversionEngine(entries: []),
        systemEngine: IndexedDictionaryEngine(),
        verbInflectionGenerator: VerbInflectionCandidateGenerator(entries: [])
    )

    @Test
    func withoutHistoryTheDictionaryOrderIsKept() {
        #expect(compositions("watashiha", CandidateSelectionHistory())
            == ["私は", "渡しは", "わたしは"])
    }

    @Test
    func followsTheBaseCandidateChosenLast() {
        var history = CandidateSelectionHistory()
        history.record("渡し", reading: "watashi")
        #expect(compositions("watashiha", history).first == "渡しは")

        history.record("私", reading: "watashi")
        #expect(compositions("watashiha", history)
            == ["私は", "渡しは", "わたしは"])
    }

    @Test(arguments: ["watashiha", "watashiga", "watashiwo", "watashini"])
    func everyParticleUsesTheSameBaseHistory(input: String) {
        var history = CandidateSelectionHistory()
        history.record("渡し", reading: "watashi")

        #expect(compositions(input, history).first?.hasPrefix("渡し") == true)
    }

    @Test
    func compositionsOwnEstablishedHistoryOutranksBaseHistory() {
        var history = CandidateSelectionHistory()
        for _ in 0..<3 {
            history.record("私は", reading: "watashiha")
        }
        history.record("渡し", reading: "watashi")

        #expect(compositions("watashiha", history)
            == ["私は", "渡しは", "わたしは"])
    }

    @Test
    func compositionsOwnHistoryBreaksTies() {
        var history = CandidateSelectionHistory()
        history.record("渡しは", reading: "watashiha")

        #expect(compositions("watashiha", history)
            == ["渡しは", "私は", "わたしは"])
    }

    @Test
    func compoundConnectionsUseTheSameSelectionHistory() {
        let compoundSource = StandardConversionCandidateSource(
            userEngine: LayeredConversionEngine(engines: []),
            importedEngine: LayeredConversionEngine(engines: []),
            basicEngine: ConversionEngine(entries: [
                DictionaryEntry(reading: "gakusei", candidates: ["学生", "学政"])
            ]),
            symbolEngine: ConversionEngine(entries: []),
            systemEngine: IndexedDictionaryEngine(),
            verbInflectionGenerator: VerbInflectionCandidateGenerator(
                entries: []
            )
        )
        var history = CandidateSelectionHistory()
        history.record("学政として", reading: "gakuseitoshite")

        let candidates = compoundSource.candidates(for: .init(
            input: "gakuseitoshite",
            conversionReading: "gakuseitoshite",
            selectionHistory: history
        )).filter { $0.hasSource(.particleComposition) }.map(\.storageText)

        #expect(candidates == ["学政として", "学生として"])
    }

    @Test
    func kanaBaseCountsFromItsSecondSelection() {
        var history = CandidateSelectionHistory()
        history.record("わたし", reading: "watashi")
        #expect(compositions("watashiha", history).first == "私は")

        history.record("わたし", reading: "watashi")
        #expect(compositions("watashiha", history).first == "わたしは")
    }

    @Test
    func baseChosenForAnotherReadingIsNotApplied() {
        var history = CandidateSelectionHistory()
        history.record("渡し", reading: "watasi")

        #expect(compositions("watashiha", history)
            == ["私は", "渡しは", "わたしは"])
    }

    @Test
    func learnedOrderSurvivesARestart() throws {
        var history = CandidateSelectionHistory()
        history.record("渡し", reading: "watashi")

        let restored = try JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: JSONEncoder().encode(history)
        )

        #expect(compositions("watashiha", restored).first == "渡しは")
    }

    @Test
    func ordinaryConversionKeepsItsOrder() {
        var history = CandidateSelectionHistory()
        history.record("渡し", reading: "watashi")

        let candidates = source.candidates(for: .init(
            input: "watashi",
            conversionReading: "watashi",
            selectionHistory: history
        )).map(\.storageText)

        #expect(candidates.first == "渡し")
        #expect(candidates.count == Set(candidates).count)
    }

    /// The particle compositions shown for `input`, in panel order
    private func compositions(
        _ input: String,
        _ history: CandidateSelectionHistory
    ) -> [String] {
        let all = source.candidates(for: .init(
            input: input,
            conversionReading: input,
            selectionHistory: history
        )).filter { $0.hasSource(.particleComposition) }.map(\.storageText)
        #expect(all.count == Set(all).count)
        return all
    }
}
