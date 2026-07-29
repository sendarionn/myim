import Foundation
import Testing
@testable import MyIMECore

@Suite
struct CosenseCredentialTests {
    @Test
    func createsPersonalAccessTokenHeader() throws {
        let credential = try #require(
            CosenseCredential(
                kind: .personalAccessToken,
                value: "personal-token"
            )
        )
        let request = credential.authenticatedRequest(
            url: try #require(URL(string: "https://scrapbox.io/api/pages"))
        )

        #expect(
            request.value(forHTTPHeaderField: "x-personal-access-token")
                == "personal-token"
        )
    }

    @Test
    func createsServiceAccountHeader() throws {
        let credential = try #require(
            CosenseCredential(
                kind: .serviceAccount,
                value: "service-key"
            )
        )
        let request = credential.authenticatedRequest(
            url: try #require(URL(string: "https://scrapbox.io/api/pages"))
        )

        #expect(
            request.value(
                forHTTPHeaderField: "x-service-account-access-key"
            ) == "service-key"
        )
    }

    @Test
    func rejectsEmptyValue() {
        #expect(
            CosenseCredential(
                kind: .personalAccessToken,
                value: "  "
            ) == nil
        )
    }
}
