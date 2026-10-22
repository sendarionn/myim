/// The input the "もしかして" candidates are searched with
///
/// The reading for standard candidates stops at a symbol, so `a=to` is
/// read as `a`. When the symbols are only ones on or beside the long-vowel
/// key on the US layout and putting `-` in their place gives a whole
/// romaji reading, as `a-to` is, the whole input is searched instead
public enum FuzzyQueryResolver {
    public static func resolve(
        input: String,
        conversionReading: String
    ) -> String {
        guard conversionReading.count < input.count,
              isLongVowelKeyTypo(input) else {
            return conversionReading
        }
        return input
    }

    /// Standard candidates a fuzzy candidate would only repeat. When the
    /// whole input is searched, the standard candidates are for the reading
    /// before the symbol, so アート completing `a` commits `アート=to` while
    /// アート correcting `a=to` commits アート; both stay
    public static func duplicateCandidates(
        standardCandidates: [String],
        query: String,
        conversionReading: String
    ) -> Set<String> {
        query == conversionReading ? Set(standardCandidates) : []
    }

    /// Text left after a fuzzy candidate: none when the whole input was
    /// searched, so `=to` is not left after アート
    public static func suffix(
        input: String,
        query: String,
        conversionReading: String,
        conversionSuffix: String
    ) -> String {
        query == conversionReading
            ? conversionSuffix
            : String(input.dropFirst(query.count))
    }

    private static func isLongVowelKeyTypo(_ input: String) -> Bool {
        let characters = Array(input.lowercased())
        let neighbors = RomajiKeyboardGeometry.longVowelKeyNeighbors
        var hasTypo = false
        for (index, character) in characters.enumerated() {
            if character.isASCII && character.isLetter
                || character == "-" || character == "'" {
                continue
            }
            // Only between a vowel and the next letter, where `-` makes a
            // long vowel; `a=b`, `x+y`, and a trailing `=` stay as typed
            guard neighbors.contains(character),
                  index > 0, "aeiou".contains(characters[index - 1]),
                  index + 1 < characters.count,
                  characters[index + 1].isASCII,
                  characters[index + 1].isLetter else {
                return false
            }
            hasTypo = true
        }
        guard hasTypo else { return false }
        let corrected = String(characters.map {
            neighbors.contains($0) ? "-" : $0
        })
        // Every letter has to become kana, so `foo=bar` is not a reading
        guard let kana = RomajiConverter().hiragana(from: corrected) else {
            return false
        }
        return !kana.contains { $0.isASCII && $0.isLetter }
    }
}
