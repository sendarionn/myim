import Foundation

enum RomajiKeyboardLayout: CaseIterable, Sendable {
    case us
    case jis
}

/// Physical key positions used only to score typo plausibility
///
/// Typos are judged on the US layout alone, so a JIS neighbour such as `@`
/// beside `p` never makes a correction cheap. Characters on one key, such as
/// `-` and `_`, are at distance 0
struct RomajiKeyboardGeometry {
    static let typoLayout: RomajiKeyboardLayout = .us

    private struct Position {
        let x: Double
        let y: Double
    }

    private static let positionsByLayout: [
        RomajiKeyboardLayout: [Character: Position]
    ] = Dictionary(uniqueKeysWithValues: RomajiKeyboardLayout.allCases.map {
        ($0, positions(for: $0))
    })
    static func distance(
        from source: Character,
        to target: Character,
        layout: RomajiKeyboardLayout
    ) -> Double? {
        guard let source = positionsByLayout[layout]?[source],
              let target = positionsByLayout[layout]?[target] else {
            return nil
        }
        return hypot(source.x - target.x, source.y - target.y)
    }

    /// Distance between the keys on the layout typos are judged on
    static func typoDistance(
        from source: Character,
        to target: Character
    ) -> Double? {
        distance(from: source, to: target, layout: typoLayout)
    }

    static func distanceFromLongVowelKey(
        _ character: Character
    ) -> Double? {
        typoDistance(from: character, to: "-")
    }

    /// Symbols sharing or touching the long-vowel key, such as `_` on it and
    /// `=` and `+` beside it, typed for `-` in a reading like `a-to`
    static let longVowelKeyNeighbors: Set<Character> = {
        guard let positions = positionsByLayout[typoLayout] else { return [] }
        return Set(positions.keys.filter { character in
            character != "-"
                && !character.isLetter
                && !character.isNumber
                && (distanceFromLongVowelKey(character) ?? .infinity) <= 1
        })
    }()

    private static func positions(
        for layout: RomajiKeyboardLayout
    ) -> [Character: Position] {
        var result: [Character: Position] = [:]
        func add(_ labels: String, x: Double, y: Double) {
            for character in labels {
                result[character] = Position(x: x, y: y)
            }
        }
        func addRow(
            _ keys: [String],
            xOffset: Double,
            y: Double
        ) {
            for (index, labels) in keys.enumerated() {
                add(labels, x: Double(index) + xOffset, y: y)
            }
        }

        addRow(Array("qwertyuiop").map(String.init), xOffset: 0, y: 0)
        addRow(Array("asdfghjkl").map(String.init), xOffset: 0.25, y: 1)
        addRow(Array("zxcvbnm").map(String.init), xOffset: 0.75, y: 2)

        switch layout {
        case .us:
            addRow(
                ["`~", "1!", "2@", "3#", "4$", "5%", "6^",
                 "7&", "8*", "9(", "0)", "-_", "=+"],
                xOffset: -1.25,
                y: -1
            )
            addRow(["[{", "]}", "\\|"], xOffset: 10, y: 0)
            addRow([";:", "'\""], xOffset: 9.25, y: 1)
        case .jis:
            addRow(
                ["1!", "2\"", "3#", "4$", "5%", "6&", "7'",
                 "8(", "9)", "0", "-=", "^~", "¥|"],
                xOffset: -0.25,
                y: -1
            )
            addRow(["@`", "[{"], xOffset: 10, y: 0)
            addRow([";:+*", "]}"], xOffset: 9.25, y: 1)
        }
        addRow([",<", ".>", "/?"], xOffset: 7.75, y: 2)
        return result
    }
}
