import Foundation

public struct TKGDictionarySnapshot: Equatable, Sendable {
    public let generatedAt: String
    public let sourceEntryCount: Int
    public let dictionaryText: String
    public let entries: [DictionaryEntry]

    public init(
        generatedAt: String,
        sourceEntryCount: Int,
        dictionaryText: String,
        entries: [DictionaryEntry]
    ) {
        self.generatedAt = generatedAt
        self.sourceEntryCount = sourceEntryCount
        self.dictionaryText = dictionaryText
        self.entries = entries
    }
}

public struct TKGDictionaryClient: Sendable {
    public static let sourceURL = URL(
        string: "https://raw.githubusercontent.com/tkgally/je-dict-1/main/entries_index.json"
    )!

    public init() {}

    public func fetch() async throws -> TKGDictionarySnapshot {
        let (data, response) = try await URLSession.shared.data(
            from: Self.sourceURL
        )
        guard
            let HTTPResponse = response as? HTTPURLResponse,
            (200..<300).contains(HTTPResponse.statusCode)
        else {
            throw TKGDictionaryError.invalidResponse
        }

        return try convert(data)
    }

    public func convert(_ data: Data) throws -> TKGDictionarySnapshot {
        let index = try JSONDecoder().decode(TKGDictionaryIndex.self, from: data)
        let tierOrder = ["basic": 0, "core": 1, "general": 2]
        let sortedEntries = index.entries.sorted {
            let leftTier = tierOrder[$0.vocabularyTier] ?? 99
            let rightTier = tierOrder[$1.vocabularyTier] ?? 99
            return leftTier == rightTier
                ? $0.id < $1.id
                : leftTier < rightTier
        }

        var readingOrder: [String] = []
        var candidatesByReading: [String: [String]] = [:]
        for entry in sortedEntries {
            guard
                tierOrder[entry.vocabularyTier] != nil,
                let separator = entry.id.firstIndex(of: "_")
            else {
                continue
            }

            let reading = String(entry.id[entry.id.index(after: separator)...])
            guard !reading.isEmpty, !entry.headword.contains("\n") else {
                continue
            }
            if candidatesByReading[reading] == nil {
                readingOrder.append(reading)
                candidatesByReading[reading] = []
            }
            for candidate in DictionaryCandidateSplitter.alternatives(
                from: entry.headword
            ) {
                let normalizedCandidate = CandidateCommitNormalizer.value(
                    from: candidate
                )
                guard
                    !normalizedCandidate.isEmpty,
                    candidatesByReading[reading]?.contains(normalizedCandidate) == false
                else {
                    continue
                }
                candidatesByReading[reading]?.append(normalizedCandidate)
            }
        }

        let entries = readingOrder.compactMap { reading in
            let candidates = candidatesByReading[reading] ?? []
            return candidates.isEmpty
                ? nil
                : DictionaryEntry(reading: reading, candidates: candidates)
        }
        let dictionaryText = DictionarySerializer.text(from: entries)

        return TKGDictionarySnapshot(
            generatedAt: index.metadata.generated,
            sourceEntryCount: index.metadata.totalEntries,
            dictionaryText: dictionaryText,
            entries: entries
        )
    }
}

private struct TKGDictionaryIndex: Decodable {
    let metadata: Metadata
    let entries: [Entry]

    struct Metadata: Decodable {
        let generated: String
        let totalEntries: Int

        enum CodingKeys: String, CodingKey {
            case generated
            case totalEntries = "total_entries"
        }
    }

    struct Entry: Decodable {
        let id: String
        let headword: String
        let vocabularyTier: String

        enum CodingKeys: String, CodingKey {
            case id
            case headword
            case vocabularyTier = "vocabulary_tier"
        }
    }
}

public enum TKGDictionaryError: Error, LocalizedError {
    case invalidResponse

    public var errorDescription: String? {
        "TKGJEの応答を読み込めません"
    }
}
