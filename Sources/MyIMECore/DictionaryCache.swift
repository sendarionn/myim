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

    /// The user dictionary, shared by the input method and the selection
    /// service
    public static func userDictionary(
        fileManager: FileManager = .default
    ) throws -> DictionaryCache {
        let applicationCache = try applicationSupport(fileManager: fileManager)
        return DictionaryCache(
            directoryURL: applicationCache.directoryURL
                .appendingPathComponent("user", isDirectory: true)
        )
    }

    /// The entries saved, none without a file; a file that cannot be read
    /// or parsed throws rather than reading as empty
    public func loadEntries(
        fileManager: FileManager = .default
    ) throws -> [DictionaryEntry] {
        guard let readableURL = readableDictionaryURL(fileManager: fileManager) else {
            return []
        }
        let text = try String(contentsOf: readableURL, encoding: .utf8)
        return try DictionaryParser().parse(text)
    }

    public var dictionaryURL: URL {
        directoryURL.appendingPathComponent("dictionary.tsv")
    }

    public var legacyDictionaryURL: URL {
        directoryURL.appendingPathComponent("dictionary.txt")
    }

    public func readableDictionaryURL(
        fileManager: FileManager = .default
    ) -> URL? {
        if fileManager.fileExists(atPath: dictionaryURL.path) {
            return dictionaryURL
        }
        if fileManager.fileExists(atPath: legacyDictionaryURL.path) {
            return legacyDictionaryURL
        }
        return nil
    }

    public var metadataURL: URL {
        directoryURL.appendingPathComponent("sync.json")
    }

    /// What tells a changed dictionary file from the one last read
    /// without reading it: its identity, size, and modification time
    public struct FileStamp: Equatable, Sendable {
        let fileNumber: Int?
        let size: Int?
        let modificationDate: Date?
    }

    public func dictionaryStamp(fileManager: FileManager = .default) -> FileStamp? {
        guard let url = readableDictionaryURL(fileManager: fileManager),
              let attributes = try? fileManager.attributesOfItem(atPath: url.path)
        else { return nil }
        return FileStamp(
            fileNumber: (attributes[.systemFileNumber] as? NSNumber)?.intValue,
            size: (attributes[.size] as? NSNumber)?.intValue,
            modificationDate: attributes[.modificationDate] as? Date
        )
    }

    public func containsDictionary(fileManager: FileManager = .default) -> Bool {
        readableDictionaryURL(fileManager: fileManager) != nil
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
        if fileManager.fileExists(atPath: legacyDictionaryURL.path) {
            try fileManager.removeItem(at: legacyDictionaryURL)
        }

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
