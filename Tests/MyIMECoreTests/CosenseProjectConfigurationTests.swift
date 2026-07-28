import Foundation
import Testing
@testable import MyIMECore

struct CosenseProjectConfigurationTests {
    @Test
    func parsesProjectURL() {
        let configuration = CosenseProjectConfiguration(
            projectURL: URL(string: "https://scrapbox.io/sendarionn-public")!
        )

        #expect(configuration?.project == "sendarionn-public")
        #expect(
            configuration?.dictionarySource.APIURL?.absoluteString
                == "https://scrapbox.io/api/pages/sendarionn-public/dictionary/text"
        )
    }

    @Test
    func acceptsDictionaryPageURL() {
        let configuration = CosenseProjectConfiguration(
            projectURL: URL(
                string: "https://scrapbox.io/sendarionn-public/dictionary"
            )!
        )

        #expect(configuration?.project == "sendarionn-public")
    }

    @Test
    func rejectsUnsupportedURL() {
        #expect(
            CosenseProjectConfiguration(
                projectURL: URL(string: "http://scrapbox.io/project")!
            ) == nil
        )
        #expect(
            CosenseProjectConfiguration(
                projectURL: URL(string: "https://example.com/project")!
            ) == nil
        )
    }
}
