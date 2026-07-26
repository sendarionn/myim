import Foundation

public struct ConversionEngine: Sendable {
    private let candidatesByReading: [String: [String]]

    public init(entries: [DictionaryEntry]) {
        self.candidatesByReading = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.reading, $0.candidates) }
        )
    }

    public func candidates(for reading: String) -> [String] {
        candidatesByReading[reading] ?? []
    }
}
