public enum CandidatePanelAccentPolicy {
    public static func isAccented(
        isTranslationInput: Bool,
        isDictionaryRegistration: Bool
    ) -> Bool {
        isTranslationInput || isDictionaryRegistration
    }
}
