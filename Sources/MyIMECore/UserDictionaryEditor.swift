import Foundation

public enum UserDictionaryInputPolicy {
    public static func accepts(
        _ characters: String,
        hasCommandModifier: Bool,
        hasControlModifier: Bool
    ) -> Bool {
        guard !characters.isEmpty,
              !hasCommandModifier,
              !hasControlModifier else {
            return false
        }
        return characters.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0)
        }
    }
}

public enum UserDictionaryRegistrationReading {
    public static func resolve(
        conversionReading: String,
        originalInput: String
    ) -> String? {
        let conversion = conversionReading.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if !conversion.isEmpty {
            return conversion.lowercased()
        }
        let original = originalInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !original.isEmpty,
              !original.contains("\t"),
              !original.contains("\n") else {
            return nil
        }
        return original.lowercased()
    }
}

public enum UserDictionaryLookupReading {
    public static func resolve(
        conversionReading: String,
        originalInput: String
    ) -> String {
        conversionReading.isEmpty ? originalInput : conversionReading
    }
}

public struct UnselectedInputLearningEntry: Equatable, Sendable {
    public let reading: String
    public let candidate: String

    public init(reading: String, candidate: String) {
        self.reading = reading
        self.candidate = candidate
    }
}

public enum UnselectedInputLearningPolicy {
    public static func entry(
        originalInput: String,
        hasSelectedCandidate: Bool
    ) -> UnselectedInputLearningEntry? {
        guard !hasSelectedCandidate else { return nil }
        let trimmedInput = originalInput.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard !trimmedInput.isEmpty,
              !originalInput.contains("\t"),
              !originalInput.contains("\n"),
              !isSingleEnglishLetterOrSymbol(originalInput) else {
            return nil
        }
        return UnselectedInputLearningEntry(
            reading: originalInput.lowercased(),
            candidate: originalInput
        )
    }

    private static func isSingleEnglishLetterOrSymbol(_ input: String) -> Bool {
        guard input.count == 1 else { return false }
        let scalars = input.unicodeScalars
        let isEnglishLetter = scalars.count == 1 && scalars.allSatisfy {
            ("a"..."z").contains(Character(String($0).lowercased()))
        }
        let isSymbol = scalars.allSatisfy {
            CharacterSet.symbols.contains($0)
                || CharacterSet.punctuationCharacters.contains($0)
        }
        return isEnglishLetter || isSymbol
    }
}

public enum ConversionReadingSuffix {
    public static func resolve(
        conversionReading: String,
        originalInput: String
    ) -> String {
        guard !conversionReading.isEmpty else { return "" }
        return String(originalInput.dropFirst(conversionReading.count))
    }
}

public enum UserDictionaryEditor {
    public static func adding(
        reading: String,
        candidate: String,
        display: String? = nil,
        to entries: [DictionaryEntry]
    ) -> [DictionaryEntry] {
        let normalizedReading =
            RomajiCanonicalizer.canonicalInput(from: reading)
        let insertedValue = candidate.isEmpty ? (display ?? "") : candidate
        guard !normalizedReading.isEmpty, !insertedValue.isEmpty else {
            return entries
        }
        let storedCandidate: String
        if let display, !display.isEmpty, display != insertedValue {
            storedCandidate = DictionaryCandidateRepresentation.encoded(
                display: display,
                value: insertedValue
            ) ?? insertedValue
        } else {
            storedCandidate = insertedValue
        }

        var result = entries
        if let index = result.firstIndex(where: {
            RomajiCanonicalizer.canonicalInput(from: $0.input)
                == normalizedReading
        }) {
            var candidates = result[index].candidates
            if !candidates.contains(storedCandidate) {
                candidates.append(storedCandidate)
            }
            result[index] = DictionaryEntry(
                reading: result[index].reading,
                candidates: candidates
            )
        } else {
            result.append(
                DictionaryEntry(reading: reading, candidates: [storedCandidate])
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
            RomajiCanonicalizer.canonicalInput(from: $0)
        })
        guard !candidate.isEmpty, !normalizedReadings.isEmpty else {
            return entries
        }

        return entries.compactMap { entry in
            let normalizedReading =
                RomajiCanonicalizer.canonicalInput(
                    from: entry.input
                )
            guard normalizedReadings.contains(normalizedReading) else {
                return entry
            }
            let candidates = entry.candidates.filter {
                !matches(stored: $0, candidate: candidate)
            }
            guard !candidates.isEmpty else {
                return nil
            }
            return DictionaryEntry(
                input: entry.input,
                candidates: candidates
            )
        }
    }

    public static func removing(
        candidate: String,
        from entries: [DictionaryEntry]
    ) -> [DictionaryEntry] {
        guard !candidate.isEmpty else { return entries }

        return entries.compactMap { entry in
            let candidates = entry.candidates.filter {
                !matches(stored: $0, candidate: candidate)
            }
            guard !candidates.isEmpty else { return nil }
            return DictionaryEntry(
                input: entry.input,
                candidates: candidates
            )
        }
    }

    private static func matches(stored: String, candidate: String) -> Bool {
        stored == candidate
            || DictionaryCandidateRepresentation.display(from: stored) == candidate
            || DictionaryCandidateRepresentation.value(from: stored) == candidate
    }
}
