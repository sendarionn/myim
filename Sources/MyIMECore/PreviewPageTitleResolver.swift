public enum PreviewPageTitleResolver {
    public static func pageTitle(
        input: String,
        selectedCandidate: String?
    ) -> String? {
        if let selectedCandidate, !selectedCandidate.isEmpty {
            return selectedCandidate
        }
        return input.isEmpty ? nil : input
    }
}
