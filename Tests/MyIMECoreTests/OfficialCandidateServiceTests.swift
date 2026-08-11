import Foundation
import Testing
@testable import MyIMECore

struct OfficialCandidateServiceTests {
    @Test func createsSearchURLFromTemplate() throws {
        let template = try SearchURLTemplate("https://example.com/search?q=%s&lang=ja")
        #expect(try template.url(for: "構造 計画").absoluteString == "https://example.com/search?q=%E6%A7%8B%E9%80%A0%20%E8%A8%88%E7%94%BB&lang=ja")
    }

    @Test func encodesSlashForPathAndSiteSearchTemplates() throws {
        let template = try SearchURLTemplate("https://example.com/wiki/%s")
        #expect(
            try template.url(for: "入力/出力").absoluteString
                == "https://example.com/wiki/%E5%85%A5%E5%8A%9B%2F%E5%87%BA%E5%8A%9B"
        )
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

}
