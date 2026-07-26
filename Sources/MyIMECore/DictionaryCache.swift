import Foundation

public struct DictionaryCacheMetadata: Codable, Equatable, Sendable {
    public let syncedAt: Date
    public let entryCount: Int

    public init(syncedAt: Date, entryCount: Int) {
        self.syncedAt = syncedAt
        self.entryCount = entryCount
    }
}

public struct DictionaryCache: Sendable {
    public let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public static func applicationSupport(
        fileManager: FileManager = .default
    ) throws -> DictionaryCache {
        guard let applicationSupportURL = fileManager.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw DictionaryCacheError.applicationSupportDirectoryNotFound
        }

        return DictionaryCache(
            directoryURL: applicationSupportURL.appendingPathComponent(
                "my-ime",
                isDirectory: true
            )
        )
    }

    public var dictionaryURL: URL {
        directoryURL.appendingPathComponent("dictionary.txt")
    }

    public var metadataURL: URL {
        directoryURL.appendingPathComponent("sync.json")
    }

    public func containsDictionary(fileManager: FileManager = .default) -> Bool {
        fileManager.fileExists(atPath: dictionaryURL.path)
    }

    public func save(
        dictionaryText: String,
        metadata: DictionaryCacheMetadata,
        fileManager: FileManager = .default
    ) throws {
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        try dictionaryText.write(
            to: dictionaryURL,
            atomically: true,
            encoding: .utf8
        )

        let metadataData = try JSONEncoder().encode(metadata)
        try metadataData.write(to: metadataURL, options: .atomic)
    }

    public func loadMetadata() throws -> DictionaryCacheMetadata? {
        guard FileManager.default.fileExists(atPath: metadataURL.path) else {
            return nil
        }

        return try JSONDecoder().decode(
            DictionaryCacheMetadata.self,
            from: Data(contentsOf: metadataURL)
        )
    }
}

public enum DictionaryCacheError: Error, LocalizedError {
    case applicationSupportDirectoryNotFound

    public var errorDescription: String? {
        "Application Supportフォルダが見つかりません"
    }
}
