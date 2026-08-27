import Foundation

public enum PostalAddressCandidateClientError: Error {
    case invalidPostalCode
    case invalidResponse
}

public enum PostalCodeNormalizer {
    public static func normalize(_ input: String) -> String? {
        let digits: String
        if input.count == 8, input[input.index(input.startIndex, offsetBy: 3)] == "-" {
            digits = input.replacingOccurrences(of: "-", with: "")
        } else {
            digits = input
        }
        guard digits.count == 7,
              digits.allSatisfy({ $0.isASCII && $0.isNumber }) else {
            return nil
        }
        return digits
    }
}

public struct PostalAddressCandidateClient: Sendable {
    public init() {}

    public func candidates(for postalCode: String) async throws -> [String] {
        let url = try Self.url(for: postalCode)
        let (data, response) = try await URLSession.shared.data(from: url)
        guard let response = response as? HTTPURLResponse,
              response.statusCode == 200 else {
            throw PostalAddressCandidateClientError.invalidResponse
        }
        return try Self.parse(data)
    }

    public static func url(for postalCode: String) throws -> URL {
        guard let normalized = PostalCodeNormalizer.normalize(postalCode),
              var components = URLComponents(
                  string: "https://zipcloud.ibsnet.co.jp/api/search"
              ) else {
            throw PostalAddressCandidateClientError.invalidPostalCode
        }
        components.queryItems = [URLQueryItem(name: "zipcode", value: normalized)]
        guard let url = components.url else {
            throw PostalAddressCandidateClientError.invalidPostalCode
        }
        return url
    }

    public static func parse(_ data: Data) throws -> [String] {
        struct Response: Decodable {
            struct Result: Decodable {
                let address1: String
                let address2: String
                let address3: String
            }
            let status: Int
            let results: [Result]?
        }
        let response = try JSONDecoder().decode(Response.self, from: data)
        guard response.status == 200 else {
            throw PostalAddressCandidateClientError.invalidResponse
        }
        var seen = Set<String>()
        return (response.results ?? []).compactMap {
            let address = $0.address1 + $0.address2 + $0.address3
            return address.isEmpty || !seen.insert(address).inserted ? nil : address
        }
    }
}
