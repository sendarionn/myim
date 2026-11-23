import Foundation

/// The experimental live conversion of one composition: the typed letters
/// stay the composition, and the conversion of the whole of them is only
/// shown and offered, so editing and declining never lose what was typed.
/// The conversion is kept in phrases with their readings, so one phrase
/// can be selected and converted again
public struct LiveConversionState: Equatable, Sendable {
    /// The letters the conversion is for
    public private(set) var input = ""
    /// Conversions of what follows the phrases corrected by hand (all of
    /// it without any), best first
    public private(set) var candidates: [String] = []
    /// The conversion shown, in phrases
    public private(set) var phrases = LiveConversionPhrases(segments: [])

    public init() {}

    /// The reading the phrases corrected by hand cover, which the next
    /// conversion leaves to them
    public var fixedReading: String { phrases.fixedReading }

    /// A conversion for `input`. `reading` is what the letters read as;
    /// where it no longer begins with the corrected phrases, as after a
    /// Delete into them, they are given up and `candidates` and `phrases`
    /// are for all of it
    public mutating func update(
        input: String,
        reading: String? = nil,
        candidates: [String],
        phrases newPhrases: [LiveConversionSegment] = []
    ) {
        self.input = input
        let keepsCorrections = phrases.hasCorrections
            && reading.map { $0.hasPrefix(phrases.fixedReading) } == true
        let fixedText = keepsCorrections ? phrases.fixedSegments.map(\.surface).joined() : ""
        self.candidates = candidates.map { fixedText + $0 }
        let segments = newPhrases.isEmpty
            ? candidates.first.map { [LiveConversionSegment(surface: $0, reading: reading ?? "")] } ?? []
            : newPhrases
        if keepsCorrections {
            phrases.replaceUnfixed(with: segments)
        } else {
            phrases = LiveConversionPhrases(segments: segments)
        }
    }

    public mutating func reset() {
        self = LiveConversionState()
    }

    /// The conversions offered for the composition as it is now: what is
    /// shown first, then the others
    public func candidates(for composition: String) -> [String] {
        guard !composition.isEmpty, composition == input else { return [] }
        let shown = phrases.segments.isEmpty ? candidates.first : phrases.text
        guard let shown else { return candidates }
        return [shown] + candidates.filter { $0 != shown }
    }

    /// What the composition shows instead of the letters, if anything:
    /// until the letters typed since are converted, the last conversion
    /// with them after it
    public func displayText(for composition: String) -> String? {
        guard !input.isEmpty, composition.hasPrefix(input),
              let shown = phrases.segments.isEmpty ? candidates.first : phrases.text
        else { return nil }
        return shown + composition.dropFirst(input.count)
    }

    // MARK: Correcting a phrase

    public var isSelectingPhrase: Bool { phrases.isSelecting }
    public var selectedReading: String? { phrases.selectedSegment?.reading }
    public var selectedTextRange: NSRange? { phrases.selectedTextRange }

    /// Phrases can be selected once the letters are converted
    public func canSelectPhrase(for composition: String) -> Bool {
        composition == input && !phrases.segments.isEmpty
    }

    public mutating func selectPreviousPhrase() { phrases.selectPrevious() }
    public mutating func selectNextPhrase() { phrases.selectNext() }
    public mutating func clearPhraseSelection() { phrases.clearSelection() }

    @discardableResult
    public mutating func adjustPhrase(toward edge: LiveConversionPhrases.Edge) -> Bool {
        phrases.adjust(toward: edge)
    }

    public mutating func previewPhrase(_ surface: String) { phrases.previewSelected(surface) }

    /// The phrase beside the selection to convert again after an adjustment
    public var phraseToConvert: LiveConversionSegment? {
        phrases.phraseToConvert.map { phrases.segments[$0] }
    }

    public mutating func convertAdjacentPhrase(_ surface: String) {
        guard let index = phrases.phraseToConvert else { return }
        phrases.replaceSurface(at: index, with: surface)
    }

    public mutating func commitPhrase(_ surface: String) { phrases.commitSelected(surface) }
}
