import Testing
@testable import MyIMECore

@Suite
struct VerbInflectionCandidateGeneratorTests {
    private let generator = VerbInflectionCandidateGenerator(entries: [
        DictionaryEntry(reading: "utsuru", candidates: ["移る", "写る"]),
        DictionaryEntry(reading: "yomu", candidates: ["読む"]),
        DictionaryEntry(reading: "kaku", candidates: ["書く"]),
        DictionaryEntry(reading: "iku", candidates: ["行く"])
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
}
