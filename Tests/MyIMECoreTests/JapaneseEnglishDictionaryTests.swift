import Testing
@testable import MyIMECore

@Suite
struct JapaneseEnglishDictionaryTests {
    private let dictionary = JapaneseEnglishDictionary(text: """
    ringo\tapple
    yomu\tread
    hashi\tchopsticks
    hashi\tbridge
    tsukau\tuse
    """)

    @Test
    func wordsAreFoundByTheReadingTyped() {
        #expect(dictionary.words(for: "ringo") == ["apple"])
        #expect(dictionary.words(for: "hashi") == ["chopsticks", "bridge"])
        // Spelled another way, the reading is the same
        #expect(dictionary.words(for: "tukau") == ["use"])
        #expect(dictionary.words(for: "rin").isEmpty)
    }

    /// The English words follow the Japanese that reads as typed and come
    /// before the English completions
    @Test
    func englishWordsFollowTheJapaneseCandidates() {
        let candidates = CandidateAssembly().candidates(from: .init(
            reading: "ringo",
            kana: ["りんご", "リンゴ"],
            userExact: [],
            learnedExact: [],
            dateTime: [],
            numericPrefix: [],
            javaScript: [],
            symbolExact: [],
            basicExact: [],
            systemExact: ["林檎"],
            inflection: [],
            particle: [],
            generatedParticles: [],
            userPrefix: [],
            learnedCompletion: [],
            symbolPrefix: [],
            systemPrefix: ["林檎酒"],
            basicPrefix: [],
            english: ["ringo"],
            japaneseEnglish: ["apple"],
            uppercase: [],
            recencyRanks: [:],
            contextualCandidates: [],
            prioritizeKana: false
        ))
        let texts = candidates.map(\.storageText)
        #expect(texts.firstIndex(of: "apple")! > texts.firstIndex(of: "林檎")!)
        #expect(texts.firstIndex(of: "apple")! < texts.firstIndex(of: "ringo")!)
        #expect(texts.firstIndex(of: "apple")! < texts.firstIndex(of: "林檎酒")!)
        #expect(candidates.first { $0.storageText == "apple" }?.primarySource == .japaneseEnglishDictionary)
    }
}
