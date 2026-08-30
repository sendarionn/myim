import Foundation

public enum JapaneseNumberConverter {
    public static func candidates(for input: String) -> [String] {
        guard !input.isEmpty,
              input.allSatisfy(\.isNumber),
              input.allSatisfy({ $0.isASCII }),
              let value = UInt64(input),
              String(value) == input else {
            return []
        }

        var candidates = [input]
        if let circled = Int(exactly: value).flatMap(circledNumber) {
            candidates.append(circled)
        }
        candidates.append(fullWidthNumber(input))
        if let smallValue = Int(exactly: value),
           let smallCandidates = kanjiNumbers[smallValue] {
            candidates.append(contentsOf: smallCandidates)
        } else if let kanji = kanjiNumber(value) {
            candidates.append(kanji)
        }
        return candidates
    }

    public static func kanjiCandidates(for input: String) -> [String] {
        guard !input.isEmpty,
              input.allSatisfy({ $0.isASCII && $0.isNumber }),
              let value = UInt64(input),
              String(value) == input,
              let kanji = kanjiNumber(value) else {
            return []
        }
        return [kanji]
    }

    private static func circledNumber(_ value: Int) -> String? {
        if value == 0 {
            return "⓪"
        }
        guard (1...20).contains(value),
              let scalar = UnicodeScalar(0x2460 + value - 1) else {
            return nil
        }
        return String(Character(scalar))
    }

    private static func fullWidthNumber(_ input: String) -> String {
        String(input.compactMap { character -> Character? in
            guard let value = character.wholeNumberValue,
                  let scalar = UnicodeScalar(0xFF10 + value) else {
                return nil
            }
            return Character(scalar)
        })
    }

    private static func kanjiNumber(_ value: UInt64) -> String? {
        if value == 0 {
            return "零"
        }
        let largeUnits = ["", "万", "億", "兆", "京"]
        var remaining = value
        var groupIndex = 0
        var result = ""
        while remaining > 0 {
            guard groupIndex < largeUnits.count else { return nil }
            let group = Int(remaining % 10_000)
            if group > 0 {
                result = kanjiGroup(group) + largeUnits[groupIndex] + result
            }
            remaining /= 10_000
            groupIndex += 1
        }
        return result
    }

    private static func kanjiGroup(_ value: Int) -> String {
        let digits = ["", "一", "二", "三", "四", "五", "六", "七", "八", "九"]
        let units = ["千", "百", "十", ""]
        let divisors = [1_000, 100, 10, 1]
        return zip(divisors, units).reduce(into: "") { result, pair in
            let digit = value / pair.0 % 10
            guard digit > 0 else { return }
            if digit != 1 || pair.0 == 1 {
                result += digits[digit]
            }
            result += pair.1
        }
    }

    private static let kanjiNumbers: [Int: [String]] = [
        0: ["零", "〇"],
        1: ["一", "壱"],
        2: ["二", "弐"],
        3: ["三", "参"],
        4: ["四"],
        5: ["五"],
        6: ["六"],
        7: ["七"],
        8: ["八"],
        9: ["九"],
        10: ["十", "拾"],
        11: ["十一"],
        12: ["十二"],
        13: ["十三"],
        14: ["十四"],
        15: ["十五"],
        16: ["十六"],
        17: ["十七"],
        18: ["十八"],
        19: ["十九"],
        20: ["二十"]
    ]
}
