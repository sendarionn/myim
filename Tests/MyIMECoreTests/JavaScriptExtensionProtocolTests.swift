import Foundation
import Testing
@testable import MyIMECore

@Suite("JavaScriptExtensionProtocolTests")
struct JavaScriptExtensionProtocolTests {
    @Test func carriesTimeComponentsWithoutDateConversion() throws {
        let request = JavaScriptExtensionRequest(
            input: "time",
            timestamp: "2026-10-21T00:00:00Z",
            timeZone: "Asia/Tokyo",
            extensionDirectories: ["/tmp/extensions"],
            parameters: ["hour": "14", "minute": "35"]
        )

        let decoded = try JSONDecoder().decode(
            JavaScriptExtensionRequest.self,
            from: JSONEncoder().encode(request)
        )

        #expect(decoded.parameters == ["hour": "14", "minute": "35"])
    }

    @Test func decodesRequestsFromBeforeParametersWereAdded() throws {
        let data = Data("""
        {
          "id": "00000000-0000-0000-0000-000000000000",
          "input": "calendar",
          "timestamp": "2026-10-21T00:00:00Z",
          "timeZone": "Asia/Tokyo",
          "extensionDirectories": [],
          "disabledFileNames": [],
          "settings": {}
        }
        """.utf8)

        let decoded = try JSONDecoder().decode(
            JavaScriptExtensionRequest.self,
            from: data
        )
        #expect(decoded.parameters == nil)
    }

    @Test func preservesDynamicDateTimeCandidateMetadata() throws {
        let response = JavaScriptExtensionResponse(
            id: UUID(),
            candidates: [
                JavaScriptExtensionCandidate(
                    value: "20261031",
                    kind: .dynamicDateTime
                ),
                JavaScriptExtensionCandidate(value: "今日")
            ]
        )

        let decoded = try JSONDecoder().decode(
            JavaScriptExtensionResponse.self,
            from: JSONEncoder().encode(response)
        )

        #expect(decoded.candidates[0].kind == .dynamicDateTime)
        #expect(decoded.candidates[1].kind == .staticValue)
    }
}
