import Foundation

public enum JapaneseNumberConverter {
    public static func candidates(for input: String) -> [String] {
        guard !input.isEmpty,
              input.allSatisfy(\.isNumber),
              input.allSatisfy({ $0.isASCII }),
              let value = Int(input),
              (0...20).contains(value),
              String(value) == input else {
            return []
        }

        var candidates = [circledNumber(value), fullWidthNumber(input)]
        candidates.append(contentsOf: kanjiNumbers[value] ?? [])
        return candidates.compactMap { $0 }
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
