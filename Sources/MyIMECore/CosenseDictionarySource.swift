import Foundation

public struct CosenseDictionarySource: Equatable, Sendable {
    public let project: String
    public let pageTitle: String

    public init(project: String, pageTitle: String) {
        self.project = project
        self.pageTitle = pageTitle
    }

    public var APIURL: URL? {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")

        guard
            let encodedProject = project.addingPercentEncoding(withAllowedCharacters: allowed),
            let encodedTitle = pageTitle.addingPercentEncoding(withAllowedCharacters: allowed)
        else {
            return nil
        }

        return URL(
            string: "https://scrapbox.io/api/pages/\(encodedProject)/\(encodedTitle)/text"
        )
    }

    public var pageURL: URL? {
        CosensePageURL.make(project: project, pageTitle: pageTitle)
    }

    public func dictionaryText(from responseText: String) throws -> String {
        var lines = responseText.components(separatedBy: .newlines)

        guard let firstContentLineIndex = lines.firstIndex(
            where: { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        ) else {
            throw CosenseDictionaryError.emptyResponse
        }

        guard
            lines[firstContentLineIndex]
                .trimmingCharacters(in: .whitespaces) == pageTitle
        else {
            throw CosenseDictionaryError.unexpectedPageTitle
        }

        lines.remove(at: firstContentLineIndex)
        let dictionaryText = lines.joined(separator: "\n")

        guard !dictionaryText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw CosenseDictionaryError.emptyDictionary
        }

        return dictionaryText
    }
}

public enum CosenseDictionaryError: Error, Equatable, LocalizedError {
    case invalidAPIURL
    case invalidResponse
    case HTTPStatus(Int)
    case invalidEncoding
    case emptyResponse
    case unexpectedPageTitle
    case emptyDictionary

    public var errorDescription: String? {
        switch self {
        case .invalidAPIURL:
            return "Cosense APIのURLを作成できません"
        case .invalidResponse:
            return "Cosense APIから不正な応答を受信しました"
        case let .HTTPStatus(status):
            return "Cosense APIがHTTP \(status)を返しました"
        case .invalidEncoding:
            return "Cosense辞書をUTF-8として読み込めません"
        case .emptyResponse:
            return "Cosense辞書ページが空です"
        case .unexpectedPageTitle:
            return "Cosense辞書ページのタイトルを確認できません"
        case .emptyDictionary:
            return "Cosense辞書に変換項目がありません"
        }
    }
}
