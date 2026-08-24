import Foundation
import MyIMECore

enum JavaScriptExtensionConfiguration {
    static func webSearchURL() -> String {
        metadata("myim-url", in: "websearch.js")
            ?? SearchURLTemplate.defaultValue
    }

    static func externalInformationURL(project: String) -> String? {
        metadata("myim-url", in: "external-information.js")?
            .replacingOccurrences(of: "{project}", with: encoded(project))
    }

    static func externalInformationDelay() -> TimeInterval? {
        metadata("myim-delay", in: "external-information.js")
            .flatMap(TimeInterval.init)
            .map { max(0, $0) }
    }

    private static func metadata(_ name: String, in fileName: String) -> String? {
        guard let directory = JavaScriptExtensionClient
            .prepareUserExtensionDirectory(),
              let source = try? String(
                  contentsOf: directory.appendingPathComponent(fileName),
                  encoding: .utf8
              ) else {
            return nil
        }
        let marker = "// @\(name) "
        return source.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(30)
            .compactMap { line -> String? in
                let text = String(line)
                guard text.hasPrefix(marker) else { return nil }
                let value = String(text.dropFirst(marker.count))
                    .trimmingCharacters(in: .whitespaces)
                return value.isEmpty ? nil : value
            }
            .first
    }

    private static func encoded(_ value: String) -> String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        return value.addingPercentEncoding(withAllowedCharacters: allowed) ?? value
    }
}
