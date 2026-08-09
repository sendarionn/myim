import Foundation

public struct SemanticDictionaryEntry: Codable, Equatable, Sendable {
    public let id: String
    public let headword: String
    public let reading: String
    public let partOfSpeech: String?
    public let vocabularyTier: String?
    public let glosses: [String]
    public let explanations: [String]
    public let source: String

    public init(
        id: String,
        headword: String,
        reading: String,
        partOfSpeech: String? = nil,
        vocabularyTier: String? = nil,
        glosses: [String],
        explanations: [String] = [],
        source: String
    ) {
        self.id = id
        self.headword = headword
        self.reading = reading
        self.partOfSpeech = partOfSpeech
        self.vocabularyTier = vocabularyTier
        self.glosses = glosses
        self.explanations = explanations
        self.source = source
    }

    public var searchText: String {
        ([headword, reading, partOfSpeech ?? ""] + glosses + explanations)
            .filter { !$0.isEmpty }
            .joined(separator: "\n")
    }
}

public enum SemanticDictionaryJSONL {
    public static func decode(_ data: Data) throws -> [SemanticDictionaryEntry] {
        let decoder = JSONDecoder()
        return try data.split(separator: 0x0A).compactMap { line in
            guard !line.allSatisfy({ $0 == 0x20 || $0 == 0x09 || $0 == 0x0D }) else {
                return nil
            }
            return try decoder.decode(SemanticDictionaryEntry.self, from: Data(line))
        }
    }

    public static func encode(_ entries: [SemanticDictionaryEntry]) throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        var data = Data()
        for entry in entries {
            data.append(try encoder.encode(entry))
            data.append(0x0A)
        }
        return data
    }
}

public struct SemanticDictionaryMatch: Equatable, Sendable {
    public let entry: SemanticDictionaryEntry
    public let score: Int

    public init(entry: SemanticDictionaryEntry, score: Int) {
        self.entry = entry
        self.score = score
    }
}

public struct SemanticDictionarySearchEngine: Sendable {
    private let entries: [SemanticDictionaryEntry]

    public init(entries: [SemanticDictionaryEntry]) {
        self.entries = entries
    }

    public func matches(for query: String, limit: Int = 3) -> [SemanticDictionaryMatch] {
        let normalizedQuery = Self.normalize(query)
        guard !normalizedQuery.isEmpty, limit > 0 else {
            return []
        }
        return entries.compactMap { entry -> SemanticDictionaryMatch? in
            let headword = Self.normalize(entry.headword)
            let reading = Self.normalize(entry.reading)
            let text = Self.normalize(entry.searchText)
            let score: Int
            if headword == normalizedQuery {
                score = 100
            } else if reading == normalizedQuery {
                score = 90
            } else if headword.contains(normalizedQuery) {
                score = 70
            } else if reading.contains(normalizedQuery) {
                score = 60
            } else if text.contains(normalizedQuery) {
                score = 40
            } else {
                return nil
            }
            return SemanticDictionaryMatch(entry: entry, score: score)
        }.sorted {
            if $0.score != $1.score {
                return $0.score > $1.score
            }
            return $0.entry.id < $1.entry.id
        }.prefix(limit).map { $0 }
    }

    private static func normalize(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
