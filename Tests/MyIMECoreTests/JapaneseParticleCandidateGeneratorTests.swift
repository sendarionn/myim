import Testing
@testable import MyIMECore

@Suite
struct JapaneseParticleCandidateGeneratorTests {
    private let dictionary = [
        "kouho": ["候補"],
        "shitei": ["指定"],
        "sentaku": ["選択"],
        "baai": ["場合"],
        "kekka": ["結果"],
        "houhou": ["方法"],
        "kanousei": ["可能性"],
        "riyuu": ["理由"],
        "keesu": ["ケース"],
        "gazoufairu": ["画像ファイル"],
        "shirizoku": ["退く"],
        "eibun": ["ABC"],
        "kigou": ["データ・ベース"],
        "gakusei": ["学生"],
        "benri": ["便利"],
        "kirei": ["綺麗", "きれい"],
        "utsukushii": ["美しい"],
        "iku": ["行く"],
        "taberu": ["食べる"]
    ]

    @Test(arguments: [
        ("kouhodesu", ["候補です"]),
        ("gakuseideshita", ["学生でした"]),
        ("benridesu", ["便利です"]),
        ("utsukushiidesu", ["美しいです"]),
        ("kireidesu", ["綺麗です"])
    ])
    func joinsTheCopulaToNounsAndAdjectives(
        input: String,
        expected: [String]
    ) {
        #expect(candidates(for: input) == expected)
    }

    @Test(arguments: [
        "ikudesu", "taberudeshita", "utsukushiideshita", "desu", "kouhodes"
    ])
    func doesNotJoinTheCopulaToVerbsOrMissingWords(_ input: String) {
        #expect(candidates(for: input).isEmpty)
    }

    @Test
    func keepsTrailingParticleInHiragana() {
        #expect(candidates(for: "kouhowo") == ["候補を"])
    }

    @Test
    func doesNotGenerateLeadingParticleCandidate() {
        #expect(candidates(for: "hakouho").isEmpty)
    }

    @Test(arguments: [
        ("nobaai", "の場合"),
        ("nokekka", "の結果"),
        ("nohouhou", "の方法"),
        ("nokanousei", "の可能性"),
        ("noriyuu", "の理由")
    ])
    func generatesLeadingNoBeforeNounLikeCandidates(
        input: String,
        expected: String
    ) {
        #expect(candidates(for: input) == [expected])
    }

    @Test
    func nounLikeApproximationAcceptsKatakanaAndMixedScripts() {
        #expect(candidates(for: "nokeesu") == ["のケース"])
        #expect(candidates(for: "nogazoufairu") == ["の画像ファイル"])
    }

    @Test
    func doesNotGenerateOtherLeadingParticles() {
        #expect(candidates(for: "hakouho").isEmpty)
        #expect(candidates(for: "gakouho").isEmpty)
        #expect(candidates(for: "nekouho").isEmpty)
        #expect(candidates(for: "yokouho").isEmpty)
        #expect(candidates(for: "nodekouho").isEmpty)
        #expect(candidates(for: "nonikouho").isEmpty)
    }

    @Test
    func leadingNoRequiresAnExactNounLikeCandidate() {
        #expect(candidates(for: "nomityakuwp").isEmpty)
        #expect(candidates(for: "noshirizoku").isEmpty)
        #expect(candidates(for: "noeibun").isEmpty)
        #expect(candidates(for: "nokigou").isEmpty)
    }

    @Test
    func doesNotSplitLeadingNoInsideInput() {
        #expect(candidates(for: "kouhonobaai").isEmpty)
    }

    @Test
    func supportsCompoundParticles() {
        #expect(candidates(for: "kouhonite") == ["候補にて"])
        #expect(candidates(for: "kouhonotame") == ["候補のため"])
        #expect(candidates(for: "kouhonitsuki") == ["候補につき"])
        #expect(candidates(for: "kouhoniyotte") == ["候補によって"])
        #expect(candidates(for: "kouhonikanshite") == ["候補に関して"])
    }

    @Test
    func doesNotSplitParticleInsideInput() {
        #expect(candidates(for: "kouhowosentaku").isEmpty)
    }

    @Test
    func requiresAnExactDictionaryStem() {
        #expect(candidates(for: "mityakuwp").isEmpty)
    }

    @Test
    func doesNotTreatVerbTeFormAsASimpleParticle() {
        #expect(!candidates(for: "shiteite").contains("指定て"))
    }

    @Test
    func identifiesCandidatesThatExistOnlyAsParticleCompositions() {
        #expect(
            JapaneseParticleCandidateGenerator.generatedOnlyCandidates(
                generated: ["候補を", "候補につき"],
                exactDictionaryCandidates: ["候補を"]
            ) == ["候補につき"]
        )
    }

    @Test
    func selectedCompositionCanBecomeAnExactUserDictionaryCandidate() throws {
        let candidate = try #require(candidates(for: "kouhowo").first)
        let entries = UserDictionaryEditor.adding(
            reading: "kouhowo",
            candidate: candidate,
            to: []
        )

        #expect(
            ConversionEngine(entries: entries).candidates(for: "kouhowo")
                == ["候補を"]
        )
        #expect(
            JapaneseParticleCandidateGenerator.generatedOnlyCandidates(
                generated: [candidate],
                exactDictionaryCandidates: [candidate]
            ).isEmpty
        )
    }

    private func candidates(for input: String) -> [String] {
        JapaneseParticleCandidateGenerator.candidates(for: input) {
            dictionary[$0] ?? []
        }
    }
}
