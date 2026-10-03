import Testing
@testable import MyIMECore

@Suite
struct VerbConjugationCandidateGeneratorTests {
    private let generator = VerbConjugationCandidateGenerator(
        dictionary: VerbConjugationDictionary(text: """
        kaku\t書く\tgodan\t3000
        oyogu\t泳ぐ\tgodan\t3000
        hanasu\t話す\tgodan\t3000
        matsu\t待つ\tgodan\t3000
        yomu\t読む\tgodan\t2126
        yobu\t呼ぶ\tgodan\t2756
        asobu\t遊ぶ\tgodan\t3000
        shinu\t死ぬ\tgodan\t3000
        toru\t取る\tgodan\t3000
        kau\t買う\tgodan\t3000
        shiru\t知る\tgodan\t3000
        shiru\tしる\tgodan\t1000
        wakaru\t分かる\tgodan\t2420
        iku\t行く\tgodan-iku\t119
        taberu\t食べる\tichidan\t3000
        miru\t見る\tichidan\t3000
        kiru\t着る\tichidan\t3000
        kiru\t切る\tgodan\t3500
        kaeru\t変える\tichidan\t3000
        kaeru\t帰る\tgodan\t3000
        benkyousuru\t勉強する\tsuru\t3000
        ninzuru\t任ずる\tzuru\t3000
        kuru\t来る\tkuru\t3000
        """)
    )

    @Test(arguments: [
        ("wakatteiru", "分かっている"),
        ("shiritai", "知りたい"),
        ("tabeteiru", "食べている"),
        ("yondeiru", "読んでいる"),
        ("hanashitai", "話したい"),
        ("wakaranai", "分からない"),
        ("shitteiru", "知っている")
    ])
    func conjugatesEverydayVerbs(input: String, expected: String) {
        #expect(generator.candidates(for: input).first == expected)
    }

    @Test(arguments: [
        ("shiritakunai", "知りたくない"),
        ("shiritakunakatta", "知りたくなかった"),
        ("shiritakatta", "知りたかった"),
        ("shiritakute", "知りたくて"),
        ("shiritakereba", "知りたければ"),
        ("shiritakunaru", "知りたくなる"),
        ("shiritakunatta", "知りたくなった"),
        ("shiritakunaranai", "知りたくならない")
    ])
    func conjugatesDesireExpressions(input: String, expected: String) {
        #expect(generator.candidates(for: input).first == expected)
    }

    @Test(arguments: [
        ("mitakunai", "見たくない"),
        ("mitakatta", "見たかった"),
        ("mitakunatta", "見たくなった"),
        ("kakitakunai", "書きたくない"),
        ("yomitakatta", "読みたかった"),
        ("ikitakunatta", "行きたくなった"),
        ("tabetakatta", "食べたかった"),
        ("benkyoushitakunai", "勉強したくない")
    ])
    func appliesDesireExpressionsToVerbClasses(
        input: String,
        expected: String
    ) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    @Test(arguments: [
        ("kaiteiru", "書いている"),
        ("kakitai", "書きたい"),
        ("kakanai", "書かない"),
        ("kaita", "書いた"),
        ("oyoideiru", "泳いでいる"),
        ("matteita", "待っていた"),
        ("asondeinai", "遊んでいない"),
        ("shindeiru", "死んでいる"),
        ("totteiru", "取っている"),
        ("kawanakatta", "買わなかった"),
        ("katteimasu", "買っています"),
        ("itteiru", "行っている"),
        ("tabenai", "食べない"),
        ("mitai", "見たい"),
        ("benkyoushiteiru", "勉強している"),
        ("benkyoushitai", "勉強したい"),
        ("ninjite", "任じて"),
        ("kiteiru", "来ている"),
        ("konai", "来ない")
    ])
    func followsEachConjugationClass(input: String, expected: String) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    @Test
    func usesTheDictionaryClassToChooseBetweenSameReadings() {
        #expect(!generator.candidates(for: "kiteiru").contains("切ている"))
        #expect(generator.candidates(for: "kitteiru") == ["切っている"])
        #expect(generator.candidates(for: "kaeranai") == ["帰らない"])
        #expect(generator.candidates(for: "kaenai") == ["変えない"])
    }

    @Test
    func doesNotTreatWordsEndingInAuxiliariesAsVerbs() {
        #expect(generator.candidates(for: "pantai").isEmpty)
        #expect(generator.candidates(for: "tantai").isEmpty)
        #expect(generator.candidates(for: "sanai").isEmpty)
        #expect(generator.candidates(for: "pantakunai").isEmpty)
        #expect(generator.candidates(for: "tantakunatta").isEmpty)
        #expect(Set(generator.candidates(for: "kita")) == ["来た", "着た"])
    }

    @Test
    func ordersByCostAndLeavesKanaVerbsToAutomaticKana() {
        #expect(generator.candidates(for: "yondeiru") == ["読んでいる", "呼んでいる"])
        #expect(generator.candidates(for: "yobanai") == ["呼ばない"])
        #expect(!generator.candidates(for: "shitteiru").contains("しっている"))
    }

    @Test
    func legacyRulesFollowKnownVerbClasses() {
        let conjugations = VerbConjugationDictionary(text: """
        kiru\t着る\tichidan\t3000
        kiru\t切る\tgodan\t3500
        saru\t去る\tgodan\t3000
        """)
        let lookup: (String) -> [String] = { reading in
            ["kiru": ["着る", "切る"], "saru": ["去る"], "neru": ["寝る"]][
                reading
            ] ?? []
        }

        #expect(VerbInflectionCandidateGenerator.candidates(
            for: "kite",
            conjugations: conjugations,
            lookup: lookup
        ) == ["着て"])
        #expect(VerbInflectionCandidateGenerator.candidates(
            for: "kitta",
            conjugations: conjugations,
            lookup: lookup
        ) == ["切った"])
        #expect(VerbInflectionCandidateGenerator.candidates(
            for: "satai",
            conjugations: conjugations,
            lookup: lookup
        ).isEmpty)
        #expect(VerbInflectionCandidateGenerator.candidates(
            for: "netai",
            conjugations: conjugations,
            lookup: lookup
        ) == ["寝たい"])
    }
}
