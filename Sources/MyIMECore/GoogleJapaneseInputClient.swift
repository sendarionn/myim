import Foundation

public enum GoogleJapaneseInputClientError: Error {
    case invalidInput
    case invalidResponse
}

public struct GoogleJapaneseInputClient: Sendable {
    public init() {}

    public func candidates(for input: String) async throws -> [String] {
        let url = try Self.url(for: input)
        var request = URLRequest(url: url)
        request.timeoutInterval = 2
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200 else {
            throw GoogleJapaneseInputClientError.invalidResponse
        }
        return try Self.parse(data)
    }

    public static func url(for input: String) throws -> URL {
        guard !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              var components = URLComponents(
                  string: "https://www.google.com/transliterate"
              ) else {
            throw GoogleJapaneseInputClientError.invalidInput
        }
        components.queryItems = [
            URLQueryItem(name: "langpair", value: "ja-Hira|ja"),
            URLQueryItem(name: "text", value: input)
        ]
        guard let url = components.url else {
            throw GoogleJapaneseInputClientError.invalidInput
        }
        return url
    }

    public static func parse(_ data: Data, limit: Int = 32) throws -> [String] {
        guard limit > 0,
              let payload = try JSONSerialization.jsonObject(with: data)
                as? [Any] else {
            throw GoogleJapaneseInputClientError.invalidResponse
        }
        let segments: [[String]] = try payload.map { value in
            guard let segment = value as? [Any],
                  segment.count >= 2,
                  let candidates = segment[1] as? [String],
                  !candidates.isEmpty else {
                throw GoogleJapaneseInputClientError.invalidResponse
            }
            return candidates
        }
        guard !segments.isEmpty else { return [] }

        var combined = [""]
        for segment in segments {
            combined = combined.flatMap { prefix in
                segment.map { prefix + $0 }
            }
            if combined.count > limit {
                combined = Array(combined.prefix(limit))
            }
        }
        var seen = Set<String>()
        return combined.filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
