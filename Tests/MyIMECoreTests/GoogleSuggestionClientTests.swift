import Foundation
import Testing
@testable import MyIMECore

@Suite
struct GoogleSuggestionClientTests {
    @Test
    func createsEncodedSuggestionURL() throws {
        let url = try GoogleSuggestionClient.url(
            for: "構造 計画",
            locale: "ja"
        )
        let components = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)
        )
        let items = Dictionary(uniqueKeysWithValues: components.queryItems?
            .map { ($0.name, $0.value ?? "") } ?? [])

        #expect(items["client"] == "firefox")
        #expect(items["hl"] == "ja")
        #expect(items["ie"] == "utf8")
        #expect(items["oe"] == "utf8")
        #expect(items["q"] == "構造 計画")
    }

    @Test
    func parsesAndDeduplicatesSuggestions() throws {
        let data = Data(
            #"["ret",["return","return value","return"]]"#.utf8
        )
        let result = try GoogleSuggestionClient.parse(data)

        #expect(result == ["return", "return value"])
    }

    @Test
    func rejectsUnexpectedResponse() {
        #expect(throws: GoogleSuggestionClientError.self) {
            try GoogleSuggestionClient.parse(Data(#"{"value":[]}"#.utf8))
        }
    }

    @Test
    func createsGoogleSearchURLIndependentlyFromSuggestions() throws {
        let url = try GoogleSuggestionClient.searchURL(for: "構造 計画")
        let components = try #require(
            URLComponents(url: url, resolvingAgainstBaseURL: false)
        )

        #expect(components.host == "www.google.com")
        #expect(components.path == "/search")
        #expect(components.queryItems?.first?.value == "構造 計画")
    }
}
