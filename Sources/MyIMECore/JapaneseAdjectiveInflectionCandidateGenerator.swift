public struct JapaneseAdjectiveInflectionCandidateGenerator: Sendable {
    private struct Inflection: Sendable {
        let inputSuffix: String
        let surfaceSuffix: String
    }

    private static let inflections = [
        Inflection(
            inputSuffix: "kunakunatta",
            surfaceSuffix: "くなくなった"
        ),
        Inflection(
            inputSuffix: "kunakunaru",
            surfaceSuffix: "くなくなる"
        ),
        Inflection(
            inputSuffix: "kunakereba",
            surfaceSuffix: "くなければ"
        ),
        Inflection(
            inputSuffix: "kunakatta",
            surfaceSuffix: "くなかった"
        ),
        Inflection(
            inputSuffix: "kunakute",
            surfaceSuffix: "くなくて"
        ),
        Inflection(inputSuffix: "kattara", surfaceSuffix: "かったら"),
        Inflection(inputSuffix: "kereba", surfaceSuffix: "ければ"),
        Inflection(inputSuffix: "kutemo", surfaceSuffix: "くても"),
        Inflection(inputSuffix: "kunai", surfaceSuffix: "くない"),
        Inflection(inputSuffix: "katta", surfaceSuffix: "かった"),
        Inflection(inputSuffix: "kute", surfaceSuffix: "くて"),
        Inflection(inputSuffix: "ku", surfaceSuffix: "く")
    ]

    private let dictionary: JapaneseAdjectiveDictionary

    public init(dictionary: JapaneseAdjectiveDictionary = .init()) {
        self.dictionary = dictionary
    }

    public func candidates(for input: String, limit: Int = 16) -> [String] {
        generatedCandidates(for: input, limit: limit).map(\.text)
    }

    public func generatedCandidates(
        for input: String,
        limit: Int = 16
    ) -> [GeneratedInflectionCandidate] {
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
        // いい uses the よい series; do not derive it from ikereba or ikunai
        guard basicReading != "ii" else { return [] }
        var results: [GeneratedInflectionCandidate] = []
        var seen = Set<String>()
        for surface in dictionary.surfaces(
            reading: basicReading,
            class: .iAdjective
        ) {
            guard surface.last == "い" else { continue }
            let inflected = surface.dropLast() + inflection.surfaceSuffix
            if seen.insert(String(inflected)).inserted {
                results.append(GeneratedInflectionCandidate(
                    text: String(inflected),
                    bases: [InflectionBaseIdentity(
                        kind: .adjective,
                        reading: basicReading,
                        surface: surface,
                        inflectionType: JapaneseAdjectiveClass.iAdjective.rawValue
                    )]
                ))
            }
            if results.count >= limit { break }
        }
        return results
    }
}
