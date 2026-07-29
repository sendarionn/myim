import Foundation

public struct CosenseWebCookieStore {
    private struct StoredCookie: Codable {
        let name: String
        let value: String
        let domain: String
        let path: String
        let expiresAt: Date?
        let isSecure: Bool

        init(_ cookie: HTTPCookie) {
            name = cookie.name
            value = cookie.value
            domain = cookie.domain
            path = cookie.path
            expiresAt = cookie.expiresDate
            isSecure = cookie.isSecure
        }

        var httpCookie: HTTPCookie? {
            var properties: [HTTPCookiePropertyKey: Any] = [
                .name: name,
                .value: value,
                .domain: domain,
                .path: path,
                .secure: isSecure ? "TRUE" : "FALSE"
            ]
            if let expiresAt {
                properties[.expires] = expiresAt
            }
            return HTTPCookie(properties: properties)
        }
    }

    public init() {}

    public func save(_ cookies: [HTTPCookie]) throws {
        let fileManager = FileManager.default
        let directory = try storageDirectory(fileManager: fileManager)
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try fileManager.setAttributes(
            [.posixPermissions: 0o700],
            ofItemAtPath: directory.path
        )

        let data = try JSONEncoder().encode(cookies.map(StoredCookie.init))
        let fileURL = directory.appendingPathComponent("cosense-web-cookies.json")
        try data.write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    public func load() -> [HTTPCookie] {
        let fileManager = FileManager.default
        guard
            let directory = try? storageDirectory(fileManager: fileManager),
            let data = try? Data(
                contentsOf: directory.appendingPathComponent(
                    "cosense-web-cookies.json"
                )
            ),
            let stored = try? JSONDecoder().decode(
                [StoredCookie].self,
                from: data
            )
        else {
            return []
        }
        return stored.compactMap(\.httpCookie)
    }

    private func storageDirectory(fileManager: FileManager) throws -> URL {
        try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("myim", isDirectory: true)
        .appendingPathComponent("web-session", isDirectory: true)
    }
}
