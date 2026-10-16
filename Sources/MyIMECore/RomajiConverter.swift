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
                if next == "-" {
                    result.append("ん")
                    index += 1
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

    fileprivate static let mapping: [String: String] = [
        "a": "あ", "i": "い", "u": "う", "e": "え", "o": "お",
        "ka": "か", "ki": "き", "ku": "く", "ke": "け", "ko": "こ",
        "kya": "きゃ", "kyu": "きゅ", "kyo": "きょ",
        "kye": "きぇ",
        "kwa": "くぁ", "kwi": "くぃ", "kwe": "くぇ", "kwo": "くぉ",
        "ga": "が", "gi": "ぎ", "gu": "ぐ", "ge": "げ", "go": "ご",
        "gya": "ぎゃ", "gyu": "ぎゅ", "gyo": "ぎょ",
        "gye": "ぎぇ",
        "gwa": "ぐぁ", "gwi": "ぐぃ", "gwe": "ぐぇ", "gwo": "ぐぉ",
        "sa": "さ", "shi": "し", "si": "し", "su": "す", "se": "せ", "so": "そ",
        "sha": "しゃ", "shu": "しゅ", "she": "しぇ", "sho": "しょ",
        "sya": "しゃ", "syu": "しゅ", "syo": "しょ",
        "za": "ざ", "ji": "じ", "zi": "じ", "zu": "ず", "ze": "ぜ", "zo": "ぞ",
        "ja": "じゃ", "ju": "じゅ", "je": "じぇ", "jo": "じょ",
        "jya": "じゃ", "jyu": "じゅ", "jyo": "じょ",
        "ta": "た", "chi": "ち", "ti": "ち", "tsu": "つ", "tu": "つ", "te": "て", "to": "と",
        "cha": "ちゃ", "chu": "ちゅ", "che": "ちぇ", "cho": "ちょ",
        "tcha": "っちゃ", "tchu": "っちゅ", "tcho": "っちょ",
        "cya": "ちゃ", "cyu": "ちゅ", "cyo": "ちょ",
        "tha": "てゃ", "thi": "てぃ", "thu": "てゅ", "the": "てぇ", "tho": "てょ",
        "dha": "でゃ", "dhi": "でぃ", "dhu": "でゅ", "dhe": "でぇ", "dho": "でょ",
        "twa": "とぁ", "twi": "とぃ", "twu": "とぅ", "twe": "とぇ", "two": "とぉ",
        "dwa": "どぁ", "dwi": "どぃ", "dwu": "どぅ", "dwe": "どぇ", "dwo": "どぉ",
        "tsa": "つぁ", "tsi": "つぃ", "tse": "つぇ", "tso": "つぉ",
        "da": "だ", "di": "ぢ", "du": "づ", "de": "で", "do": "ど",
        "dya": "ぢゃ", "dyu": "ぢゅ", "dyo": "ぢょ",
        "na": "な", "ni": "に", "nu": "ぬ", "ne": "ね", "no": "の",
        "nya": "にゃ", "nyu": "にゅ", "nye": "にぇ", "nyo": "にょ",
        "ha": "は", "hi": "ひ", "fu": "ふ", "hu": "ふ", "he": "へ", "ho": "ほ",
        "hya": "ひゃ", "hyu": "ひゅ", "hye": "ひぇ", "hyo": "ひょ",
        "fa": "ふぁ", "fi": "ふぃ", "fe": "ふぇ", "fo": "ふぉ",
        "ba": "ば", "bi": "び", "bu": "ぶ", "be": "べ", "bo": "ぼ",
        "bya": "びゃ", "byu": "びゅ", "bye": "びぇ", "byo": "びょ",
        "pa": "ぱ", "pi": "ぴ", "pu": "ぷ", "pe": "ぺ", "po": "ぽ",
        "pya": "ぴゃ", "pyu": "ぴゅ", "pye": "ぴぇ", "pyo": "ぴょ",
        "ma": "ま", "mi": "み", "mu": "む", "me": "め", "mo": "も",
        "mya": "みゃ", "myu": "みゅ", "mye": "みぇ", "myo": "みょ",
        "ya": "や", "yu": "ゆ", "ye": "いぇ", "yo": "よ",
        "ra": "ら", "ri": "り", "ru": "る", "re": "れ", "ro": "ろ",
        "rya": "りゃ", "ryu": "りゅ", "rye": "りぇ", "ryo": "りょ",
        "wa": "わ", "wi": "うぃ", "we": "うぇ", "wo": "を",
        "wha": "うぁ", "whi": "うぃ", "whe": "うぇ", "who": "うぉ",
        "va": "ゔぁ", "vi": "ゔぃ", "vu": "ゔ", "ve": "ゔぇ", "vo": "ゔぉ",
        "xa": "ぁ", "xi": "ぃ", "xu": "ぅ", "xe": "ぇ", "xo": "ぉ",
        "xya": "ゃ", "xyu": "ゅ", "xyo": "ょ", "xtsu": "っ", "xtu": "っ",
        "xwa": "ゎ", "xka": "ゕ", "xke": "ゖ",
        "la": "ぁ", "li": "ぃ", "lu": "ぅ", "le": "ぇ", "lo": "ぉ",
        "lya": "ゃ", "lyu": "ゅ", "lyo": "ょ", "ltsu": "っ", "ltu": "っ"
    ]
}

