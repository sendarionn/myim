import Foundation

/// The typed letters as the live conversion engine reads them. The engine
/// keeps -, comma and period as typed, which reads ko-hi- as こ-ひ-; here a
/// hyphen after romaji becomes ー as in ordinary conversion, and a comma or
/// period after romaji, or after such a ー, becomes 、 or 。. After digits
/// or letters that are not romaji, as in 3.14, 1,000 and example.com, they
/// stay as typed. Letters are read as romaji in lower case, as ordinary
/// conversion reads them, so Kyou reads きょう; a word of letters that is
/// not romaji, as iPhone or example, is kept as typed, and the converter
/// converts the rest around it. A finished word may be read differently
/// from while it was typed, and the converter then starts over
public enum LiveConversionInput {
    public struct Element: Equatable, Sendable {
        public let text: String
        /// Read as romaji; otherwise taken as it is
        public let isRomaji: Bool

        public init(text: String, isRomaji: Bool) {
            self.text = text
            self.isRomaji = isRomaji
        }
    }

    /// How far the engine read the letters as kana
    public enum Reading: Equatable, Sendable {
        /// All of them: a conversion of it can be shown
        case converted
        /// Romaji still being typed at the end, as the k of かk
        case typingRomaji
        /// Romaji left in the middle that the converter did not read
        case notRomaji
    }

    /// How far `reading` is read, apart from the words of `elements` kept
    /// as typed
    public static func reading(_ reading: String, elements: [Element] = []) -> Reading {
        var scalars = Array(reading.unicodeScalars)
        var searchStart = 0
        for kept in elements where !kept.isRomaji {
            let keptScalars = Array(kept.text.unicodeScalars)
            guard keptScalars.contains(where: isLetter),
                  let start = firstIndex(of: keptScalars, in: scalars, from: searchStart)
            else { continue }
            for index in start..<(start + keptScalars.count) {
                scalars[index] = " "
            }
            searchStart = start + keptScalars.count
        }
        let unread = scalars.map(isLetter)
        guard let firstUnread = unread.firstIndex(of: true) else { return .converted }
        return unread[firstUnread...].allSatisfy { $0 } ? .typingRomaji : .notRomaji
    }

    private static func isLetter(_ scalar: Unicode.Scalar) -> Bool {
        scalar.isASCII && CharacterSet.letters.contains(scalar)
    }

    private static func firstIndex(
        of part: [Unicode.Scalar],
        in whole: [Unicode.Scalar],
        from start: Int
    ) -> Int? {
        guard !part.isEmpty, whole.count >= part.count, start <= whole.count - part.count
        else { return nil }
        return (start...(whole.count - part.count)).first {
            Array(whole[$0..<($0 + part.count)]) == part
        }
    }

    public static func elements(
        for typed: String,
        converter: RomajiConverter = RomajiConverter()
    ) -> [Element] {
        let characters = Array(typed)
        var elements: [Element] = []
        var afterRomaji = false
        var followsKana = false
        var index = 0
        while index < characters.count {
            if characters[index].isASCII, characters[index].isLetter {
                var end = index
                while end < characters.count, characters[end].isASCII, characters[end].isLetter {
                    end += 1
                }
                let word = String(characters[index..<end])
                let isLast = end == characters.count
                let romaji = word.lowercased()
                // The last word may still be romaji being typed, as ky
                afterRomaji = converter.hiragana(from: romaji) != nil
                    || (isLast && converter.hiragana(from: romaji + "a") != nil)
                if afterRomaji {
                    elements += romaji.map { Element(text: String($0), isRomaji: true) }
                    // An n before what is not a letter is ん, as ordinary
                    // conversion reads nihon2026, where the converter
                    // waits for the letter after it
                    let trailingN = romaji.reversed().prefix { $0 == "n" }.count
                    if !isLast, !trailingN.isMultiple(of: 2) {
                        elements.append(Element(text: "n", isRomaji: true))
                    }
                } else {
                    elements.append(Element(text: word, isRomaji: false))
                }
                followsKana = false
                index = end
                continue
            }
            let character = characters[index]
            let inKana = afterRomaji || followsKana
            let replacement: String? = switch character {
            case "-" where inKana: "ー"
            case "," where inKana: "、"
            case "." where inKana: "。"
            default: nil
            }
            afterRomaji = false
            followsKana = replacement == "ー"
            elements.append(Element(text: replacement ?? String(character), isRomaji: false))
            index += 1
        }
        return elements
    }
}
