/// Input converted one unit at a time from the front: `watashiha,`
/// becomes 私は and then 、, and `123+456` becomes 123, then +, then 456,
/// without retyping the rest
///
/// Only symbols are split at, and only where the symbol cannot belong to
/// the words around it, so `example.com`, `3.14`, `14:30`, `a-to`, and
/// `hello,world` stay whole. Input the existing conversions take as a whole,
/// such as `1,000`, `100cm`, or `1+2=`, is not split either
public struct SequentialConversionSplit: Equatable, Sendable {
    /// Punctuation split off the end of a word
    public static let trailingPunctuation: Set<Character> = [
        ",", ".", "!", "?"
    ]
    /// Symbols joining the words around them, as in domains, times, dates,
    /// decimals, mail addresses, paths, and long vowels
    static let connectors: Set<Character> = [
        ".", ":", "/", "@", "_", "'", "-", "\\"
    ]

    /// The unit converted now
    public let unit: String
    /// Input after the unit, carried over once the unit is committed
    public let remainder: String

    public init(unit: String, remainder: String) {
        self.unit = unit
        self.remainder = remainder
    }

    /// - Parameters:
    ///   - isCarried: The input is the remainder left after a committed
    ///     unit, so it is split again without checking it as a whole
    ///   - convertsAsWhole: Typed input an existing conversion takes as a
    ///     whole, such as a dictionary word, a number, or a calculation
    ///   - convertsAsGroup: Symbols converted together, such as `!?`
    public static func split(
        _ input: String,
        isCarried: Bool = false,
        convertsAsWhole: (String) -> Bool = { _ in false },
        convertsAsGroup: (String) -> Bool = { _ in false }
    ) -> Self? {
        let characters = Array(input)
        guard characters.count > 1,
              !characters.contains(where: \.isWhitespace) else {
            return nil
        }
        if isCarried, isSymbol(characters[0]) {
            return splitLeadingSymbols(
                characters,
                convertsAsGroup: convertsAsGroup
            )
        }
        guard !isSymbol(characters[0]),
              let index = firstBoundary(in: characters) else {
            return nil
        }
        if !isCarried {
            // A calculation, mail address, or whole conversion stays one unit
            guard characters.last != "=",
                  !characters.contains("@"),
                  !convertsAsWhole(input) else {
                return nil
            }
        }
        return Self(
            unit: String(characters[..<index]),
            remainder: String(characters[index...])
        )
    }

    /// What Return commits and what is left for the next step: the
    /// selected candidate or, with none selected, the unit as typed, so
    /// `123+456` goes on to `+` either way. Input of one unit is committed
    /// whole as before
    public static func returnCommit(
        input: String,
        split: Self?,
        selectedValue: String?
    ) -> (text: String, remainder: String) {
        if let selectedValue {
            return (selectedValue, split?.remainder ?? "")
        }
        guard let split else { return (input, "") }
        return (split.unit, split.remainder)
    }

    /// Symbols left first after a committed unit convert together when
    /// they have candidates as a group, and otherwise one at a time
    private static func splitLeadingSymbols(
        _ characters: [Character],
        convertsAsGroup: (String) -> Bool
    ) -> Self? {
        let run = characters.prefix(while: isSymbol)
        let unitLength: Int
        if run.count > 1, convertsAsGroup(String(run)) {
            unitLength = run.count
        } else {
            unitLength = 1
        }
        guard unitLength < characters.count else { return nil }
        return Self(
            unit: String(characters.prefix(unitLength)),
            remainder: String(characters.dropFirst(unitLength))
        )
    }

    private static func firstBoundary(in characters: [Character]) -> Int? {
        for index in 1..<characters.count {
            let character = characters[index]
            let previous = characters[index - 1]
            // A run of symbols is split at its start; a long vowel or
            // apostrophe before it belongs to the word
            guard isSymbol(character),
                  !isSymbol(previous) || connectors.contains(previous) else {
                continue
            }
            if characters[index...].allSatisfy(trailingPunctuation.contains) {
                // Punctuation ending a word, or ! and ? after a number;
                // `100.` and `1,` may still become `100.5` and `1,000`
                if isWordCharacter(previous)
                    || previous.isNumber && "!?".contains(character) {
                    return index
                }
                return nil
            }
            guard !connectors.contains(character) else { continue }
            let next = index + 1 < characters.count
                ? characters[index + 1]
                : nil
            // `1,0` may still become `1,000`
            if character == ",", previous.isNumber, next?.isNumber == true {
                continue
            }
            // A symbol between letters may be a word or a typo such as
            // `a=to`, so only one beside a number is split at
            if previous.isNumber || next?.isNumber == true {
                return index
            }
        }
        return nil
    }

    private static func isWordCharacter(_ character: Character) -> Bool {
        character.isASCII && character.isLetter || character == "-"
    }

    static func isSymbol(_ character: Character) -> Bool {
        character.isASCII
            && !character.isLetter
            && !character.isNumber
            && !character.isWhitespace
    }
}
