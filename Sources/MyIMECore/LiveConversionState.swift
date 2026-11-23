import Foundation

/// The live conversion of one composition: the typed letters stay the
/// composition, and the conversions of the whole of them are offered among
/// the candidates. Each is kept in phrases with their readings, so a part
/// of one chosen can be converted again
public struct LiveConversionState: Equatable, Sendable {
    /// The letters the conversion is for
    public private(set) var input = ""
    /// The kana the letters read
    public private(set) var reading = ""
    /// Conversions of the whole of them, best first
    public private(set) var candidates: [String] = []
    /// Each of the candidates in phrases
    public private(set) var phrases: [[LiveConversionSegment]] = []

    public init() {}

    public mutating func update(
        input: String,
        reading: String = "",
        candidates: [String],
        phrases: [[LiveConversionSegment]] = []
    ) {
        self.input = input
        self.reading = reading
        self.candidates = candidates
        self.phrases = phrases
    }

    public mutating func reset() {
        self = LiveConversionState()
    }

    /// The conversions offered for the composition as it is now
    public func candidates(for composition: String) -> [String] {
        guard !composition.isEmpty, composition == input else { return [] }
        return candidates
    }

    /// The last conversion with the letters typed since after it, until
    /// they are converted
    public func displayText(for composition: String) -> String? {
        guard !input.isEmpty, composition.hasPrefix(input),
              let shown = candidates.first else { return nil }
        return shown + composition.dropFirst(input.count)
    }

    /// A candidate chosen for the composition, to be corrected in place:
    /// a conversion in its phrases, any other as one phrase of the reading
    public func preview(of candidate: String, for composition: String) -> LiveConversionPreview? {
        guard !candidate.isEmpty, composition == input, !reading.isEmpty else { return nil }
        if let index = candidates.firstIndex(of: candidate), phrases.indices.contains(index),
           !phrases[index].isEmpty {
            return LiveConversionPreview(segments: phrases[index])
        }
        return LiveConversionPreview(segments: [
            LiveConversionSegment(surface: candidate, reading: reading)
        ])
    }
}
