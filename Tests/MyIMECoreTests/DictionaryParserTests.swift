import Testing
@testable import MyIMECore

struct DictionaryParserTests {
    @Test
    func parsesEntriesAndCandidates() throws {
        let text = """
        miru
         見る
         診る
         観る

        ikiru
         生きる
         活きる
        """

        let entries = try DictionaryParser().parse(text)

        #expect(entries == [
            DictionaryEntry(reading: "miru", candidates: ["見る", "診る", "観る"]),
            DictionaryEntry(reading: "ikiru", candidates: ["生きる", "活きる"])
        ])
    }

    @Test
    func mergesDuplicateReadingsAndCandidates() throws {
        let text = """
        miru
         見る
         診る
        miru
         見る
         観る
        """

        let entries = try DictionaryParser().parse(text)

        #expect(entries == [
            DictionaryEntry(reading: "miru", candidates: ["見る", "診る", "観る"])
        ])
    }

    @Test
    func rejectsCandidateWithoutReading() {
        #expect(throws: DictionaryParserError.candidateWithoutReading(line: 1)) {
            try DictionaryParser().parse(" 見る")
        }
    }

    @Test
    func rejectsReadingWithoutCandidates() {
        #expect(
            throws: DictionaryParserError.readingWithoutCandidates(
                reading: "miru",
                line: 1
            )
        ) {
            try DictionaryParser().parse("miru")
        }
    }
}
