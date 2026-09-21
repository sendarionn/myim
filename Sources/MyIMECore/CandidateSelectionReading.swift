public enum CandidateSelectionReading {
    public static func resolve(
        conversionReading: String,
        originalInput: String
    ) -> String {
        conversionReading.isEmpty ? originalInput : conversionReading
    }
}
