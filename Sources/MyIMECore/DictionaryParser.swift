import Foundation

public struct DictionaryEntry: Equatable, Sendable {
    public let input: String
    public let candidates: [String]

    public init(input: String, candidates: [String]) {
        self.input = input
        self.candidates = candidates
    }

    public init(reading: String, candidates: [String]) {
        self.input = reading
        self.candidates = candidates
    }

    public var reading: String { input }
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
                let normalizedCandidate = DictionaryCandidateRepresentation
                    .normalizedForStorage(value)
                if !normalizedCandidate.isEmpty,
                   !currentCandidates.contains(normalizedCandidate) {
                    currentCandidates.append(normalizedCandidate)
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
            if candidatesByReading[entry.input] == nil {
                order.append(entry.input)
                candidatesByReading[entry.input] = []
            }

            for candidate in entry.candidates
            where candidatesByReading[entry.input]?.contains(candidate) == false {
                candidatesByReading[entry.input]?.append(candidate)
            }
        }

        return order.map {
            DictionaryEntry(reading: $0, candidates: candidatesByReading[$0] ?? [])
        }
    }
}
