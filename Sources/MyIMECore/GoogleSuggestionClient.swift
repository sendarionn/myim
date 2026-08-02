import Foundation

public enum GoogleSuggestionClientError: Error {
    case invalidQuery
    case invalidResponse
}

public struct GoogleSuggestionClient: Sendable {
    public init() {}

    public func suggestions(
        for query: String,
        locale: String = "ja"
    ) async throws -> [String] {
        let url = try Self.url(for: query, locale: locale)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw GoogleSuggestionClientError.invalidResponse
        }
        return try Self.parse(data)
    }

    public static func url(
        for query: String,
        locale: String = "ja"
    ) throws -> URL {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var components = URLComponents(
                string: "https://suggestqueries.google.com/complete/search"
              ) else {
            throw GoogleSuggestionClientError.invalidQuery
        }
        components.queryItems = [
            URLQueryItem(name: "client", value: "firefox"),
            URLQueryItem(name: "hl", value: locale),
            URLQueryItem(name: "ie", value: "utf8"),
            URLQueryItem(name: "oe", value: "utf8"),
            URLQueryItem(name: "q", value: query)
        ]
        guard let url = components.url else {
            throw GoogleSuggestionClientError.invalidQuery
        }
        return url
    }

    public static func parse(_ data: Data) throws -> [String] {
        guard let payload = try JSONSerialization.jsonObject(with: data)
                as? [Any],
              payload.count >= 2,
              let values = payload[1] as? [String] else {
            throw GoogleSuggestionClientError.invalidResponse
        }
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    public static func searchURL(for query: String) throws -> URL {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var components = URLComponents(
                string: "https://www.google.com/search"
              ) else {
            throw GoogleSuggestionClientError.invalidQuery
        }
        components.queryItems = [URLQueryItem(name: "q", value: query)]
        guard let url = components.url else {
            throw GoogleSuggestionClientError.invalidQuery
        }
        return url
    }
}
