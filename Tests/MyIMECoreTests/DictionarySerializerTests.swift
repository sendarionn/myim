import Testing
@testable import MyIMECore

@Suite
struct DictionarySerializerTests {
    @Test
    func serializesEntries() {
        #expect(
            DictionarySerializer.text(from: [
                DictionaryEntry(reading: "hiduke", candidates: ["日付"])
            ]) == "hiduke\n 日付\n"
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
        #expect(try DictionaryParser().parse(text) == entries)
    }
}
