import Testing
@testable import MyIMECore

@Suite
struct CandidateAssemblyTests {
    @Test
    func promotesLearnedParticleAndPreservesLearningMetadata() {
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
            "候補を", "公募を", "こうほを", "コウホヲ"
        ])
        #expect(candidates[0].primarySource == .particleComposition)
        #expect(candidates[0].isLearnable)
        #expect(candidates[0].hasAttribute(.generated))
    }

    @Test
    func keepsEveryExactCandidateAheadOfUnlearnedGeneratedCandidates() throws {
        let candidates = CandidateAssembly().candidates(from: .init(
            reading: "whole",
            kana: ["かな"],
            userExact: ["ユーザー完全"],
            learnedExact: ["履歴完全"],
            dateTime: [],
            numericPrefix: ["数字合成"],
            javaScript: [],
            symbolExact: ["記号完全"],
            basicExact: ["基本完全"],
            systemExact: ["Mozc完全"],
            deferredSystemExact: ["旧後回し完全"],
            importedExact: ["取込完全"],
            importedSpelling: ["取込見出し完全"],
            inflection: ["活用生成"],
            particle: ["助詞合成"],
            generatedParticles: ["助詞合成"],
            userPrefix: [],
            learnedCompletion: [],
            symbolPrefix: [],
            systemPrefix: [],
            basicPrefix: [],
            english: [],
            uppercase: [],
            recencyRanks: [:],
            secondaryRanks: ["助詞合成": 100],
            contextualCandidates: [],
            prioritizeKana: false
        ))
        let values = candidates.map(\.storageText)
        let exactValues = [
            "ユーザー完全", "履歴完全", "記号完全", "基本完全",
            "Mozc完全", "旧後回し完全", "取込完全", "取込見出し完全"
        ]
        let generatedValues = ["数字合成", "活用生成", "助詞合成"]
        let lastExact = try #require(exactValues.compactMap {
            values.firstIndex(of: $0)
        }.max())
        let firstGenerated = try #require(generatedValues.compactMap {
            values.firstIndex(of: $0)
        }.min())

        #expect(lastExact < firstGenerated)
    }

    @Test
    func keepsLearnedOrderingInsideTheGeneratedTier() {
        let candidates = CandidateAssembly().candidates(from: .init(
            reading: "whole",
            kana: [],
            userExact: [],
            learnedExact: [],
            dateTime: [],
            numericPrefix: ["数字合成"],
            javaScript: [],
            symbolExact: [],
            basicExact: ["完全一致"],
            systemExact: [],
            inflection: ["活用生成"],
            particle: ["助詞合成"],
            generatedParticles: ["助詞合成"],
            userPrefix: [],
            learnedCompletion: [],
            symbolPrefix: [],
            systemPrefix: [],
            basicPrefix: [],
            english: [],
            uppercase: [],
            recencyRanks: [:],
            secondaryRanks: [
                "活用生成": 3,
                "助詞合成": 2,
                "数字合成": 1
            ],
            contextualCandidates: [],
            prioritizeKana: false
        ))

        #expect(candidates.map(\.storageText) == [
            "完全一致", "活用生成", "助詞合成", "数字合成"
        ])
    }

    @Test
    func movesLearnedGeneratedCandidateAheadWithoutChangingItsOrigin() throws {
        let candidates = CandidateAssembly().candidates(from: .init(
            reading: "arimasu",
            kana: ["あります", "アリマス"],
            userExact: [],
            learnedExact: [],
            dateTime: [],
            numericPrefix: [],
            javaScript: [],
            symbolExact: [],
            basicExact: [],
            systemExact: ["アリマス"],
            inflection: ["あります"],
            particle: [],
            generatedParticles: [],
            userPrefix: [],
            learnedCompletion: [],
            symbolPrefix: [],
            systemPrefix: [],
            basicPrefix: [],
            english: [],
            uppercase: [],
            recencyRanks: ["あります": 1],
            secondaryRanks: ["あります": 1],
            contextualCandidates: [],
            prioritizeKana: false
        ))

        #expect(candidates.first?.storageText == "あります")
        #expect(candidates.first?.hasSource(.verbInflection) == true)
        #expect(candidates.first?.hasSource(.selectionHistory) == false)
    }
}
