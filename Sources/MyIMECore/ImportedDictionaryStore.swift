import Foundation

public struct ImportedDictionarySummary: Equatable, Sendable {
    public let fileURL: URL
    public let readingCount: Int
    public let candidateCount: Int
    public let skippedEntryCount: Int
}

public struct ImportedDictionary: Equatable, Sendable {
    public let fileURL: URL
    public let entries: [DictionaryEntry]

    public init(fileURL: URL, entries: [DictionaryEntry]) {
        self.fileURL = fileURL
        self.entries = entries
    }
}

public enum ImportedDictionaryStoreError: Error, LocalizedError {
    case unsupportedEncoding
    case noEntries

    public var errorDescription: String? {
        switch self {
        case .unsupportedEncoding:
            return "辞書の文字コードを読み取れません"
        case .noEntries:
            return "取り込める送りなしエントリがありません"
        }
    }
}

public struct ImportedDictionaryStore: Sendable {
    public let directoryURL: URL

    public init(directoryURL: URL) {
        self.directoryURL = directoryURL
    }

    public func importSKK(
        data: Data,
        sourceFilename: String,
        fileManager: FileManager = .default
    ) throws -> ImportedDictionarySummary {
        guard let text = decode(data) else {
            throw ImportedDictionaryStoreError.unsupportedEncoding
        }
        let result = SKKDictionaryParser().parse(text)
        guard !result.entries.isEmpty else {
            throw ImportedDictionaryStoreError.noEntries
        }
        try fileManager.createDirectory(
            at: directoryURL,
            withIntermediateDirectories: true
        )
        let fileURL = dictionaryURL(for: sourceFilename)
        try DictionarySerializer.text(from: result.entries).write(
            to: fileURL,
            atomically: true,
            encoding: .utf8
        )
        return ImportedDictionarySummary(
            fileURL: fileURL,
            readingCount: result.entries.count,
            candidateCount: result.entries.reduce(0) { $0 + $1.candidates.count },
            skippedEntryCount: result.skippedEntryCount
        )
    }

    public func loadLayers(
        fileManager: FileManager = .default
    ) -> [[DictionaryEntry]] {
        loadDictionaries(fileManager: fileManager).map(\.entries)
    }

    public func loadDictionaries(
        fileManager: FileManager = .default
    ) -> [ImportedDictionary] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls
            .filter { $0.pathExtension.lowercased() == "tsv" }
            .sorted { $0.lastPathComponent < $1.lastPathComponent }
            .compactMap { url in
                guard let text = try? String(contentsOf: url, encoding: .utf8)
                else { return nil }
                guard let entries = try? DictionaryParser().parse(text),
                      !entries.isEmpty else { return nil }
                return ImportedDictionary(fileURL: url, entries: entries)
            }
    }

    private func dictionaryURL(for sourceFilename: String) -> URL {
        let name = URL(fileURLWithPath: sourceFilename).lastPathComponent
        let safeName = name.unicodeScalars.map { scalar -> Character in
            if CharacterSet.alphanumerics.contains(scalar)
                || scalar == "-" || scalar == "_" || scalar == "." {
                return Character(String(scalar))
            }
            return "_"
        }
        let filename = String(safeName).trimmingCharacters(
            in: CharacterSet(charactersIn: "._")
        )
        return directoryURL.appendingPathComponent(
            (filename.isEmpty ? "SKK-dictionary" : filename) + ".tsv"
        )
    }

    private func decode(_ data: Data) -> String? {
        [.utf8, .japaneseEUC, .shiftJIS].lazy.compactMap {
            String(data: data, encoding: $0)
        }.first
    }
}
