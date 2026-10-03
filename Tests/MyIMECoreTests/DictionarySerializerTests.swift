import Testing
@testable import MyIMECore

@Suite
struct DictionarySerializerTests {
    @Test
    func serializesEntries() {
        #expect(
            DictionarySerializer.text(from: [
                DictionaryEntry(reading: "hiduke", candidates: ["日付"])
            ]) == "hiduke\t日付\n"
        )
    }

    @Test
    func roundTripsCandidateWithSeparateDisplayAndValue() throws {
        let encoded = try #require(DictionaryCandidateRepresentation.encoded(
            display: "トマトの画像",
            value: "https://example.com/tomato.jpg"
        ))
        let entries = [
            DictionaryEntry(reading: "tomato", candidates: [encoded])
        ]
        let text = DictionarySerializer.text(from: entries)
        #expect(text == "tomato\tトマトの画像\thttps://example.com/tomato.jpg\n")
        #expect(try DictionaryParser().parse(text) == entries)
    }

    @Test
    func roundTripsMultilineInsertedValue() throws {
        let value = "山田太郎\n株式会社Example\nexample@example.com"
        let encoded = try #require(DictionaryCandidateRepresentation.encoded(
            display: "会社署名",
            value: value
        ))
        let entries = [
            DictionaryEntry(reading: "signature", candidates: [encoded])
        ]

        let text = DictionarySerializer.text(from: entries)

        #expect(!text.contains("山田太郎\n株式会社Example"))
        #expect(try DictionaryParser().parse(text) == entries)
    }
}
