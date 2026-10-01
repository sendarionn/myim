public enum ConversionReadingResolver {
    public static func resolve(_ input: String) -> String {
        if NumericPrefixCandidateComposer.parts(of: input) != nil
            || containsMixedASCIILettersAndDigits(input) {
            return input
        }
        return String(
            input.prefix {
                $0.isASCII
                    && ($0.isLetter || $0 == "-" || $0 == "'")
            }
        )
    }

    private static func containsMixedASCIILettersAndDigits(
        _ input: String
    ) -> Bool {
        let hasLetter = input.contains { $0.isASCII && $0.isLetter }
        let hasDigit = input.contains { $0.isASCII && $0.isNumber }
        return hasLetter && hasDigit
    }
}
