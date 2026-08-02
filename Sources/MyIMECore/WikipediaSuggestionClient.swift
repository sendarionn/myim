import Foundation

public enum WikipediaSuggestionClientError: Error {
    case invalidQuery
    case invalidResponse
}

public struct WikipediaSuggestionClient: Sendable {
    public init() {}

    public func suggestions(for query: String, language: String = "ja") async throws -> [String] {
        let url = try Self.url(for: query, language: language)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200 else {
            throw WikipediaSuggestionClientError.invalidResponse
        }
        return try Self.parse(data)
    }

    public static func url(for query: String, language: String = "ja") throws -> URL {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              language.range(of: #"^[a-z-]+$"#, options: .regularExpression) != nil,
              var components = URLComponents(string: "https://\(language).wikipedia.org/w/api.php") else {
            throw WikipediaSuggestionClientError.invalidQuery
        }
        components.queryItems = [
            URLQueryItem(name: "action", value: "opensearch"),
            URLQueryItem(name: "search", value: query),
            URLQueryItem(name: "limit", value: "7"),
            URLQueryItem(name: "namespace", value: "0"),
            URLQueryItem(name: "format", value: "json"),
            URLQueryItem(name: "origin", value: "*")
        ]
        guard let url = components.url else {
            throw WikipediaSuggestionClientError.invalidQuery
        }
        return url
    }

    public static func parse(_ data: Data) throws -> [String] {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [Any],
              payload.count >= 2,
              let values = payload[1] as? [String] else {
            throw WikipediaSuggestionClientError.invalidResponse
        }
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
