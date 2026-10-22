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
