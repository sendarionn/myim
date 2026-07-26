import Foundation

public struct DictionaryEntry: Equatable, Sendable {
    public let reading: String
    public let candidates: [String]

    public init(reading: String, candidates: [String]) {
        self.reading = reading
        self.candidates = candidates
    }
}

public enum DictionaryParserError: Error, Equatable, LocalizedError {
    case candidateWithoutReading(line: Int)
    case readingWithoutCandidates(reading: String, line: Int)

    public var errorDescription: String? {
        switch self {
        case let .candidateWithoutReading(line):
            return "\(line)行目の候補に対応する読みがありません"
        case let .readingWithoutCandidates(reading, line):
            return "\(line)行目の読み「\(reading)」に候補がありません"
        }
    }
}

public struct DictionaryParser: Sendable {
    public init() {}

    public func parse(_ text: String) throws -> [DictionaryEntry] {
        var entries: [DictionaryEntry] = []
        var currentReading: String?
        var currentReadingLine = 0
        var currentCandidates: [String] = []

        func makeEntry() throws -> DictionaryEntry? {
            guard let reading = currentReading else {
                return nil
            }
            guard !currentCandidates.isEmpty else {
                throw DictionaryParserError.readingWithoutCandidates(
                    reading: reading,
                    line: currentReadingLine
                )
            }
            return DictionaryEntry(reading: reading, candidates: currentCandidates)
        }

        for (index, rawLine) in text.components(separatedBy: .newlines).enumerated() {
            let lineNumber = index + 1
            let value = rawLine.trimmingCharacters(in: .whitespaces)

            if value.isEmpty {
                continue
            }

            let isCandidate = rawLine.first?.isWhitespace == true
            if isCandidate {
                guard currentReading != nil else {
                    throw DictionaryParserError.candidateWithoutReading(line: lineNumber)
                }
                if !currentCandidates.contains(value) {
                    currentCandidates.append(value)
                }
                continue
            }

            if let entry = try makeEntry() {
                entries.append(entry)
            }
            currentReading = value
            currentReadingLine = lineNumber
            currentCandidates = []
        }

        if let entry = try makeEntry() {
            entries.append(entry)
        }

        return mergeDuplicateReadings(entries)
    }

    private func mergeDuplicateReadings(_ entries: [DictionaryEntry]) -> [DictionaryEntry] {
        var order: [String] = []
        var candidatesByReading: [String: [String]] = [:]

        for entry in entries {
            if candidatesByReading[entry.reading] == nil {
                order.append(entry.reading)
                candidatesByReading[entry.reading] = []
            }

            for candidate in entry.candidates
            where candidatesByReading[entry.reading]?.contains(candidate) == false {
                candidatesByReading[entry.reading]?.append(candidate)
            }
        }

        return order.map {
            DictionaryEntry(reading: $0, candidates: candidatesByReading[$0] ?? [])
        }
    }
}
