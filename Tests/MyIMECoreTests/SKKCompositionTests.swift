import Foundation
import Testing
@testable import MyIMECore

@Suite
struct SKKCompositionTests {
    /// Keys as typed, a capital standing for one typed with Shift
    private func composition(_ keys: String) -> SKKComposition {
        var composition = SKKComposition(firstLetter: keys.first!)
        for key in keys.dropFirst() {
            composition.type(key)
        }
        return composition
    }

    @Test
    func theSecondCapitalStartsTheOkurigana() throws {
        let kaku = composition("KaKu")
        #expect(kaku.romaji == "kaku")
        #expect(kaku.parts == ("ka", "ku"))
        #expect(try #require(kaku.reading()) == .init(stem: "か", okurigana: "く", okuriAriKey: "かk"))
        let taberu = composition("TaBeru")
        #expect(taberu.parts == ("ta", "beru"))
        #expect(try #require(taberu.reading()).okuriAriKey == "たb")
        #expect(composition("Kanji").okuriganaStart == nil)
    }

    /// Capitals typed together at the start are the stem; the first capital
    /// after a lowercase letter starts the okurigana
    @Test
    func capitalsAtTheStartAreTheStem() throws {
        for keys in ["TorituKe", "TORituKe", "ToritsuKe", "TORitsuKe"] {
            let keys = composition(keys)
            #expect(try #require(keys.reading()).okuriAriKey == "とりつk")
            #expect(try #require(keys.reading()).okurigana == "け")
        }
        #expect(composition("TORituKe").typed == "TORituKe")
        #expect(composition("TAB").okuriganaStart == nil)
        #expect(composition("SKK").okuriganaStart == nil)
        #expect(composition("TaBeru").okuriganaStart == 2)
    }

    @Test
    func deletingIntoTheStemForgetsTheOkurigana() {
        var kaku = composition("KaKu")
        kaku.shorten(to: 3)
        #expect(kaku.okuriganaStart == 2)
        kaku.shorten(to: 2)
        #expect(kaku.okuriganaStart == nil)
        #expect(kaku.typed == "Ka")
    }

    /// Okurigana marked say what is meant: the okuri-ari entries come first
    /// in the dictionary's order, then the ordinary candidates that convert
    /// the stem and end in the okurigana; the reading as a whole is not
    /// offered
    @Test
    func okuriAriEntriesComeBeforeTheOrdinaryCandidates() {
        let kaku = composition("KaKu")
        let standard = ["角", "書く", "かく", "描く", "格"].map {
            Candidate(storageText: $0, source: .systemDictionary, reading: "kaku")
        }
        let candidates = SKKCandidateComposer.candidates(
            input: "kaku",
            composition: kaku,
            standard: standard,
            okuriAri: { $0 == "かk" ? ["書", "欠"] : [] }
        ).map(\.storageText)
        #expect(candidates == ["書く", "欠く", "描く", "かく", "KaKu"])
    }

    /// 取り付け ranked first by ordinary conversion or learning still
    /// follows the entries for とりつk, in their order either way
    @Test
    func theOkuriAriOrderWinsOverTheOrdinaryRanking() throws {
        let toritsuke = composition("ToritsuKe")
        #expect(try #require(toritsuke.reading()).okuriAriKey == "とりつk")
        let standard = ["取り付け", "取付け", "鳥付け", "取付"].map {
            Candidate(storageText: $0, source: .systemDictionary, reading: "toritsuke")
        }
        func candidates(_ entries: [String]) -> [String] {
            SKKCandidateComposer.candidates(
                input: "toritsuke",
                composition: toritsuke,
                standard: standard,
                okuriAri: { $0 == "とりつk" ? entries : [] }
            ).map(\.storageText)
        }
        #expect(candidates(["取付", "取り付"])
            == ["取付け", "取り付け", "鳥付け", "とりつけ", "ToritsuKe"])
        #expect(candidates(["取り付", "取付"])
            == ["取り付け", "取付け", "鳥付け", "とりつけ", "ToritsuKe"])
        // Without okurigana marked the ordinary order stays
        #expect(SKKCandidateComposer.candidates(
            input: "toritsuke",
            composition: composition("Toritsuke"),
            standard: standard,
            okuriAri: { _ in ["取付"] }
        ).map(\.storageText) == ["取り付け", "取付け", "鳥付け", "取付", "Toritsuke"])
    }

    /// Capitals alone mark no okurigana, so the ordinary candidates of the
    /// reading are offered and the keys as typed close them
    @Test
    func capitalsAloneKeepTheirCase() {
        let skk = composition("SKK")
        #expect(skk.typed == "SKK")
        #expect(skk.romaji == "skk")
        #expect(SKKCandidateComposer.candidates(
            input: "skk", composition: skk, standard: [], okuriAri: { _ in [] }
        ).map(\.storageText) == ["SKK"])
    }

    @Test
    func incompleteOkuriganaOfferNothingYet() {
        #expect(SKKCandidateComposer.candidates(
            input: "kak", composition: composition("KaK"), standard: [], okuriAri: { _ in ["書"] }
        ).isEmpty)
    }

    @Test
    func withoutOkuriganaTheOrdinaryCandidatesStay() {
        let standard = [Candidate(storageText: "スウィフト", source: .systemDictionary)]
        let candidates = SKKCandidateComposer.candidates(
            input: "swift", composition: composition("Swift"), standard: standard, okuriAri: { _ in [] }
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

    @Test
    func skkModeIsOffUntilTurnedOn() {
        let defaults = UserDefaults(suiteName: "SKKCompositionTests")!
        defaults.removePersistentDomain(forName: "SKKCompositionTests")
        defer { defaults.removePersistentDomain(forName: "SKKCompositionTests") }
        let settings = InputFeatureSettings(defaults: defaults)
        #expect(!settings.isSKKModeEnabled)
        #expect(settings.isLiveConversionEnabled)
    }
}
