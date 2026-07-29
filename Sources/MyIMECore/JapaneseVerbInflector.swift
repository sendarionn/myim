public enum JapaneseVerbInflector {
    public static func teFormCandidates(
        for reading: String,
        lookup: (String) -> [String]
    ) -> [String] {
        guard reading.hasSuffix("tte") else {
            return []
        }

        let stem = String(reading.dropLast(3))
        let baseReadings = [stem, stem + "ru"]
        var seen = Set<String>()
        return baseReadings
            .flatMap(lookup)
            .compactMap { candidate in
                guard let last = candidate.last,
                      ["う", "つ", "る"].contains(last) else {
                    return nil
                }
                let value = String(candidate.dropLast()) + "って"
                return seen.insert(value).inserted ? value : nil
            }
    }
}
