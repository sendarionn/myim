import Foundation
import Testing
@testable import MyIMECore

@Suite
struct IndexedDictionaryEngineTests {
    private let engine = IndexedDictionaryEngine(
        data: Data(
            """
            あ
             亜
             あ

            あい
             愛
             藍

            い
             胃
            """.utf8
        )
    )

    @Test
    func returnsExactCandidates() {
        #expect(engine.candidates(for: "あ") == ["亜", "あ"])
    }

    @Test
    func returnsPrefixCandidatesInDictionaryOrder() {
        #expect(
            engine.candidates(matching: "あ")
                == ["亜", "あ", "愛", "藍"]
        )
    }

    @Test
    func separatesExactAndPrefixCandidatesInOneLookup() {
        #expect(
            engine.candidateGroups(matching: "あ")
                == DictionaryCandidateGroups(
                    exact: ["亜", "あ"],
                    prefix: ["愛", "藍"]
                )
        )
    }

    @Test
    func limitsPrefixCandidates() {
        #expect(engine.candidates(matching: "あ", limit: 3) == ["亜", "あ", "愛"])
    }

    @Test
    func reportsReadingCount() {
        #expect(engine.readingCount == 3)
    }

    @Test
    func findsReadingsForCandidate() {
        #expect(engine.readings(for: "愛") == ["あい"])
        #expect(engine.readings(for: "未登録").isEmpty)
    }
}
