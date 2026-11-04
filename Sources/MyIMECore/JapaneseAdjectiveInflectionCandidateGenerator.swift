public struct JapaneseAdjectiveInflectionCandidateGenerator: Sendable {
    private struct Inflection: Sendable {
        let inputSuffix: String
        let surfaceSuffix: String
    }

    private static let inflections = [
        Inflection(
            inputSuffix: "kunakatta",
            surfaceSuffix: "くなかった"
        ),
        Inflection(inputSuffix: "katta", surfaceSuffix: "かった")
    ]

    private let dictionary: JapaneseAdjectiveDictionary

    public init(dictionary: JapaneseAdjectiveDictionary = .init()) {
        self.dictionary = dictionary
    }

    public func candidates(for input: String, limit: Int = 16) -> [String] {
        guard limit > 0 else { return [] }
        let input = RomajiCanonicalizer.canonicalInput(from: input)
        guard let inflection = Self.inflections.first(where: {
            input.hasSuffix($0.inputSuffix)
        }) else {
            return []
        }
        let stem = input.dropLast(inflection.inputSuffix.count)
        guard !stem.isEmpty else { return [] }
        let basicReading = String(stem) + "i"
        var results: [String] = []
        var seen = Set<String>()
        for surface in dictionary.surfaces(
            reading: basicReading,
            class: .iAdjective
        ) {
            guard surface.last == "い" else { continue }
            let inflected = surface.dropLast() + inflection.surfaceSuffix
            if seen.insert(String(inflected)).inserted {
                results.append(String(inflected))
            }
            if results.count >= limit { break }
        }
        return results
    }
}