enum KanaReadingDictionaryKey {
    static func value(from reading: String) -> String? {
        guard !reading.isEmpty else { return nil }
        let source = Array(reading)
        var result = ""
        var index = 0
        var geminate = false

        while index < source.count {
            let character = source[index]
            if character == "っ" {
                geminate = true
                index += 1
                continue
            }
            if character == "ー" {
                result.append("-")
                index += 1
                continue
            }
            if character == "ん" {
                let following = index + 1 < source.count
                    ? String(source[index + 1])
                    : ""
                let followingRomaji = reverseMapping[following] ?? ""
                result += followingRomaji.first.map {
                    "aeiouy".contains($0) ? "n'" : "n"
                } ?? "n"
                index += 1
                continue
            }

            let pair = index + 1 < source.count
                ? String(source[index...index + 1])
                : ""
            let romaji: String
            if let pairRomaji = reverseMapping[pair] {
                romaji = pairRomaji
                index += 2
            } else {
                guard let singleRomaji = reverseMapping[String(character)] else {
                    return nil
                }
                romaji = singleRomaji
                index += 1
            }
            if geminate {
                result.append(romaji.hasPrefix("ch") ? "t" : romaji.first!)
                geminate = false
            }
            result += romaji
        }

        if geminate {
            result += "xtsu"
        }
        return result
    }

    private static let reverseMapping: [String: String] = {
        var result: [String: String] = [:]
        for (romaji, kana) in RomajiConverter.mapping
        where kana != "っ" && !kana.hasPrefix("っ") {
            let canonical = RomajiCanonicalizer.canonicalInput(from: romaji)
            if let current = result[kana] {
                if canonical.count < current.count
                    || (canonical.count == current.count && canonical < current) {
                    result[kana] = canonical
                }
            } else {
                result[kana] = canonical
            }
        }
        return result
    }()
}

public enum JapaneseSymbolConverter {
    public static func candidates(for input: String) -> [String] {
        (mapping[input] ?? []).filter { $0 != input }
    }

    private static let mapping: [String: [String]] = [
        "zh": ["←"],
        "zj": ["↓"],
        "zk": ["↑"],
        "zl": ["→"],
        ",": [",", "、", "，"],
        ".": [".", "。", "．", "…"],
        "/": ["/", "・", "･", "／"],
        "\\": ["\\", "￥", "＼"],
        "[": ["[", "「", "［", "『", "【"],
        "]": ["]", "」", "］", "』", "】"],
        "(": ["(", "（", "「", "『"],
        ")": [")", "）", "」", "』"],
        "{": ["{", "｛", "【"],
        "}": ["}", "｝", "】"],
        "<": ["<", "＜", "〈", "《"],
        ">": [">", "＞", "〉", "》"],
        "!": ["!", "！"],
        "?": ["?", "？"],
        ":": [":", "："],
        ";": [";", "；"],
        "~": ["~", "〜", "～"],
        "-": ["ー", "-", "－", "―", "−", "—"],
        "_": ["_", "＿"],
        "\"": ["\"", "＂", "“", "”", "〝", "〟"],
        "'": ["'", "＇", "‘", "’"],
        "#": ["#", "＃", "♯"],
        "$": ["$", "＄", "￥"],
        "%": ["%", "％"],
        "&": ["&", "＆"],
        "*": ["*", "＊", "※"],
        "+": ["+", "＋"],
        "=": ["=", "＝", "≒", "≠"],
        "@": ["@", "＠"],
        "^": ["^", "＾"],
        "`": ["`", "｀"],
        "|": ["|", "｜"],
        "...": ["...", "…", "⋯"],
        "--": ["--", "—", "―", "−"]
    ]
}

public enum RomajiCanonicalizer {
    public static func dictionaryLookupInputs(
        from input: String
    ) -> [String] {
        exactLookupInputs(from: input)
    }

    public static func exactLookupInputs(from input: String) -> [String] {
        unexpandedLookupInputs(from: input)
    }

    public static func legacyLongVowelLookupInputs(
        from input: String
    ) -> [String] {
        var inputs = unexpandedLookupInputs(from: input)
        for value in inputs {
            let expanded = longVowelInput(from: value)
            if expanded != value, !inputs.contains(expanded) {
                inputs.append(expanded)
            }
        }
        return inputs
    }

    public static func longVowelNotationPreservingLookupInputs(
        from input: String
    ) -> [String] {
        guard input.contains("-") else { return [] }
        return unexpandedLookupInputs(from: input)
    }

    private static func unexpandedLookupInputs(from input: String) -> [String] {
        let raw = input.lowercased()
        let canonical = canonicalInput(from: raw)
        var inputs = raw == canonical ? [raw] : [raw, canonical]
        let hyphenCanonical = canonicalHyphenatedInput(from: raw)
        if hyphenCanonical != raw, !inputs.contains(hyphenCanonical) {
            inputs.append(hyphenCanonical)
        }
        for value in inputs {
            let moraicN = moraicNBeforeYInput(from: value)
            if moraicN != value, !inputs.contains(moraicN) {
                inputs.append(moraicN)
            }
        }
        return inputs
    }

