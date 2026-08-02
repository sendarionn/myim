import Foundation

public enum AzureDictionaryClientError: Error {
    case invalidInput
    case invalidResponse
}

public struct AzureDictionaryClient: Sendable {
    public let key: String
    public let region: String?

    public init(key: String, region: String? = nil) {
        self.key = key
        self.region = region
    }

    public func translations(
        for text: String,
        from sourceLanguage: String = "ja",
        to targetLanguage: String = "en"
    ) async throws -> [String] {
        guard !key.isEmpty, !text.isEmpty,
              var components = URLComponents(
                string: "https://api.cognitive.microsofttranslator.com/dictionary/lookup"
              ) else {
            throw AzureDictionaryClientError.invalidInput
        }
        components.queryItems = [
            URLQueryItem(name: "api-version", value: "3.0"),
            URLQueryItem(name: "from", value: sourceLanguage),
            URLQueryItem(name: "to", value: targetLanguage)
        ]
        guard let url = components.url else {
            throw AzureDictionaryClientError.invalidInput
        }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json; charset=UTF-8", forHTTPHeaderField: "Content-Type")
        request.setValue(key, forHTTPHeaderField: "Ocp-Apim-Subscription-Key")
        if let region, !region.isEmpty {
            request.setValue(region, forHTTPHeaderField: "Ocp-Apim-Subscription-Region")
        }
        request.httpBody = try JSONSerialization.data(withJSONObject: [["Text": text]])
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200 else {
            throw AzureDictionaryClientError.invalidResponse
        }
        return try Self.parse(data)
    }

    public static func parse(_ data: Data) throws -> [String] {
        guard let payload = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
              let first = payload.first,
              let translations = first["translations"] as? [[String: Any]] else {
            throw AzureDictionaryClientError.invalidResponse
        }
        var seen = Set<String>()
        return translations.compactMap { $0["displayTarget"] as? String }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
    }
}
