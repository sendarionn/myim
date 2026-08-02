public enum UserDictionaryEditor {
    public static func adding(
        reading: String,
        candidate: String,
        to entries: [DictionaryEntry]
    ) -> [DictionaryEntry] {
        let normalizedReading =
            RomanizedReadingNormalizer.dictionaryReading(from: reading)
        guard !normalizedReading.isEmpty, !candidate.isEmpty else {
            return entries
        }

        var result = entries
        if let index = result.firstIndex(where: {
            RomanizedReadingNormalizer.dictionaryReading(from: $0.reading)
                == normalizedReading
        }) {
            var candidates = result[index].candidates
            if !candidates.contains(candidate) {
                candidates.append(candidate)
            }
            result[index] = DictionaryEntry(
                reading: result[index].reading,
                candidates: candidates
            )
        } else {
            result.append(
                DictionaryEntry(reading: reading, candidates: [candidate])
            )
        }
        return result
    }

    public static func removing(
        candidate: String,
        matchingReadings readings: [String],
        from entries: [DictionaryEntry]
    ) -> [DictionaryEntry] {
        let normalizedReadings = Set(readings.map {
            RomanizedReadingNormalizer.dictionaryReading(from: $0)
        })
        guard !candidate.isEmpty, !normalizedReadings.isEmpty else {
            return entries
        }

        return entries.compactMap { entry in
            let normalizedReading =
                RomanizedReadingNormalizer.dictionaryReading(
                    from: entry.reading
                )
            guard normalizedReadings.contains(normalizedReading) else {
                return entry
            }
            let candidates = entry.candidates.filter { $0 != candidate }
            guard !candidates.isEmpty else {
                return nil
            }
            return DictionaryEntry(
                reading: entry.reading,
                candidates: candidates
            )
        }
    }
}
