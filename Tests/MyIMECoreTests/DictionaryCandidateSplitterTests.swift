import Testing
@testable import MyIMECore

@Suite
struct DictionaryCandidateSplitterTests {
    @Test func splitsAlternativeSpellings() {
        #expect(DictionaryCandidateSplitter.alternatives(from: "速い／早い") == ["速い", "早い"])
        #expect(DictionaryCandidateSplitter.alternatives(from: "×/バツ") == ["×", "バツ"])
    }

    @Test func keepsStandaloneSlash() {
        #expect(DictionaryCandidateSplitter.alternatives(from: "／") == ["／"])
    }
}