    /// Readings that take an `n` between vowels as ん, as dictionaries key
    /// 順位 as `jun'i` while `juni` reads じゅに; only exact matches use
    /// them, after those of the reading as typed
    public static func moraicNBeforeVowelLookupInputs(
        from input: String
    ) -> [String] {
        let inputs = dictionaryLookupInputs(from: input)
        var result: [String] = []
        for value in inputs {
            let moraicN = moraicNBeforeVowelInput(from: value)
            if moraicN != value,
               !inputs.contains(moraicN),
               !result.contains(moraicN) {
                result.append(moraicN)
            }
        }
        return result
    }

    private static func canonicalHyphenatedInput(from input: String) -> String {
        guard input.contains("-") else { return input }
        return input.split(
            separator: "-",
            omittingEmptySubsequences: false
        ).map {
            canonicalInput(from: String($0))
        }.joined(separator: "-")
    }

    private static func longVowelInput(from input: String) -> String {
        var result = ""
        for character in input {
            guard character == "-" else {
                result.append(character)
                continue
            }
            guard let previous = result.last,
                  "aeiou".contains(previous) else {
                return input
            }
            result.append(previous)
        }
        return result
    }

    /// Reads an `n` between vowels as ん, as dictionaries key 単位 as
    /// `tan'i` and 原因 as `gen'in`
    private static func moraicNBeforeVowelInput(from input: String) -> String {
        let characters = Array(input)
        guard characters.count >= 3 else { return input }
        var result = ""
        for index in characters.indices {
            let character = characters[index]
            if character == "n",
               index > characters.startIndex,
               index + 1 < characters.endIndex,
               "aeiou".contains(characters[index + 1]),
               "aeiou".contains(characters[index - 1]) {
                result.append("n'")
            } else {
                result.append(character)
            }
        }
        return result
    }

    private static func moraicNBeforeYInput(from input: String) -> String {
        let characters = Array(input)
        guard characters.count >= 3 else { return input }
        var result = ""
        for index in characters.indices {
            let character = characters[index]
            if character == "n",
               index > characters.startIndex,
               index + 1 < characters.endIndex,
               characters[index + 1] == "y",
               "aeiou".contains(characters[index - 1]) {
                result.append("n'")
            } else {
                result.append(character)
            }
        }
        return result
    }

    public static func canonicalInput(from input: String) -> String {
        let source = Array(input.lowercased())
        var result = ""
        var index = 0

        while index < source.count {
            if source[index] == "-" {
                return input.lowercased()
            }

            if index + 1 < source.count,
               source[index] == source[index + 1],
               isConsonant(source[index]),
               source[index] != "n" {
                result.append(source[index])
                index += 1
                continue
            }

            if source[index] == "n" {
                if index + 1 == source.count {
                    result.append("n")
                    index += 1
                    continue
                }
                let next = source[index + 1]
                if next == "'" {
                    result.append("n'")
                    index += 2
                    continue
                }
                if next == "n" || (isConsonant(next) && next != "y") {
                    result.append("n")
                    index += 1
                    continue
                }
            }

            var match: String?
            for length in stride(
                from: min(4, source.count - index),
                through: 1,
                by: -1
            ) {
                let token = String(source[index..<(index + length)])
                if RomajiConverter.mapping[token] != nil {
                    match = token
                    index += length
                    break
                }
            }
            guard let match else { return input.lowercased() }
            let canonical = aliases[match] ?? match
            result.append(canonical)
        }

        return result
    }

    private static let aliases: [String: String] = [
        "si": "shi", "ti": "chi", "tu": "tsu", "hu": "fu",
        "du": "zu",
        "sya": "sha", "syu": "shu", "syo": "sho",
        "tya": "cha", "tyu": "chu", "tyo": "cho",
        "cya": "cha", "cyu": "chu", "cyo": "cho",
        "zi": "ji", "zya": "ja", "zyu": "ju", "zyo": "jo",
        "jya": "ja", "jyu": "ju", "jyo": "jo"
    ]

    private static func isConsonant(_ character: Character) -> Bool {
        character.isASCII
            && character.isLetter
            && !"aeiou".contains(character)
    }

}

public enum LongVowelNotationCandidateFilter {
    public static func candidates(
        _ candidates: [String],
        for input: String,
        preserving preservedCandidates: Set<String> = []
    ) -> [String] {
        let normalized = input.lowercased()
        guard normalized.count > 1,
              normalized.allSatisfy({
                  $0.isASCII && ($0.isLetter || $0 == "-" || $0 == "'")
              }) else {
            return candidates
        }
        if normalized.contains("-") {
            return candidates.filter {
                $0.contains("ー") || preservedCandidates.contains($0)
            }
        }
        return candidates.filter {
            !$0.contains("ー") || preservedCandidates.contains($0)
        }
    }
}
