import Testing
@testable import MyIMECore

@Suite
struct DictionaryCandidateRepresentationTests {
    @Test func separatesDisplayAndInsertedValue() throws {
        let encoded = try #require(DictionaryCandidateRepresentation.encoded(
            display: "トマトの画像",
            value: "https://example.com/tomato.jpg"
        ))
        #expect(DictionaryCandidateRepresentation.display(from: encoded) == "トマトの画像")
        #expect(DictionaryCandidateRepresentation.value(from: encoded) == "https://example.com/tomato.jpg")
        #expect(DictionaryCandidateRepresentation.normalizedForStorage(encoded) == encoded)
    }

    @Test func keepsLegacyCandidateBehavior() {
        #expect(DictionaryCandidateRepresentation.display(from: "〜個") == "個")
        #expect(DictionaryCandidateRepresentation.value(from: "〜個") == "個")
    }
}
