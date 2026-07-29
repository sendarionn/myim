import Foundation

public struct CosenseCredential: Equatable, Sendable {
    public enum Kind: String, CaseIterable, Sendable {
        case personalAccessToken
        case serviceAccount
    }

    public let kind: Kind
    public let value: String

    public init?(kind: Kind, value: String) {
        let trimmedValue = value.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedValue.isEmpty else {
            return nil
        }
        self.kind = kind
        self.value = trimmedValue
    }

    public var headerField: String {
        switch kind {
        case .personalAccessToken:
            return "x-personal-access-token"
        case .serviceAccount:
            return "x-service-account-access-key"
        }
    }

    public func authenticatedRequest(url: URL) -> URLRequest {
        var request = URLRequest(url: url)
        request.setValue(value, forHTTPHeaderField: headerField)
        return request
    }
}
