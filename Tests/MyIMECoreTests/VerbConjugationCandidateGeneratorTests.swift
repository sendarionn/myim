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

    @Test(arguments: [
        ("yobarete", "呼ばれて"),
        ("yobaretemo", "呼ばれても"),
        ("yobarenai", "呼ばれない"),
        ("yobarenakatta", "呼ばれなかった"),
        ("yobaretara", "呼ばれたら"),
        ("yobareteiru", "呼ばれている"),
        ("yobareteinai", "呼ばれていない"),
        ("yobaseru", "呼ばせる"),
        ("yobasete", "呼ばせて"),
        ("yobasenai", "呼ばせない"),
        ("yobaseteiru", "呼ばせている"),
        ("yobaserareru", "呼ばせられる"),
        ("yobaserarete", "呼ばせられて"),
        ("yobaseraretemo", "呼ばせられても")
    ])
    func composesVoiceAndFollowingExpressions(
        input: String,
        expected: String
    ) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    @Test(arguments: [
        ("yondemo", "呼んでも"),
        ("yondara", "呼んだら"),
        ("yondari", "呼んだり"),
        ("yobanakereba", "呼ばなければ"),
        ("wakatteinai", "分かっていない"),
        ("wakatteita", "分かっていた"),
        ("wakatteitemo", "分かっていても")
    ])
    func composesBasicFormsAndFollowingExpressions(
        input: String,
        expected: String
    ) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    @Test(arguments: [
        ("miraretemo", "見られても"),
        ("misaseraretemo", "見させられても"),
        ("benkyousaseteiru", "勉強させている"),
        ("ninjirarete", "任じられて"),
        ("koraretemo", "来られても")
    ])
    func composesVoicesAcrossRegisteredVerbClasses(
        input: String,
        expected: String
    ) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    /// A passive or causative verb is re-conjugated as an ichidan verb,
    /// including the forms that do not end a sentence
    @Test(arguments: [
        ("yobare", "呼ばれ"),
        ("yobarereba", "呼ばれれば"),
        ("yobarenakereba", "呼ばれなければ"),
        ("yobarenakute", "呼ばれなくて"),
        ("yobaremasu", "呼ばれます"),
        ("yobaremashita", "呼ばれました"),
        ("yobaremasen", "呼ばれません"),
        ("yobaremasendeshita", "呼ばれませんでした"),
        ("yobaretari", "呼ばれたり"),
        ("yobareteitemo", "呼ばれていても"),
        ("yobarerunode", "呼ばれるので"),
        ("yobase", "呼ばせ"),
        ("yobasereba", "呼ばせれば"),
        ("yobasenakatta", "呼ばせなかった"),
        ("yobaseteoku", "呼ばせておく"),
        ("yobaserarereba", "呼ばせられれば"),
        ("taberarereba", "食べられれば"),
        ("benkyousaserarereba", "勉強させられれば"),
        ("korarenai", "来られない")
    ])
    func reconjugatesDerivedVerbs(input: String, expected: String) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    @Test(arguments: [
        ("yobasareru", "呼ばされる"),
        ("yobasareta", "呼ばされた"),
        ("yobasarenai", "呼ばされない"),
        ("yobasarereba", "呼ばされれば"),
        ("yobasaretara", "呼ばされたら"),
        ("kakasareta", "書かされた"),
        ("matasareta", "待たされた"),
        ("kawasareta", "買わされた"),
        ("ikasareta", "行かされた")
    ])
    func composesShortCausativePassiveOfGodanVerbs(
        input: String,
        expected: String
    ) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    @Test
    func shortCausativePassiveIsOnlyForGodanVerbsOutsideTheSuRow() {
        #expect(!generator.candidates(for: "hanasasareta").contains("話さされた"))
        #expect(generator.candidates(for: "hanasaserareta").contains("話させられた"))
        #expect(!generator.candidates(for: "tabesasareta").contains("食べさされた"))
        #expect(!generator.candidates(for: "benkyousasareta")
            .contains("勉強さされた"))
    }

    @Test(arguments: [
        ("yobeba", "呼べば"),
        ("kakeba", "書けば"),
        ("mateba", "待てば"),
        ("kaeba", "買えば"),
        ("ikeba", "行けば"),
        ("tabereba", "食べれば"),
        ("mireba", "見れば"),
        ("benkyousureba", "勉強すれば"),
        ("ninzureba", "任ずれば"),
        ("kureba", "来れば")
    ])
    func conjugatesConditionalFormOfEachClass(
        input: String,
        expected: String
    ) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    @Test(arguments: [
        ("yondeoku", "呼んでおく"),
        ("yondeoita", "呼んでおいた"),
        ("yondeshimau", "呼んでしまう"),
        ("yondeshimatta", "呼んでしまった"),
        ("yondemiru", "呼んでみる"),
        ("yondekara", "呼んでから"),
        ("kaiteoku", "書いておく"),
        ("tabeteshimatta", "食べてしまった"),
        ("ittemita", "行ってみた"),
        ("yobinagara", "呼びながら"),
        ("yobuna", "呼ぶな"),
        ("yobunode", "呼ぶので"),
        ("yobukeredo", "呼ぶけれど")
    ])
    func joinsAuxiliariesAndConjunctions(input: String, expected: String) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    @Test(arguments: [
        ("kakou", "書こう"),
        ("yobou", "呼ぼう"),
        ("matou", "待とう"),
        ("kaou", "買おう"),
        ("ikou", "行こう"),
        ("tabeyou", "食べよう"),
        ("miyou", "見よう"),
        ("benkyoushiyou", "勉強しよう"),
        ("ninjiyou", "任じよう"),
        ("koyou", "来よう"),
        ("yobareyou", "呼ばれよう"),
        ("ikouka", "行こうか")
    ])
    func conjugatesTheVolitionalOfEachClass(
        input: String,
        expected: String
    ) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    @Test(arguments: [
        ("benkyoushimashou", "勉強しましょう"),
        ("kakimasuka", "書きますか"),
        ("benkyousubeki", "勉強すべき"),
        ("taberubeki", "食べるべき"),
        ("benkyoushinakerebanaranai", "勉強しなければならない"),
        ("tabenakutemoii", "食べなくてもいい"),
        ("yondemoii", "読んでもいい"),
        ("yondehanaranai", "読んではならない"),
        ("kaitearu", "書いてある"),
        ("ikukamoshirenai", "行くかもしれない"),
        ("tabetakotogaaru", "食べたことがある")
    ])
    func joinsObligationPermissionAndExperience(
        input: String,
        expected: String
    ) {
        #expect(generator.candidates(for: input).contains(expected))
    }

    @Test
    func rareVerbsDoNotOfferTheVolitional() {
        let generator = VerbConjugationCandidateGenerator(
            dictionary: VerbConjugationDictionary(text: """
            dassu\t脱す\tgodan\t6329
            iku\t行く\tgodan-iku\t119
            """)
        )

        #expect(!generator.candidates(for: "dassou").contains("脱そう"))
        #expect(generator.candidates(for: "dasshita").contains("脱した"))
        #expect(generator.candidates(for: "ikou").contains("行こう"))
    }

    @Test
    func takesSuruVerbsFromDictionaryWordsWithSuru() {
        let generator = VerbConjugationCandidateGenerator(
            dictionary: VerbConjugationDictionary().addingSuruVerbs(from: [
                DictionaryEntry(reading: "kentousuru", candidates: ["検討する"]),
                DictionaryEntry(reading: "kentou", candidates: ["検討", "見当"]),
                DictionaryEntry(reading: "kouho", candidates: ["候補"])
            ])
        )

        #expect(generator.candidates(for: "kentoushiyou") == ["検討しよう"])
        #expect(generator.candidates(for: "kentoushiteiru") == ["検討している"])
        #expect(generator.candidates(for: "kouhoshiyou").isEmpty)
    }

    @Test
    func rejectsFormsTheVerbClassDoesNotHave() {
        // 書かれば and 食べられば join ば to the wrong form
        #expect(!generator.candidates(for: "kakareba").contains("書かれば"))
        #expect(!generator.candidates(for: "taberareba").contains("食べられば"))
        // 取る is godan, so 取れば rather than an ichidan 取れれば
        #expect(generator.candidates(for: "toreba").contains("取れば"))
        #expect(!generator.candidates(for: "torureba").contains("取るれば"))
        // Bare base forms are the dictionary's own words
        #expect(generator.candidates(for: "yobu").isEmpty)
        #expect(generator.candidates(for: "yobi").isEmpty)
    }

    @Test
    func derivedFormsStayFewAndUnique() {
        for input in [
            "yobare", "yobasareta", "yobaserarereba", "yobareteshimatta"
        ] {
            let candidates = generator.candidates(for: input)
            #expect(candidates.count == Set(candidates).count)
            #expect(candidates.count <= 2)
        }
    }

    @Test
    func compoundGenerationDoesNotDuplicateOrGuessUnknownVerbs() {
        let candidates = generator.candidates(for: "yobaseraretemo")

        #expect(candidates.count { $0 == "呼ばせられても" } == 1)
        #expect(generator.candidates(for: "dammyseraretemo").isEmpty)
        #expect(generator.candidates(
            for: String(repeating: "dammy", count: 40) + "seraretemo"
        ).isEmpty)
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
    func legacyRulesRequireRegisteredVerbClasses() {
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
        ).isEmpty)

        #expect(VerbInflectionCandidateGenerator.candidates(
            for: "nerareru",
            conjugations: conjugations,
            lookup: lookup
        ).isEmpty)
    }

    @Test
    func dictionaryRejectsUnregisteredVerbs() {
        let conjugations = VerbConjugationDictionary(text: """
        kiru\t着る\tichidan\t3000
        """)

        #expect(conjugations.allows(
            reading: "kiru",
            surface: "着る",
            classes: [.ichidan]
        ))
        #expect(!conjugations.allows(
            reading: "neru",
            surface: "寝る",
            classes: [.ichidan]
        ))
    }
}
