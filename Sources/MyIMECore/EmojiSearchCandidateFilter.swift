public enum EmojiSearchCandidateFilter {
    public static func candidates(
        _ candidates: [Candidate],
        isEditingEmojiSearch: Bool
    ) -> [Candidate] {
        guard isEditingEmojiSearch else { return candidates }
        return candidates.filter { !isEmojiSequence($0.commitText) }
    }

    private static func isEmojiSequence(_ value: String) -> Bool {
        guard value.count == 1 else { return false }
        let scalars = value.unicodeScalars
        guard scalars.contains(where: { $0.properties.isEmoji }) else {
            return false
        }

        let standaloneTextBases: Set<Unicode.Scalar> = [
            "0", "1", "2", "3", "4", "5", "6", "7", "8", "9", "#", "*"
        ]
        return !scalars.allSatisfy { standaloneTextBases.contains($0) }
    }
}
