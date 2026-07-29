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
}
