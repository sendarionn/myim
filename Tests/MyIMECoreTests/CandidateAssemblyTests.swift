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

    @Test
    func keepsEveryExactCandidateAheadOfGeneratedCandidates() throws {
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
            recencyRanks: [
                "数字合成": 100,
                "活用生成": 99,
                "助詞合成": 98
            ],
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
}
