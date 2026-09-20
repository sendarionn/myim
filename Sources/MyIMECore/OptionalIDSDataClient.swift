import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum OptionalIDSDataError: Error, Equatable, LocalizedError {
    case invalidResponse
    case invalidData

    public var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "配布元から正常な応答を取得できませんでした"
        case .invalidData:
            "取得したファイルが対応するIDS形式ではありません"
        }
    }
}

public struct OptionalIDSDataClient: Sendable {
    public static let sourceURL = URL(
        string: "https://raw.githubusercontent.com/cjkvi/cjkvi-ids/master/ids.txt"
    )!

    public init() {}

    public func fetch() async throws -> Data {
        let (data, response) = try await URLSession.shared.data(
            from: Self.sourceURL
        )
        guard let HTTPResponse = response as? HTTPURLResponse,
              (200..<300).contains(HTTPResponse.statusCode) else {
            throw OptionalIDSDataError.invalidResponse
        }
        try validate(data)
        return data
    }

    public func validate(_ data: Data) throws {
        guard let text = String(data: data, encoding: .utf8),
              text.split(whereSeparator: \Character.isNewline).contains(where: {
                  $0.hasPrefix("U+") && $0.contains("\t")
              }) else {
            throw OptionalIDSDataError.invalidData
        }
    }
}
