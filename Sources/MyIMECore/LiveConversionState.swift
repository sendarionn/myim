/// The experimental live conversion of one composition: the typed letters
/// stay the composition, and the conversion of the whole of them is only
/// shown and offered, so editing and declining never lose what was typed
public struct LiveConversionState: Equatable, Sendable {
    /// The letters the conversion is for
    public private(set) var input = ""
    /// Conversions of all of them, best first
    public private(set) var candidates: [String] = []
    /// Declined with Esc: the letters are shown until the composition ends
    public private(set) var isDeclined = false

    public init() {}

    /// A conversion for `input`; one for letters typed since is kept out
    public mutating func update(input: String, candidates: [String]) {
        self.input = input
        self.candidates = candidates
    }

    public mutating func decline() {
        isDeclined = true
    }

    public mutating func reset() {
        self = LiveConversionState()
    }

    /// The conversions offered for the composition as it is now
    public func candidates(for composition: String) -> [String] {
        guard !isDeclined, !composition.isEmpty, composition == input else { return [] }
        return candidates
    }

    /// What the composition shows instead of the letters, if anything:
    /// until the letters typed since are converted, the last conversion
    /// with them after it
    public func displayText(for composition: String) -> String? {
        guard !isDeclined, let best = candidates.first, !input.isEmpty,
              composition.hasPrefix(input) else { return nil }
        return best + composition.dropFirst(input.count)
    }
}
