import Foundation
import Testing
@testable import MyIMECore

@Suite
struct SKKCompositionTests {
    /// Keys as typed, a capital standing for one typed with Shift
    private func composition(_ keys: String) -> SKKComposition {
        var composition = SKKComposition(firstLetter: keys.first!)
        for key in keys.dropFirst() {
            composition.type(key, marksOkurigana: key.isUppercase)
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

    @Test
    func deletingIntoTheStemForgetsTheOkurigana() {
        var kaku = composition("KaKu")
        kaku.shorten(to: 3)
        #expect(kaku.okuriganaStart == 2)
        kaku.shorten(to: 2)
        #expect(kaku.okuriganaStart == nil)
        #expect(kaku.typed == "Ka")
    }

    /// The ordinary candidates that convert the stem and end in the
    /// okurigana, then the okuri-ari entries; the reading as a whole is
    /// not offered
    @Test
    func okuriganaFollowTheConvertedStem() {
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
        #expect(candidates == ["書く", "描く", "欠く", "かく", "KaKu"])
    }

    /// Keys that read as no kana offer nothing to commit in their place,
    /// and keep their capitals to be committed as typed
    @Test
    func keysThatReadAsNoKanaKeepTheirCapitals() {
        let skk = composition("SKK")
        #expect(skk.typed == "SKK")
        #expect(skk.romaji == "skk")
        #expect(skk.reading() == nil)
        #expect(SKKCandidateComposer.candidates(
            input: "skk", composition: skk, standard: [], okuriAri: { _ in [] }
        ).isEmpty)
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
