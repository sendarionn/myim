public enum DictionaryRegistrationTextAccumulator {
    public static func confirmedText(
        confirmed: String?,
        pendingPaste: String?
    ) -> String? {
        let combined = (confirmed ?? "") + (pendingPaste ?? "")
        return combined.isEmpty ? nil : combined
    }
}
