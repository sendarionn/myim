public enum CandidateSelectionReading {
    public static func resolve(
        conversionReading: String,
        originalInput: String
    ) -> String {
        conversionReading.isEmpty ? originalInput : conversionReading
    }

    /// The history keys a selection is learned under and ranked by, so
    /// recording and lookup normalize the reading the same way
    public static func historyReadings(for reading: String) -> [String] {
        RomajiCanonicalizer.dictionaryLookupInputs(from: reading)
    }
}
