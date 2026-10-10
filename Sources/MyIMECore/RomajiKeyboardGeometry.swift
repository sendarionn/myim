import Foundation

enum RomajiKeyboardLayout: CaseIterable, Sendable {
    case us
    case jis
}

/// Physical key positions used only to score typo plausibility
///
/// Both layouts are evaluated and the safer minimum distance is used because
/// an input method cannot reliably infer the attached hardware layout from a
/// text input source alone
struct RomajiKeyboardGeometry {
    private struct Position {
        let x: Double
        let y: Double
    }

    private static let positionsByLayout: [
        RomajiKeyboardLayout: [Character: Position]
    ] = Dictionary(uniqueKeysWithValues: RomajiKeyboardLayout.allCases.map {
        ($0, positions(for: $0))
    })
    private static let minimumDistances: [Character: [Character: Double]] = {
        var result: [Character: [Character: Double]] = [:]
        for positions in positionsByLayout.values {
            for (sourceCharacter, sourcePosition) in positions {
                for (targetCharacter, targetPosition) in positions {
                    let distance = hypot(
                        sourcePosition.x - targetPosition.x,
                        sourcePosition.y - targetPosition.y
                    )
                    result[sourceCharacter, default: [:]][targetCharacter] = min(
                        result[sourceCharacter]?[targetCharacter] ?? .infinity,
                        distance
                    )
                }
            }
        }
        return result
    }()

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

    static func minimumDistance(
        from source: Character,
        to target: Character
    ) -> Double? {
        minimumDistances[source]?[target]
    }

    static func distanceFromLongVowelKey(
        _ character: Character
    ) -> Double? {
        minimumDistance(from: character, to: "-")
    }

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
