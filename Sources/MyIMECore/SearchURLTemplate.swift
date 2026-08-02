import Foundation

public enum SearchURLTemplateError: Error {
    case missingPlaceholder
    case invalidQuery
    case invalidURL
}

public struct SearchURLTemplate: Sendable {
    public static let defaultValue = "https://www.google.com/search?q=%s"

    public let value: String

    public init(_ value: String) throws {
        guard value.contains("%s") else {
            throw SearchURLTemplateError.missingPlaceholder
        }
        self.value = value
    }

    public func url(for query: String) throws -> URL {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw SearchURLTemplateError.invalidQuery
        }
        let allowed = CharacterSet.urlQueryAllowed
            .subtracting(CharacterSet(charactersIn: "+&=#?"))
        guard let encoded = query.addingPercentEncoding(withAllowedCharacters: allowed),
              let url = URL(string: value.replacingOccurrences(of: "%s", with: encoded)),
              let scheme = url.scheme?.lowercased(),
              scheme == "https" || scheme == "http" else {
            throw SearchURLTemplateError.invalidURL
        }
        return url
    }
}
