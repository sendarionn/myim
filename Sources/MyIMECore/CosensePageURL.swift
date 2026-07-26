import Foundation

public enum CosensePageURL {
    public static func make(project: String, pageTitle: String) -> URL? {
        guard !project.isEmpty, !pageTitle.isEmpty else {
            return nil
        }

        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")

        guard
            let encodedProject = project.addingPercentEncoding(withAllowedCharacters: allowed),
            let encodedTitle = pageTitle
                .replacingOccurrences(of: " ", with: "_")
                .addingPercentEncoding(withAllowedCharacters: allowed)
        else {
            return nil
        }

        return URL(string: "https://scrapbox.io/\(encodedProject)/\(encodedTitle)")
    }
}
