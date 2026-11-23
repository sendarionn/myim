import Foundation

public struct ImportedDictionarySummary: Equatable, Sendable {
    public let fileURL: URL
    public let readingCount: Int
    public let candidateCount: Int
    public let skippedEntryCount: Int
}

public struct ImportedDictionaryBatchSummary: Equatable, Sendable {
    public let readingCount: Int
    public let candidateCount: Int
    public let skippedEntryCount: Int

    public var description: String {
        "読み \(readingCount)件、候補 \(candidateCount)件、対象外 \(skippedEntryCount)件"
    }
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
        // Okuri-ari entries go beside it, for SKK mode only; an extension
        // other than tsv keeps them out of the ordinary dictionaries
        let okuriURL = Self.okuriAriURL(for: fileURL)
        if result.okuriAriEntries.isEmpty {
            try? fileManager.removeItem(at: okuriURL)
        } else {
            try DictionarySerializer.text(from: result.okuriAriEntries).write(
                to: okuriURL,
                atomically: true,
                encoding: .utf8
            )
        }
        return ImportedDictionarySummary(
            fileURL: fileURL,
            readingCount: result.entries.count,
            candidateCount: result.entries.reduce(0) { $0 + $1.candidates.count },
            skippedEntryCount: result.skippedEntryCount
        )
    }

    public func importSKKFiles(
        _ urls: [URL],
        fileManager: FileManager = .default,
        onImported: (ImportedDictionarySummary) -> Void = { _ in }
    ) throws -> ImportedDictionaryBatchSummary {
        var readingCount = 0
        var candidateCount = 0
        var skippedEntryCount = 0
        for url in urls {
            let summary = try importSKK(
                data: Data(contentsOf: url),
                sourceFilename: url.lastPathComponent,
                fileManager: fileManager
            )
            readingCount += summary.readingCount
            candidateCount += summary.candidateCount
            skippedEntryCount += summary.skippedEntryCount
            onImported(summary)
        }
        return ImportedDictionaryBatchSummary(
            readingCount: readingCount,
            candidateCount: candidateCount,
            skippedEntryCount: skippedEntryCount
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

    /// The okuri-ari entries of the enabled dictionaries, by SKK key (かk),
    /// in dictionary order
    public func loadOkuriAriCandidates(
        excludingFilenames disabled: Set<String> = [],
        fileManager: FileManager = .default
    ) -> [String: [String]] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directoryURL,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [:] }
        var candidates: [String: [String]] = [:]
        for url in urls.filter({ $0.pathExtension == Self.okuriAriExtension })
            .sorted(by: { $0.lastPathComponent < $1.lastPathComponent }) {
            let dictionaryName = url.deletingPathExtension()
                .appendingPathExtension("tsv").lastPathComponent
            guard !disabled.contains(dictionaryName),
                  let text = try? String(contentsOf: url, encoding: .utf8),
                  let entries = try? DictionaryParser().parse(text) else { continue }
            for entry in entries {
                for candidate in entry.candidates
                where candidates[entry.reading, default: []].contains(candidate) == false {
                    candidates[entry.reading, default: []].append(candidate)
                }
            }
        }
        return candidates
    }

    private static let okuriAriExtension = "okuri"

    private static func okuriAriURL(for dictionaryURL: URL) -> URL {
        dictionaryURL.deletingPathExtension().appendingPathExtension(okuriAriExtension)
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
