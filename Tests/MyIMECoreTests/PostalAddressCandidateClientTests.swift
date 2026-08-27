import Foundation
import Testing
@testable import MyIMECore

@Suite
struct PostalAddressCandidateClientTests {
    @Test
    func normalizesPostalCodeInput() {
        #expect(PostalCodeNormalizer.normalize("1000001") == "1000001")
        #expect(PostalCodeNormalizer.normalize("100-0001") == "1000001")
        #expect(PostalCodeNormalizer.normalize("100000").isNil)
        #expect(PostalCodeNormalizer.normalize("100x000").isNil)
    }

    @Test
    func buildsSearchURL() throws {
        let url = try PostalAddressCandidateClient.url(for: "100-0001")
        #expect(url.absoluteString.contains("zipcode=1000001"))
    }

    @Test
    func parsesAddressCandidates() throws {
        let data = Data(#"{"status":200,"results":[{"address1":"東京都","address2":"千代田区","address3":"千代田"}]}"#.utf8)
        #expect(
            try PostalAddressCandidateClient.parse(data)
                == ["東京都千代田区千代田"]
        )
    }
}

private extension Optional {
    var isNil: Bool { self == nil }
}
