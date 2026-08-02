import Foundation
import Testing
@testable import MyIMECore

struct OfficialCandidateServiceTests {
    @Test func createsSearchURLFromTemplate() throws {
        let template = try SearchURLTemplate("https://example.com/search?q=%s&lang=ja")
        #expect(try template.url(for: "構造 計画").absoluteString == "https://example.com/search?q=%E6%A7%8B%E9%80%A0%20%E8%A8%88%E7%94%BB&lang=ja")
    }

    @Test func rejectsSearchTemplateWithoutPlaceholder() {
        #expect(throws: SearchURLTemplateError.self) {
            try SearchURLTemplate("https://example.com/search")
        }
    }

    @Test func parsesWikipediaSuggestions() throws {
        let data = Data(#"["構造",["構造計画研究所","構造主義"],[],[]]"#.utf8)
        #expect(try WikipediaSuggestionClient.parse(data) == ["構造計画研究所", "構造主義"])
    }

    @Test func parsesAzureDictionaryTranslations() throws {
        let data = Data(#"[{"normalizedSource":"修正","displaySource":"修正","translations":[{"normalizedTarget":"revision","displayTarget":"revision","posTag":"NOUN","confidence":1.0,"prefixWord":"","backTranslations":[]}]}]"#.utf8)
        #expect(try AzureDictionaryClient.parse(data) == ["revision"])
    }
}
