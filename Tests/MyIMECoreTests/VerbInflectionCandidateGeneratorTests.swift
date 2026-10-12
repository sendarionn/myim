import Testing
@testable import MyIMECore

@Suite
struct VerbInflectionCandidateGeneratorTests {
    @Test
    func createsTypoSearchEntryForTeForm() {
        let conjugations = VerbConjugationDictionary(text: """
        susumeru\t進める\tichidan\t3000
        susumeru\t勧める\tichidan\t3000
        """)
        let entries = VerbInflectionCandidateGenerator.typoSearchEntries(
            from: [
                DictionaryEntry(
                    reading: "susumeru",
                    candidates: ["進める", "勧める"]
                )
            ],
            conjugations: conjugations
        )

        #expect(entries.contains {
            $0.reading == "susumete"
                && $0.candidates == ["進めて", "勧めて"]
        })
        let engine = FuzzyConversionEngine(entries: entries)
        #expect(engine.matches(for: "susmete").first?.candidates == [
            "進めて", "勧めて"
        ])
    }

    private let generator = VerbInflectionCandidateGenerator(entries: [
        DictionaryEntry(reading: "utsuru", candidates: ["移る", "写る"]),
        DictionaryEntry(reading: "yomu", candidates: ["読む"]),
        DictionaryEntry(reading: "kaku", candidates: ["書く"]),
        DictionaryEntry(reading: "iku", candidates: ["行く"]),
        DictionaryEntry(reading: "kangaeru", candidates: ["考える"]),
        DictionaryEntry(reading: "taberu", candidates: ["食べる"]),
        DictionaryEntry(reading: "hanasu", candidates: ["話す"]),
        DictionaryEntry(reading: "benkyousuru", candidates: ["勉強する"]),
        DictionaryEntry(reading: "kuru", candidates: ["来る"]),
        DictionaryEntry(reading: "miru", candidates: ["見る"]),
        DictionaryEntry(reading: "kau", candidates: ["買う"])
    ])

    private let conjugations = VerbConjugationDictionary(text: """
    utsuru\t移る\tgodan\t3000
    utsuru\t写る\tgodan\t3000
    yomu\t読む\tgodan\t3000
    kaku\t書く\tgodan\t3000
    iku\t行く\tgodan-iku\t3000
    kangaeru\t考える\tichidan\t3000
    taberu\t食べる\tichidan\t3000
    hanasu\t話す\tgodan\t3000
    benkyousuru\t勉強する\tsuru\t3000
    kuru\t来る\tkuru\t3000
    miru\t見る\tichidan\t3000
    kau\t買う\tgodan\t3000
    """)

    private func candidates(_ reading: String) -> [String] {
        generator.candidates(for: reading, conjugations: conjugations)
    }

    @Test
    func createsTeFormCandidates() {
        #expect(candidates("utsutte") == ["移って", "写って"])
        #expect(candidates("yonde") == ["読んで"])
        #expect(candidates("kaite") == ["書いて"])
        #expect(candidates("itte") == ["行って"])
    }

    @Test
    func createsPastFormCandidates() {
        #expect(candidates("utsutta") == ["移った", "写った"])
        #expect(candidates("yonda") == ["読んだ"])
    }

    @Test
    func createsIchidanInflectionCandidates() {
        #expect(candidates("kangaete") == ["考えて"])
        #expect(candidates("kangaeta") == ["考えた"])
        #expect(candidates("tabenai") == ["食べない"])
        #expect(candidates("tabemasu") == ["食べます"])
    }

    @Test
    func createsGodanNegativeAndPoliteCandidates() {
        #expect(candidates("kakanai") == ["書かない"])
        #expect(candidates("kakimasu") == ["書きます"])
        #expect(candidates("hanasanai") == ["話さない"])
        #expect(candidates("hanashimasu") == ["話します"])
    }

    @Test
    func createsIrregularInflectionCandidates() {
        #expect(candidates("benkyoushite") == ["勉強して"])
        #expect(candidates("benkyoushinai") == ["勉強しない"])
        #expect(candidates("kite").contains("来て"))
        #expect(candidates("konai") == ["来ない"])
    }

    @Test
    func createsPotentialPassiveAndCausativeCandidates() {
        #expect(candidates("mirareru").contains("見られる"))
        #expect(candidates("kakeru").contains("書ける"))
        #expect(candidates("yomeru").contains("読める"))
        #expect(candidates("hanaseru").contains("話せる"))
        #expect(candidates("kawareru").contains("買われる"))
        #expect(candidates("kakaseru").contains("書かせる"))
    }

    @Test
    func rejectsUnregisteredBaseForms() {
        let generator = VerbInflectionCandidateGenerator(entries: [
            DictionaryEntry(reading: "neru", candidates: ["寝る"])
        ])

        #expect(generator.candidates(
            for: "netai",
            conjugations: conjugations
        ).isEmpty)
        #expect(generator.candidates(
            for: "nerareru",
            conjugations: conjugations
        ).isEmpty)
    }

    @Test
    func excludesUnregisteredBaseFormsFromTypoSearch() {
        let entries = VerbInflectionCandidateGenerator.typoSearchEntries(
            from: [
                DictionaryEntry(reading: "neru", candidates: ["寝る"])
            ],
            conjugations: conjugations
        )

        #expect(entries.isEmpty)
    }
}
