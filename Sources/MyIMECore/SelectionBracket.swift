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
    /// `NSTextInputClient` uses this sentinel to replace its current
    /// selection. This lets the client perform the replacement as normal
    /// text input and place the caret after the inserted text
    public static let currentSelectionReplacementRange = NSRange(
        location: NSNotFound,
        length: NSNotFound
    )

    /// The collapsed selection expected after replacing `selectedRange`
    /// with a wrapped string of `wrappedLength` UTF-16 code units
    public static func expectedCaretRange(
        afterReplacing selectedRange: NSRange,
        wrappedLength: Int
    ) -> NSRange {
        NSRange(
            location: selectedRange.location + wrappedLength,
            length: 0
        )
    }

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

/// What a key does while the brackets are being chosen
public enum SelectionBracketCommand: Equatable, Sendable {
    case previous
    case next
    case apply
    case cancel
}

/// Choosing a bracket for the selection captured when the panel opened;
/// the brackets go in only while the same application still has the same
/// text selected
public struct SelectionBracketChoice: Equatable, Sendable {
    public enum Outcome: Equatable, Sendable {
        case moved
        case apply(SelectionBracketPair)
        case cancel
    }

    public let applicationIdentifier: String?
    public let selectedRange: NSRange
    public let selectedText: String
    public private(set) var selectedIndex: Int

    public init(
        applicationIdentifier: String?,
        selectedRange: NSRange,
        selectedText: String,
        current: SelectionBracketPair
    ) {
        self.applicationIdentifier = applicationIdentifier
        self.selectedRange = selectedRange
        self.selectedText = selectedText
        selectedIndex = SelectionBracketPair.all.firstIndex(of: current) ?? 0
    }

    public var labels: [String] { SelectionBracketPair.all.map(\.label) }

    public var selectedPair: SelectionBracketPair {
        SelectionBracketPair.all[selectedIndex]
    }

    public mutating func handle(_ command: SelectionBracketCommand) -> Outcome {
        switch command {
        case .previous:
            move(by: -1)
            return .moved
        case .next:
            move(by: 1)
            return .moved
        case .apply:
            return .apply(selectedPair)
        case .cancel:
            return .cancel
        }
    }

    /// Moves through the pairs, wrapping at either end
    public mutating func move(by offset: Int) {
        let count = SelectionBracketPair.all.count
        selectedIndex = ((selectedIndex + offset) % count + count) % count
    }

    public func appliesTo(
        applicationIdentifier: String?,
        range: NSRange,
        text: String
    ) -> Bool {
        applicationIdentifier == self.applicationIdentifier
            && range == selectedRange
            && text == selectedText
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
