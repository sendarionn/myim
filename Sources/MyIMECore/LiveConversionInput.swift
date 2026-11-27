import Foundation

/// The typed letters as the live conversion engine reads them. The engine
/// keeps -, comma and period as typed, which reads ko-hi- as こ-ひ-; here a
/// hyphen after romaji becomes ー as in ordinary conversion, and a comma or
/// period after romaji, or after such a ー, becomes 、 or 。. After digits
/// or letters that are not romaji, as in 3.14, 1,000 and example.com, they
/// stay as typed. Letters are read as romaji in lower case, as ordinary
/// conversion reads them, so Kyou reads きょう; a word of letters that is
/// not romaji, as iPhone or example, is kept as typed, and the converter
/// converts the rest around it. ん is read as ordinary conversion reads it
/// (`romajiElements`). A finished word may be read differently from while
/// it was typed, and the converter then starts over
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

    /// About how many kana the typed letters read as, without the converter,
    /// to decide whether live conversion starts: each word of letters as
    /// ordinary conversion reads it, the last one less the romaji still
    /// being typed, as the k of kyouk, a word that is not romaji as none,
    /// and a hyphen after romaji as ー
    public static func kanaCount(
        of typed: String,
        converter: RomajiConverter = RomajiConverter()
    ) -> Int {
        var count = 0
        var word = ""
        var afterRomaji = false
        func countWord(isLast: Bool) {
            defer { word = "" }
            guard !word.isEmpty else { return }
            let romaji = word.lowercased()
            if let kana = converter.hiragana(from: romaji) {
                count += kana.count
                afterRomaji = true
            } else if isLast, let kana = converter.hiragana(from: romaji + "a") {
                count += kana.count - 1
                afterRomaji = true
            } else {
                afterRomaji = false
            }
        }
        for character in typed {
            if character.isASCII, character.isLetter {
                word.append(character)
                continue
            }
            countWord(isLast: false)
            if character == "-", afterRomaji {
                count += 1
            } else {
                afterRomaji = false
            }
        }
        countWord(isLast: true)
        return count
    }

    /// Romaji as ordinary conversion reads ん, for the converter, which
    /// reads nn as ん and so konna as こんあ: an n before an n, or at the end
    /// of the letters, is ん and goes as nn, so konna reads こんな and nihon2026
    /// にほん2026; an n after such an n at the end waits for a vowel and goes
    /// as nothing yet, so kann reads かん and kanno かんの
    private static func romajiElements(_ romaji: String) -> [Element] {
        let letters = Array(romaji)
        var elements: [Element] = []
        for (index, letter) in letters.enumerated() {
            guard letter == "n" else {
                elements.append(Element(text: String(letter), isRomaji: true))
                continue
            }
            let next = index + 1 < letters.count ? letters[index + 1] : nil
            if next == "n" {
                elements.append(Element(text: "nn", isRomaji: true))
            } else if next == nil {
                if index == 0 || letters[index - 1] != "n" {
                    elements.append(Element(text: "nn", isRomaji: true))
                }
            } else {
                elements.append(Element(text: "n", isRomaji: true))
            }
        }
        return elements
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
                    elements += romajiElements(romaji)
                } else {
                    elements.append(Element(text: word, isRomaji: false))
                }
                followsKana = false
                index = end
                continue
            }
            let character = characters[index]
            // n' only separates ん from what follows, which the n before it
            // already says
            if character == "'", afterRomaji, elements.last?.text.hasSuffix("n") == true {
                index += 1
                continue
            }
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
