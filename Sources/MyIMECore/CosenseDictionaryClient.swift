import Foundation

public struct CosenseDictionaryClient: Sendable {
    public init() {}

    public func fetch(
        from source: CosenseDictionarySource,
        credential: CosenseCredential? = nil
    ) async throws -> String {
        guard let url = source.APIURL else {
            throw CosenseDictionaryError.invalidAPIURL
        }

        let request = credential?.authenticatedRequest(url: url)
            ?? URLRequest(url: url)
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let HTTPResponse = response as? HTTPURLResponse else {
            throw CosenseDictionaryError.invalidResponse
        }
        guard (200..<300).contains(HTTPResponse.statusCode) else {
            throw CosenseDictionaryError.HTTPStatus(HTTPResponse.statusCode)
        }
        guard let responseText = String(data: data, encoding: .utf8) else {
            throw CosenseDictionaryError.invalidEncoding
        }

        return try source.dictionaryText(from: responseText)
    }
}
