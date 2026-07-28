import Foundation

public struct DictionaryCacheMetadata: Codable, Equatable, Sendable {
    public let syncedAt: Date
    public let entryCount: Int
    public let sourceRevision: String?
    public let sourceEntryCount: Int?

    public init(
        syncedAt: Date,
        entryCount: Int,
        sourceRevision: String? = nil,
        sourceEntryCount: Int? = nil
    ) {
        self.syncedAt = syncedAt
        self.entryCount = entryCount
        self.sourceRevision = sourceRevision
        self.sourceEntryCount = sourceEntryCount
    }
}

public struct DictionaryCache: Sendable {
    public let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public static func applicationSupport(
        applicationName: String = "myim",
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
                applicationName,
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
