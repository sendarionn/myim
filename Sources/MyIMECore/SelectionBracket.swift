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
        // Second, next to the default, as it is used nearly as often
        .init(opening: "【", closing: "】"),
        .init(opening: "『", closing: "』"),
        .init(opening: "（", closing: "）"),
        .init(opening: "(", closing: ")"),
        .init(opening: "［", closing: "］"),
        .init(opening: "[", closing: "]"),
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

/// The brackets put around selections, most recently used first, kept
/// across launches. The one bracket kept before the history began starts it
public struct SelectionBracketPreference: @unchecked Sendable {
    /// The bracket chosen last, from before the history
    public static let defaultsKey = "SelectionBracketPair"
    public static let historyKey = "SelectionBracketHistory"
    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    /// Used brackets, newest first, each once
    public var history: [SelectionBracketPair] {
        if let labels = defaults.stringArray(forKey: Self.historyKey) {
            return labels.compactMap(SelectionBracketPair.pair(labeled:))
        }
        return defaults.string(forKey: Self.defaultsKey)
            .flatMap(SelectionBracketPair.pair(labeled:))
            .map { [$0] } ?? []
    }

    /// Every bracket, the used ones first by how recently, the rest in
    /// their usual order
    public var orderedPairs: [SelectionBracketPair] {
        let used = history
        return used + SelectionBracketPair.all.filter { !used.contains($0) }
    }

    /// The bracket chosen last
    public var pair: SelectionBracketPair {
        history.first ?? .standard
    }

    /// A bracket put around a selection goes to the front
    public func remember(_ pair: SelectionBracketPair) {
        let labels = ([pair] + history.filter { $0 != pair })
            .prefix(SelectionBracketPair.all.count)
            .map(\.label)
        defaults.set(Array(labels), forKey: Self.historyKey)
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
    /// The brackets in the order shown, fixed while the panel is open
    public let pairs: [SelectionBracketPair]
    public private(set) var selectedIndex = 0

    /// Opens on the first of `pairs`, the one used last
    public init(
        applicationIdentifier: String?,
        selectedRange: NSRange,
        selectedText: String,
        pairs: [SelectionBracketPair] = SelectionBracketPair.all
    ) {
        self.applicationIdentifier = applicationIdentifier
        self.selectedRange = selectedRange
        self.selectedText = selectedText
        self.pairs = pairs.isEmpty ? SelectionBracketPair.all : pairs
    }

    public var labels: [String] { pairs.map(\.label) }

    public var selectedPair: SelectionBracketPair {
        pairs[selectedIndex]
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
        let count = pairs.count
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
