import Foundation

public struct RomajiConverter: Sendable {
    public init() {}

    public func hiragana(from input: String) -> String? {
        guard !input.isEmpty else {
            return nil
        }

        let source = Array(input.lowercased())
        var result = ""
        var index = 0

        while index < source.count {
            if source[index] == "-" {
                result.append("ー")
                index += 1
                continue
            }

            if index + 1 < source.count,
               source[index] == source[index + 1],
               isConsonant(source[index]),
               source[index] != "n" {
                result.append("っ")
                index += 1
                continue
            }

            if source[index] == "n" {
                if index + 1 == source.count {
                    result.append("ん")
                    index += 1
                    continue
                }
                let next = source[index + 1]
                if next == "'" {
                    result.append("ん")
                    index += 2
                    continue
                }
                if next == "n" || (isConsonant(next) && next != "y") {
                    result.append("ん")
                    index += next == "n" ? 1 : 1
                    continue
                }
            }

            var matched = false
            for length in stride(from: min(4, source.count - index), through: 1, by: -1) {
                let token = String(source[index..<(index + length)])
                if let kana = Self.mapping[token] {
                    result.append(kana)
                    index += length
                    matched = true
                    break
                }
            }
            if !matched {
                return nil
            }
        }

        return result
    }

    public func katakana(from input: String) -> String? {
        guard let hiragana = hiragana(from: input) else {
            return nil
        }

        return String(
            hiragana.unicodeScalars.map { scalar in
                if (0x3041...0x3096).contains(scalar.value),
                   let converted = UnicodeScalar(scalar.value + 0x60) {
                    return Character(converted)
                }
                return Character(scalar)
            }
        )
    }

    private func isConsonant(_ character: Character) -> Bool {
        character.isASCII
            && character.isLetter
            && !"aeiou".contains(character)
    }

    private static let mapping: [String: String] = [
        "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
        "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
        "kya": "きゃ", "kyu": "きゅ", "kyo": "きょ",
        "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
        "gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ",
        "sa": "さ", "shi": "し", "si": "し", "su": "す", "se": "せ", "so": "そ",
        "sha": "しゃ", "shu": "しゅ", "sho": "しょ",
        "sya": "しゃ", "syu": "しゅ", "syo": "しょ",
        "za": "ざ", "ji": "じ", "zi": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
        "ja": "じゃ", "ju": "じゅ", "jo": "じょ",
        "jya": "じゃ", "jyu": "じゅ", "jyo": "じょ",
        "ta": "た", "chi": "ち", "ti": "ち", "tsu": "つ", "tu": "つ", "te": "て", "to": "と",
        "cha": "ちゃ", "chu": "ちゅ", "cho": "ちょ",
        "tcha": "っちゃ", "tchu": "っちゅ", "tcho": "っちょ",
        "cya": "ちゃ", "cyu": "ちゅ", "cyo": "ちょ",
        "thi": "てぃ", "thu": "てゅ", "dhi": "でぃ", "dhu": "でゅ",
        "tsa": "つぁ", "tsi": "つぃ", "tse": "つぇ", "tso": "つぉ",
        "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
        "dya": "ぢゃ", "dyu": "ぢゅ", "dyo": "ぢょ",
        "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
        "nya": "にゃ", "nyu": "にゅ", "nyo": "にょ",
        "ha": "は", "hi": "ひ", "fu": "ふ", "hu": "ふ", "he": "へ", "ho": "ほ",
        "hya": "ひゃ", "hyu": "ひゅ", "hyo": "ひょ",
        "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
        "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
        "bya": "びゃ", "byu": "びゅ", "byo": "びょ",
        "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
        "pya": "ぴゃ", "pyu": "ぴゅ", "pyo": "ぴょ",
        "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        "mya": "みゃ", "myu": "みゅ", "myo": "みょ",
        "ya": "や", "yu": "ゆ", "yo": "よ",
        "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
        "rya": "りゃ", "ryu": "りゅ", "ryo": "りょ",
        "wa": "わ", "wi": "うぃ", "we": "うぇ", "wo": "を",
        "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
        "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
        "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ", "xtsu": "っ", "xtu": "っ",
        "la": "ぁ", "li": "ぃ", "lu": "ぅ", "le": "ぇ", "lo": "ぉ",
        "lya": "ゃ", "lyu": "ゅ", "lyo": "ょ", "ltsu": "っ", "ltu": "っ"
    ]
}

public enum JapaneseSymbolConverter {
    public static func candidates(for input: String) -> [String] {
        mapping[input] ?? []
    }

    private static let mapping: [String: [String]] = [
        ",": ["、", "，"],
        ".": ["。", "．", "…"],
        "/": ["・", "／"],
        "\\": ["￥", "＼"],
        "[": ["「", "『", "【", "［"],
        "]": ["」", "』", "】", "］"],
        "(": ["（"],
        ")": ["）"],
        "{": ["｛"],
        "}": ["｝"],
        "<": ["〈", "《", "＜"],
        ">": ["〉", "》", "＞"],
        "!": ["！"],
        "?": ["？"],
        ":": ["："],
        ";": ["；"],
        "~": ["〜", "～"],
        "-": ["ー", "−", "—"],
        "_": ["＿"],
        "\"": ["“", "”", "〝", "〟"],
        "'": ["‘", "’"],
        "...": ["…", "⋯"],
        "--": ["—", "−"]
    ]
}

public enum RomanizedReadingNormalizer {
    public static func dictionaryReading(from input: String) -> String {
        var normalized = input.lowercased()
        let protectedSyllables = [
            ("shu", "__MYIM_SHU__"),
            ("chu", "__MYIM_CHU__"),
            ("thu", "__MYIM_THU__"),
            ("dhu", "__MYIM_DHU__")
        ]
        for (syllable, placeholder) in protectedSyllables {
            normalized = normalized.replacingOccurrences(
                of: syllable,
                with: placeholder
            )
        }
        let aliases = [
            ("tu", "tsu"), ("hu", "fu"), ("si", "shi"),
            ("ti", "chi"), ("zi", "ji"),
            ("sya", "sha"), ("syu", "shu"), ("syo", "sho"),
            ("tya", "cha"), ("tyu", "chu"), ("tyo", "cho"),
            ("cya", "cha"), ("cyu", "chu"), ("cyo", "cho"),
            ("zya", "ja"), ("zyu", "ju"), ("zyo", "jo"),
            ("jya", "ja"), ("jyu", "ju"), ("jyo", "jo")
        ]
        for (source, destination) in aliases {
            normalized = normalized.replacingOccurrences(
                of: source,
                with: destination
            )
        }
        for (syllable, placeholder) in protectedSyllables {
            normalized = normalized.replacingOccurrences(
                of: placeholder,
                with: syllable
            )
        }

        var result = ""
        var lastVowel: Character?

        for character in normalized {
            if character == "-", let lastVowel {
                result.append(lastVowel)
                continue
            }
            result.append(character)
            if "aeiou".contains(character) {
                lastVowel = character
            }
        }

        return result
    }
}
