import Foundation

public struct CosenseProjectConfiguration: Equatable, Sendable {
    public let project: String

    public init?(projectURL: URL) {
        guard
            projectURL.scheme?.lowercased() == "https",
            let host = projectURL.host?.lowercased(),
            host == "scrapbox.io" || host == "www.scrapbox.io",
            let encodedProject = projectURL.pathComponents.dropFirst().first,
            let decodedProject = encodedProject.removingPercentEncoding,
            !decodedProject.isEmpty,
            decodedProject != ".",
            decodedProject != "..",
            !decodedProject.contains("/")
        else {
            return nil
        }

        project = decodedProject
    }

    public init(project: String) {
        self.project = project
    }

    public var projectURL: URL? {
        URL(string: "https://scrapbox.io/\(project)")
    }

    public var dictionarySource: CosenseDictionarySource {
        CosenseDictionarySource(project: project, pageTitle: "dictionary")
    }
}
