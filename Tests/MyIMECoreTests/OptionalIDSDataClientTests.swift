import Foundation
import Testing
@testable import MyIMECore

@Suite
struct OptionalIDSDataClientTests {
    @Test
    func acceptsCJKVIIDSData() throws {
        let data = Data("U+4F11\t休\t⿰亻木\n".utf8)
        try OptionalIDSDataClient().validate(data)
    }

    @Test
    func rejectsHTMLAndUnrelatedText() {
        #expect(throws: OptionalIDSDataError.invalidData) {
            try OptionalIDSDataClient().validate(Data("<html>error</html>".utf8))
        }
    }
}
