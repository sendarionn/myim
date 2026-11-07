import Foundation

/// A pair of brackets put around the selected text
public struct SelectionBracketPair: Equatable, Sendable {
    public let opening: String
    public let closing: String

    public init(opening: String, closing: String) {
        self.opening = opening
        self.closing = closing
    }

    /// Shown in the candidate panel and kept as the remembered choice
    public var label: String { opening + closing }

    public static let all: [SelectionBracketPair] = [
        .init(opening: "「", closing: "」"),
        .init(opening: "『", closing: "』"),
        .init(opening: "（", closing: "）"),
        .init(opening: "(", closing: ")"),
        .init(opening: "［", closing: "］"),
        .init(opening: "[", closing: "]"),
        .init(opening: "【", closing: "】"),
        .init(opening: "｛", closing: "｝"),
        .init(opening: "{", closing: "}"),
        .init(opening: "〈", closing: "〉"),
        .init(opening: "《", closing: "》"),
        .init(opening: "“", closing: "”")
    ]

    public static let standard = all[0]

    public static func pair(labeled label: String) -> SelectionBracketPair? {
        all.first { $0.label == label }
    }
}

public enum SelectionBracketWrapper {
    /// The selection with the brackets around it; each bracket takes the
    /// formatting of the character it sits next to, so styled text keeps
    /// its look where the application accepts attributes
    public static func wrapped(
        _ selection: NSAttributedString,
        in pair: SelectionBracketPair
    ) -> NSAttributedString? {
        guard selection.length > 0 else { return nil }
        let result = NSMutableAttributedString(
            string: pair.opening,
            attributes: selection.attributes(at: 0, effectiveRange: nil)
        )
        result.append(selection)
        result.append(NSAttributedString(
            string: pair.closing,
            attributes: selection.attributes(
                at: selection.length - 1,
                effectiveRange: nil
            )
        ))
        return result
    }
}

/// The bracket the shortcut puts around a selection, the one chosen last
public struct SelectionBracketPreference: @unchecked Sendable {
    public static let defaultsKey = "SelectionBracketPair"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var pair: SelectionBracketPair {
        defaults.string(forKey: Self.defaultsKey)
            .flatMap(SelectionBracketPair.pair(labeled:))
            ?? .standard
    }

    public func remember(_ pair: SelectionBracketPair) {
        defaults.set(pair.label, forKey: Self.defaultsKey)
    }
}

/// Choosing a bracket for the selection captured when the panel opened;
/// the selection must still be the same when the choice is made
public struct SelectionBracketChoice: Equatable, Sendable {
    public let selectedRange: NSRange
    public private(set) var selectedIndex: Int

    public init(selectedRange: NSRange, current: SelectionBracketPair) {
        self.selectedRange = selectedRange
        selectedIndex = SelectionBracketPair.all.firstIndex(of: current) ?? 0
    }

    public var labels: [String] { SelectionBracketPair.all.map(\.label) }

    public var selectedPair: SelectionBracketPair {
        SelectionBracketPair.all[selectedIndex]
    }

    /// Moves through the pairs, wrapping at either end
    public mutating func move(by offset: Int) {
        let count = SelectionBracketPair.all.count
        selectedIndex = ((selectedIndex + offset) % count + count) % count
    }

    public func appliesTo(currentRange: NSRange) -> Bool {
        currentRange == selectedRange
    }
}

public enum ShortcutConflict {
    /// The first other feature already using the shortcut
    public static func conflictingFeature<Feature: Equatable>(
        for storageValue: String,
        assignedTo feature: Feature,
        among assignments: [(Feature, String)]
    ) -> Feature? {
        assignments.first {
            $0.0 != feature && $0.1 == storageValue
        }?.0
    }
}
