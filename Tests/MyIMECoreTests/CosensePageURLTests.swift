import Testing
@testable import MyIMECore

struct CosensePageURLTests {
    @Test
    func createsPageURL() {
        let url = CosensePageURL.make(project: "sendarionn", pageTitle: "見る")

        #expect(
            url?.absoluteString
                == "https://scrapbox.io/sendarionn/%E8%A6%8B%E3%82%8B"
        )
    }

    @Test
    func replacesSpacesWithUnderscores() {
        let url = CosensePageURL.make(project: "my project", pageTitle: "2 Hop Link")

        #expect(
            url?.absoluteString
                == "https://scrapbox.io/my%20project/2_Hop_Link"
        )
    }
}
