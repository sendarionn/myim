import Testing
@testable import MyIMECore

@Suite
struct VerbInflectionCandidateGeneratorTests {
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

    @Test
    func createsTeFormCandidates() {
        #expect(generator.candidates(for: "utsutte") == ["移って", "写って"])
        #expect(generator.candidates(for: "yonde") == ["読んで"])
        #expect(generator.candidates(for: "kaite") == ["書いて"])
        #expect(generator.candidates(for: "itte") == ["行って"])
    }

    @Test
    func createsPastFormCandidates() {
        #expect(generator.candidates(for: "utsutta") == ["移った", "写った"])
        #expect(generator.candidates(for: "yonda") == ["読んだ"])
    }

    @Test
    func createsIchidanInflectionCandidates() {
        #expect(generator.candidates(for: "kangaete") == ["考えて"])
        #expect(generator.candidates(for: "kangaeta") == ["考えた"])
        #expect(generator.candidates(for: "tabenai") == ["食べない"])
        #expect(generator.candidates(for: "tabemasu") == ["食べます"])
    }

    @Test
    func createsGodanNegativeAndPoliteCandidates() {
        #expect(generator.candidates(for: "kakanai") == ["書かない"])
        #expect(generator.candidates(for: "kakimasu") == ["書きます"])
        #expect(generator.candidates(for: "hanasanai") == ["話さない"])
        #expect(generator.candidates(for: "hanashimasu") == ["話します"])
    }

    @Test
    func createsIrregularInflectionCandidates() {
        #expect(generator.candidates(for: "benkyoushite") == ["勉強して"])
        #expect(generator.candidates(for: "benkyoushinai") == ["勉強しない"])
        #expect(generator.candidates(for: "kite").contains("来て"))
        #expect(generator.candidates(for: "konai") == ["来ない"])
    }

    @Test
    func createsPotentialPassiveAndCausativeCandidates() {
        #expect(generator.candidates(for: "mirareru").contains("見られる"))
        #expect(generator.candidates(for: "kakeru").contains("書ける"))
        #expect(generator.candidates(for: "yomeru").contains("読める"))
        #expect(generator.candidates(for: "hanaseru").contains("話せる"))
        #expect(generator.candidates(for: "kawareru").contains("買われる"))
        #expect(generator.candidates(for: "kakaseru").contains("書かせる"))
    }
}
