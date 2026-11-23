import Testing
@testable import MyIMECore

@Suite
struct SKKDictionaryParserTests {
    @Test
    func parsesOkuriNasiEntriesAndRemovesAnnotations() throws {
        let result = SKKDictionaryParser().parse("""
        ;; okuri-nasi entries.
        かんじ /漢字;annotation/感じ/
        じしょ /辞書/
        """)

        #expect(result.entries == [
            DictionaryEntry(reading: "かんじ", candidates: ["漢字", "感じ"]),
            DictionaryEntry(reading: "じしょ", candidates: ["辞書"])
        ])
        #expect(result.skippedEntryCount == 0)
    }

    @Test
    func decodesEscapedSlashAndSemicolon() throws {
        let result = SKKDictionaryParser().parse(
            #"きごう /A\057B/C\;D;annotation/"#
        )

        #expect(result.entries.first?.candidates == ["A/B", "C;D"])
    }

    @Test
    func skipsOkuriAriAndExecutableCandidates() {
        let result = SKKDictionaryParser().parse("""
        かk /書/
        きょう /今日/(concat "危険")/
        """)

        #expect(result.entries == [
            DictionaryEntry(reading: "きょう", candidates: ["今日"])
        ])
        #expect(result.skippedEntryCount == 1)
    }

    @Test
    func importedKanaReadingCanBeFoundFromRomaji() {
        let engine = ConversionEngine(entries: [
            DictionaryEntry(reading: "かんじ", candidates: ["漢字"])
        ])

        #expect(engine.candidates(for: "kanji") == ["漢字"])
    }

    @Test
    func acceptsRomanReadingThatIsNotAnOkuriMarker() {
        let result = SKKDictionaryParser().parse("word /単語/")

        #expect(result.entries == [
            DictionaryEntry(reading: "word", candidates: ["単語"])
        ])
    }
}
