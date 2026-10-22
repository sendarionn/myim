/// The input the "もしかして" candidates are searched with
///
/// The reading for standard candidates stops at a symbol, so `a=to` is
/// read as `a`. When the symbols are only ones on or beside the long-vowel
/// key on the US layout, each between letters, the whole input is searched
/// instead, so `a=to` and `z=tp` can both reach `a-to`. Only corrections
/// that are dictionary words are offered, which keeps `foo=bar` uncorrected
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
            // Only between letters, where `-` makes a long vowel; a
            // trailing `=` and symbols next to each other stay as typed
            guard neighbors.contains(character),
                  index > 0,
                  characters[index - 1].isASCII,
                  characters[index - 1].isLetter,
                  index + 1 < characters.count,
                  characters[index + 1].isASCII,
                  characters[index + 1].isLetter else {
                return false
            }
            hasTypo = true
        }
        // Too short to be a word typed with a typo, such as `a=b`
        return hasTypo
            && characters.filter({ $0.isASCII && $0.isLetter }).count >= 3
    }
}
