import Testing
@testable import MyIMECore

@Suite
struct CandidateAssemblyTests {
    @Test
    func preservesTierOrderAndSourceSpecificLearningMetadata() {
        let candidates = CandidateAssembly().candidates(from: .init(
            reading: "kouhowo",
            kana: ["こうほを", "コウホヲ"],
            userExact: [],
            learnedExact: [],
            dateTime: [],
            numericPrefix: [],
            javaScript: [],
            symbolExact: [],
            basicExact: ["公募を"],
            systemExact: [],
            inflection: [],
            particle: ["候補を"],
            generatedParticles: ["候補を"],
            userPrefix: [],
            learnedCompletion: [],
            external: [],
            symbolPrefix: [],
            systemPrefix: [],
            basicPrefix: [],
            english: [],
            uppercase: [],
            recencyRanks: ["候補を": 100],
            contextualCandidates: [],
            prioritizeKana: false
        ))

        #expect(candidates.map(\.storageText) == [
            "公募を", "候補を", "こうほを", "コウホヲ"
        ])
        #expect(candidates[1].primarySource == .particleComposition)
        #expect(candidates[1].isLearnable)
        #expect(candidates[1].hasAttribute(.generated))
    }
}
