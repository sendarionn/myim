public enum LiteralInputCandidatePolicy {
    public static func candidate(
        input: String,
        exactDictionaryCandidates: [String]
    ) -> String? {
        guard !input.isEmpty,
              !exactDictionaryCandidates.contains(where: {
                  DictionaryCandidateRepresentation.value(from: $0) == input
              }) else {
            return nil
        }
        return input
    }
}
