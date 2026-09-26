public enum SingleLetterDictionaryCandidateFilter {
    public static func candidates(
        _ candidates: [String],
        for input: String
    ) -> [String] {
        guard isSingleASCIILetter(input) else { return candidates }
        return candidates.filter(isNaturalSingleLetterCandidate)
    }

    private static func isSingleASCIILetter(_ input: String) -> Bool {
        guard input.utf8.count == 1, let byte = input.utf8.first else {
            return false
        }
        return (65...90).contains(byte) || (97...122).contains(byte)
    }

    private static func isNaturalSingleLetterCandidate(_ candidate: String) -> Bool {
        guard candidate.count == 1,
              let scalar = candidate.unicodeScalars.first else {
            return true
        }
        let value = scalar.value
        return value <= 0x7f
            || (0x3040...0x30ff).contains(value)
            || (0x31f0...0x31ff).contains(value)
            || (0x3400...0x9fff).contains(value)
            || (0x20000...0x2fa1f).contains(value)
    }
}
