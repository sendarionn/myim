import Foundation
@preconcurrency import NaturalLanguage
import MyIMECore

struct SemanticVectorSuggestion: Equatable, Sendable {
    let candidate: String
    let reading: String
    let similarity: Double
}

actor SemanticVectorSearchEngine {
    private struct IndexedVector {
        let entry: SemanticDictionaryEntry
        let offset: Int
    }

    private let dictionaryURL: URL?
    private let vectorIndexURL: URL?
    private var indexedVectors: [IndexedVector]?
    private var vectorData: Data?
    private var centroid: [Double] = []
    private var dimension = 0
    private var entriesByReading: [String: [SemanticDictionaryEntry]] = [:]
    private var maximumReadingLength = 0
    private var preparationFailed = false

    init(dictionaryURL: URL?, vectorIndexURL: URL?) {
        self.dictionaryURL = dictionaryURL
        self.vectorIndexURL = vectorIndexURL
    }

    func prepare() async {
        guard indexedVectors == nil, !preparationFailed else {
            return
        }
        guard let dictionaryURL, let vectorIndexURL,
              let dictionaryData = try? Data(contentsOf: dictionaryURL),
              let entries = try? SemanticDictionaryJSONL.decode(dictionaryData),
              let data = try? Data(contentsOf: vectorIndexURL, options: .mappedIfSafe),
              data.count >= 20,
              String(data: data.prefix(8), encoding: .utf8) == "MYIMSV01" else {
            preparationFailed = true
            return
        }
        let version: UInt32 = Self.readInteger(data, at: 8)
        let storedDimension: UInt32 = Self.readInteger(data, at: 12)
        let recordCount: UInt32 = Self.readInteger(data, at: 16)
        let centroidSize = Int(storedDimension) * 4
        let recordsOffset = 20 + centroidSize
        let recordSize = 4 + Int(storedDimension) * 2
        guard version == 2, storedDimension > 0,
              data.count == recordsOffset + Int(recordCount) * recordSize else {
            preparationFailed = true
            return
        }
        var storedCentroid: [Double] = []
        storedCentroid.reserveCapacity(Int(storedDimension))
        for component in 0..<Int(storedDimension) {
            let bits: UInt32 = Self.readInteger(
                data,
                at: 20 + component * 4
            )
            storedCentroid.append(Double(Float(bitPattern: bits)))
        }
        var vectors: [IndexedVector] = []
        vectors.reserveCapacity(Int(recordCount))
        for recordIndex in 0..<Int(recordCount) {
            let offset = recordsOffset + recordIndex * recordSize
            let entryIndex: UInt32 = Self.readInteger(data, at: offset)
            guard entries.indices.contains(Int(entryIndex)) else {
                preparationFailed = true
                return
            }
            vectors.append(IndexedVector(
                entry: entries[Int(entryIndex)],
                offset: offset + 4
            ))
        }
        dimension = Int(storedDimension)
        centroid = storedCentroid
        entriesByReading = Dictionary(grouping: entries, by: \.reading)
        maximumReadingLength = entriesByReading.keys.map(\.count).max() ?? 0
        vectorData = data
        indexedVectors = vectors
    }

    func matches(
        for query: String,
        sourceReading: String,
        excluding excludedCandidates: Set<String>,
        limit: Int = 3
    ) async -> [SemanticVectorSuggestion] {
        await prepare()
        guard !Task.isCancelled,
              limit > 0,
              let indexedVectors, let vectorData,
              let embedding = NLEmbedding.wordEmbedding(for: .english),
              let normalizedQuery = Self.centeredNormalizedAverage(
                of: expandedQuery(query, sourceReading: sourceReading),
                embedding: embedding,
                centroid: centroid
              ), normalizedQuery.count == dimension else {
            return []
        }
        var best: [SemanticVectorSuggestion] = []
        for (index, indexed) in indexedVectors.enumerated() {
            if index.isMultiple(of: 128) {
                guard !Task.isCancelled else {
                    return []
                }
            }
            guard !excludedCandidates.contains(indexed.entry.headword) else {
                continue
            }
            var similarity = 0.0
            for component in 0..<dimension {
                let bits: UInt16 = Self.readInteger(
                    vectorData,
                    at: indexed.offset + component * 2
                )
                similarity += normalizedQuery[component]
                    * Double(Float16(bitPattern: bits))
            }
            guard similarity >= 0.42 else {
                continue
            }
            let suggestion = SemanticVectorSuggestion(
                candidate: indexed.entry.headword,
                reading: indexed.entry.reading,
                similarity: similarity
            )
            best.append(suggestion)
            best.sort { $0.similarity > $1.similarity }
            if best.count > limit {
                best.removeLast()
            }
        }
        return best
    }

    private func expandedQuery(_ query: String, sourceReading: String) -> String {
        let ignoredReadings: Set<String> = ["aru", "iru", "koto", "mono", "suru"]
        var components: [String] = []
        var offset = sourceReading.startIndex
        while offset < sourceReading.endIndex, components.count < 8 {
            let remaining = sourceReading.distance(
                from: offset,
                to: sourceReading.endIndex
            )
            var matchedLength = min(maximumReadingLength, remaining)
            var matchedEntries: [SemanticDictionaryEntry]?
            while matchedLength >= 2 {
                let end = sourceReading.index(offset, offsetBy: matchedLength)
                let reading = String(sourceReading[offset..<end])
                if !ignoredReadings.contains(reading),
                   let entries = entriesByReading[reading] {
                    matchedEntries = entries
                    break
                }
                matchedLength -= 1
            }
            if let matchedEntries {
                let glosses = matchedEntries.prefix(2).compactMap(\.glosses.first)
                components.append(contentsOf: glosses)
                offset = sourceReading.index(offset, offsetBy: matchedLength)
            } else {
                offset = sourceReading.index(after: offset)
            }
        }
        guard !components.isEmpty else { return query }
        return ([query] + components).joined(separator: ". ")
    }

    private static func centeredNormalizedAverage(
        of text: String,
        embedding: NLEmbedding,
        centroid: [Double]
    ) -> [Double]? {
        let stopWords: Set<String> = [
            "a", "an", "and", "as", "at", "be", "by", "for", "from",
            "in", "is", "it", "of", "on", "or", "that", "the", "this",
            "to", "used", "who", "with"
        ]
        let tokenizer = NLTokenizer(unit: .word)
        tokenizer.setLanguage(.english)
        tokenizer.string = text
        var sum = Array(repeating: 0.0, count: embedding.dimension)
        var count = 0
        tokenizer.enumerateTokens(in: text.startIndex..<text.endIndex) { range, _ in
            let token = text[range].lowercased()
            guard !stopWords.contains(token),
                  let vector = embedding.vector(for: token) else {
                return true
            }
            for index in vector.indices {
                sum[index] += vector[index]
            }
            count += 1
            return true
        }
        guard count > 0 else { return nil }
        let average = sum.map { $0 / Double(count) }
        let centered = zip(average, centroid).map(-)
        let magnitude = sqrt(centered.reduce(0.0) { $0 + $1 * $1 })
        guard magnitude > 0 else { return nil }
        return centered.map { $0 / magnitude }
    }

    private static func readInteger<T: FixedWidthInteger>(
        _ data: Data,
        at offset: Int
    ) -> T {
        data.withUnsafeBytes {
            T(littleEndian: $0.loadUnaligned(fromByteOffset: offset, as: T.self))
        }
    }
}
