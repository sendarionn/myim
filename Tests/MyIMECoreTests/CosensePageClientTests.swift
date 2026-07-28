import Testing
@testable import MyIMECore

@Suite
struct CosensePageClientTests {
    @Test
    func createsPageAPIURL() {
        let url = CosensePageClient.APIURL(
            project: "sendarionn-public",
            pageTitle: "見る 方法"
        )

        #expect(
            url?.absoluteString
                == "https://scrapbox.io/api/pages/sendarionn-public/%E8%A6%8B%E3%82%8B_%E6%96%B9%E6%B3%95"
        )
    }
}
