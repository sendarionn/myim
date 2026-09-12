import Foundation
import Testing
@testable import MyIMECore

struct ExternalBrowserCommandTests {
    @Test
    func decodesStoredCommandWithoutReturnApplication() throws {
        let data = Data("""
        {
          "title": "外部情報",
          "frameX": 0,
          "frameY": 0,
          "frameWidth": 420,
          "frameHeight": 420,
          "isVisible": false
        }
        """.utf8)

        let command = try JSONDecoder().decode(
            ExternalBrowserCommand.self,
            from: data
        )

        #expect(command.returnApplicationProcessIdentifier == nil)
    }

    @Test
    func preservesReturnApplicationProcessIdentifier() throws {
        let command = ExternalBrowserCommand(
            url: URL(string: "https://example.com"),
            title: "外部情報",
            frameX: 0,
            frameY: 0,
            frameWidth: 420,
            frameHeight: 420,
            isVisible: true,
            returnApplicationProcessIdentifier: 123
        )
        let restored = try JSONDecoder().decode(
            ExternalBrowserCommand.self,
            from: JSONEncoder().encode(command)
        )

        #expect(restored.returnApplicationProcessIdentifier == 123)
    }
}
