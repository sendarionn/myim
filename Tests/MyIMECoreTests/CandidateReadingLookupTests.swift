import Foundation
import Testing
@testable import MyIMECore

@Suite
struct CandidateReadingLookupTests {
    @Test
    func combinesReadingsFromAllDictionarySourcesWithoutDuplicates() async {
        let user = ConversionEngine(entries: [
            DictionaryEntry(reading: "kouho", candidates: ["候補"])
        ])
        let basic = ConversionEngine(entries: [
            DictionaryEntry(reading: "こうほ", candidates: ["候補"])
        ])
        let indexed = IndexedDictionaryEngine(data: Data(
            "kouho\t候補\nsentaku\t選択\n".utf8
        ))

        let readings = await CandidateReadingLookup.resolve(
            candidate: "候補",
            userEngine: user,
            basicEngine: basic,
            indexedEngine: indexed
        )

        #expect(readings == ["kouho", "こうほ"])
    }
}
