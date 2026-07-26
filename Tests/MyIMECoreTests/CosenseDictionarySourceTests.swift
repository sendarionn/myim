import Testing
@testable import MyIMECore

struct CosenseDictionarySourceTests {
    private let source = CosenseDictionarySource(
        project: "sendarionn-public",
        pageTitle: "dictionary"
    )

    @Test
    func createsAPIURL() {
        #expect(
            source.APIURL?.absoluteString
                == "https://scrapbox.io/api/pages/sendarionn-public/dictionary/text"
        )
    }

    @Test
    func removesPageTitleFromResponse() throws {
        let response = """
        dictionary
        miru
         見る
         診る
        """

        let dictionary = try source.dictionaryText(from: response)

        #expect(dictionary == """
        miru
         見る
         診る
        """)
    }

    @Test
    func rejectsUnexpectedPageTitle() {
        #expect(throws: CosenseDictionaryError.unexpectedPageTitle) {
            try source.dictionaryText(from: """
            another-page
            miru
             見る
            """)
        }
    }

    @Test
    func rejectsEmptyDictionary() {
        #expect(throws: CosenseDictionaryError.emptyDictionary) {
            try source.dictionaryText(from: "dictionary\n")
        }
    }
}
