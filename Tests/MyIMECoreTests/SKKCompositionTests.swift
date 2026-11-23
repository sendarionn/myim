import Testing
@testable import MyIMECore

@Suite
struct SKKCompositionTests {
    private func composition(_ keys: String) -> (String, SKKComposition) {
        var input = ""
        var composition = SKKComposition(firstLetter: keys.first!)
        input.append(keys.first!.lowercased())
        for key in keys.dropFirst() {
            composition.type(key, at: input.count)
            input.append(key.lowercased())
        }
        return (input, composition)
    }

    @Test
    func theSecondCapitalStartsTheOkurigana() {
        let (input, kaku) = composition("KaKu")
        #expect(input == "kaku")
        #expect(kaku.parts(of: input) == ("ka", "ku"))
        let (taberu, tabe) = composition("TaBeru")
        #expect(tabe.parts(of: taberu) == ("ta", "beru"))
    }

    @Test
    func deletingIntoTheStemForgetsTheOkurigana() {
        var (_, kaku) = composition("KaKu")
        kaku.shortened(to: 2)
        #expect(kaku.okuriganaStart == nil)
        #expect(kaku.typed == "Ka")
    }

    /// The okuri-ari entry and the ordinary candidates that convert the
    /// stem and end in the okurigana; the reading as a whole is not offered
    @Test
    func okuriganaFollowTheConvertedStem() {
        let (input, kaku) = composition("KaKu")
        let standard = ["角", "書く", "かく", "描く", "格"].map {
            Candidate(storageText: $0, source: .systemDictionary, reading: input)
        }
        let candidates = SKKCandidateComposer.candidates(
            input: input,
            composition: kaku,
            standard: standard,
            okuriAri: { $0 == "かk" ? ["書", "欠"] : [] }
        ).map(\.storageText)
        #expect(candidates == ["書く", "欠く", "描く", "かく", "KaKu"])
    }

    @Test
    func incompleteOkuriganaOfferNothingYet() {
        let (input, kak) = composition("KaK")
        #expect(SKKCandidateComposer.candidates(
            input: input, composition: kak, standard: [], okuriAri: { _ in ["書"] }
        ).isEmpty)
    }

    @Test
    func withoutOkuriganaTheOrdinaryCandidatesStay() {
        let (input, swift) = composition("Swift")
        let standard = [Candidate(storageText: "スウィフト", source: .systemDictionary)]
        let candidates = SKKCandidateComposer.candidates(
            input: input, composition: swift, standard: standard, okuriAri: { _ in [] }
        ).map(\.storageText)
        #expect(candidates == ["スウィフト", "Swift"])
    }

    @Test
    func okuriAriEntriesAreKeptApart() {
        let result = SKKDictionaryParser().parse("""
        かk /書/描/
        かんじ /漢字/
        """)
        #expect(result.entries.map(\.reading) == ["かんじ"])
        #expect(result.okuriAriEntries == [DictionaryEntry(reading: "かk", candidates: ["書", "描"])])
    }
}
