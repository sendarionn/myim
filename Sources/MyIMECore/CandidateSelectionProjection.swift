public enum CandidateSelectionProjection {
    public static func index(
        for candidateText: String,
        preferredIndex: Int?,
        in candidates: [Candidate]
    ) -> Int? {
        if let preferredIndex,
           candidates.indices.contains(preferredIndex) {
            let preferred = candidates[preferredIndex]
            if preferred.storageText == candidateText
                || preferred.displayText == candidateText {
                return preferredIndex
            }
        }

        let exactMatches = candidates.indices.filter {
            candidates[$0].storageText == candidateText
        }
        if exactMatches.count == 1 {
            return exactMatches[0]
        }

        let displayMatches = candidates.indices.filter {
            candidates[$0].displayText == candidateText
        }
        return displayMatches.count == 1 ? displayMatches[0] : nil
    }

    /// Text shown while no candidate is selected; the input already holds
    /// any trailing punctuation waiting to be converted
    public static func unconvertedMarkedText(
        input: String,
        prefix: String = ""
    ) -> String {
        prefix + input
    }

    public static func markedText(
        for candidate: Candidate,
        prefix: String = "",
        suffix: String = ""
    ) -> String {
        prefix + candidate.commitText + suffix
    }
}
