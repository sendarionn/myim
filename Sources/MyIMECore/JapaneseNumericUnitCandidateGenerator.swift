public enum JapaneseNumericUnitCandidateGenerator {
    private static let units: [(value: Int64, suffix: String)] = [
        (1_000, "千"),
        (10_000, "万"),
        (100_000_000, "億"),
        (1_000_000_000_000, "兆")
    ]
    private static let maximumCoefficient: Int64 = 9_999

    public static func candidates(for input: String) -> [String] {
        guard !input.isEmpty,
              input.allSatisfy({ $0.isASCII && $0.isNumber }),
              input.first != "0",
              let value = Int64(input),
              value > 0 else {
            return []
        }
        return units.compactMap { unit in
            guard value.isMultiple(of: unit.value) else { return nil }
            let coefficient = value / unit.value
            guard coefficient <= maximumCoefficient else { return nil }
            return "\(coefficient)\(unit.suffix)"
        }
    }
}
