import Foundation

/// The typed letters as the live conversion engine reads them. The engine
/// keeps -, comma and period as typed, which reads ko-hi- as こ-ひ-; here a
/// hyphen after romaji becomes ー as in ordinary conversion, and a comma or
/// period after romaji, or after such a ー, becomes 、 or 。. After digits
/// or letters that are not romaji, as in 3.14, 1,000 and example.com, they
/// stay as typed. Each depends only on what comes before it, so typing on
/// never changes what an earlier symbol became
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
        /// Letters left in the middle that are not romaji, as in
        /// example.com, where a conversion would garble the word
        case notRomaji
    }

    public static func reading(_ reading: String) -> Reading {
        let unread = reading.unicodeScalars.map { $0.isASCII && CharacterSet.letters.contains($0) }
        guard let firstUnread = unread.firstIndex(of: true) else { return .converted }
        return unread[firstUnread...].allSatisfy { $0 } ? .typingRomaji : .notRomaji
    }

    public static func elements(
        for typed: String,
        converter: RomajiConverter = RomajiConverter()
    ) -> [Element] {
        var elements: [Element] = []
        var letters = ""
        var followsKana = false
        for character in typed {
            if character.isASCII, character.isLetter {
                letters.append(character)
                elements.append(Element(text: String(character), isRomaji: true))
                continue
            }
            let afterRomaji = !letters.isEmpty && converter.hiragana(from: letters) != nil
            let inKana = afterRomaji || (letters.isEmpty && followsKana)
            let replacement: String? = switch character {
            case "-" where inKana: "ー"
            case "," where inKana: "、"
            case "." where inKana: "。"
            default: nil
            }
            letters = ""
            followsKana = replacement == "ー"
            elements.append(Element(text: replacement ?? String(character), isRomaji: false))
        }
        return elements
    }
}
