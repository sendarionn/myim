import Foundation

public struct BrowserBookmark: Equatable, Hashable, Sendable {
    public let title: String
    public let url: String
    public let folderPath: String
    public let profile: String

    public init(
        title: String,
        url: String,
        folderPath: String,
        profile: String
    ) {
        self.title = title
        self.url = url
        self.folderPath = folderPath
        self.profile = profile
    }

    public var displayText: String {
        let name = title.isEmpty ? url : title
        let location = [folderPath, profile]
            .filter { !$0.isEmpty }
            .joined(separator: " · ")
        return location.isEmpty ? "\(name) — \(url)" : "\(name) — \(location) — \(url)"
    }

    /// A bookmarklet runs script instead of opening a page, so it is not
    /// offered to insert or preview
    public var isBookmarklet: Bool {
        url.trimmingCharacters(in: .whitespaces).lowercased().hasPrefix("javascript:")
    }

    public func matches(_ query: String) -> Bool {
        let normalizedQuery = Self.normalized(query)
        guard !normalizedQuery.isEmpty else { return true }
        return [title, url, folderPath, profile].contains {
            Self.normalized($0).contains(normalizedQuery)
        }
    }

    private static func normalized(_ value: String) -> String {
        value.folding(
            options: [.caseInsensitive, .diacriticInsensitive, .widthInsensitive],
            locale: .current
        )
    }
}

public struct BookmarkFormatCandidate: Equatable, Hashable, Sendable {
    public let id: String
    public let label: String
    public let text: String
    public let linkURL: String?

    public init(
        id: String,
        label: String,
        text: String,
        linkURL: String? = nil
    ) {
        self.id = id
        self.label = label
        self.text = text
        self.linkURL = linkURL
    }
}
