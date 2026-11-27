import Foundation
import Testing
@testable import MyIMECore

@Suite
struct SelectionBracketTests {
    @Test func currentSelectionReplacementUsesInputMethodSentinel() {
        #expect(
            SelectionBracketWrapper.currentSelectionReplacementRange
                == NSRange(location: NSNotFound, length: NSNotFound)
        )
    }

    @Test func expectedCaretIsAfterWrappedUTF16Text() {
        let selectedRange = NSRange(location: 4, length: 3)
        let wrapped = NSAttributedString(string: "「絵文字😀」")

        #expect(
            SelectionBracketWrapper.expectedCaretRange(
                afterReplacing: selectedRange,
                wrappedLength: wrapped.length
            ) == NSRange(location: 11, length: 0)
        )
    }

    @Test(arguments: ["文章", "こんにちは", "abc 123", "1行目\n2行目", "👨‍👩‍👧 が", "e\u{301}t\u{301}e\u{301}"])
    func wrapsTheWholeSelectionWithoutChangingIt(text: String) throws {
        let wrapped = try #require(SelectionBracketWrapper.wrapped(
            NSAttributedString(string: text),
            in: .standard
        ))

        #expect(wrapped.string == "「" + text + "」")
        #expect(wrapped.string.dropFirst().dropLast() == Substring(text))
    }

    @Test
    func everyPairOpensAndClosesInOrder() {
        let pairs = SelectionBracketPair.all.map { ($0.opening, $0.closing) }
        let expected = [
            ("「", "」"), ("【", "】"), ("『", "』"), ("（", "）"),
            ("(", ")"), ("［", "］"), ("[", "]"), ("｛", "｝"),
            ("{", "}"), ("〈", "〉"), ("《", "》"), ("“", "”")
        ]
        #expect(pairs.count == expected.count)
        for (pair, expectation) in zip(pairs, expected) {
            #expect(pair == expectation)
        }
        #expect(SelectionBracketPair.standard.label == "「」")
    }

    @Test
    func bracketsTakeTheFormattingBesideThem() throws {
        let style = NSAttributedString.Key("style")
        let selection = NSMutableAttributedString(
            string: "太字",
            attributes: [style: "bold"]
        )
        selection.append(NSAttributedString(
            string: "大",
            attributes: [style: "large"]
        ))

        let wrapped = try #require(SelectionBracketWrapper.wrapped(
            selection,
            in: .standard
        ))

        #expect(wrapped.attribute(style, at: 0, effectiveRange: nil)
            as? String == "bold")
        #expect(wrapped.attribute(style, at: 1, effectiveRange: nil)
            as? String == "bold")
        #expect(wrapped.attribute(
            style,
            at: wrapped.length - 1,
            effectiveRange: nil
        ) as? String == "large")
    }

    @Test
    func emptySelectionIsNotWrapped() {
        #expect(SelectionBracketWrapper.wrapped(
            NSAttributedString(string: ""),
            in: .standard
        ) == nil)
    }

    private func preference() throws -> (SelectionBracketPreference, UserDefaults, String) {
        let suite = "SelectionBracketTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        return (SelectionBracketPreference(defaults: defaults), defaults, suite)
    }

    /// Used brackets come first, newest first and each once, the rest in
    /// their usual order, and stay across launches
    @Test
    func recentlyUsedPairsComeFirst() throws {
        let (preference, defaults, suite) = try preference()
        defer { defaults.removePersistentDomain(forName: suite) }
        #expect(preference.orderedPairs == SelectionBracketPair.all)
        #expect(preference.pair == .standard)

        for label in ["【】", "（）", "「」"] {
            preference.remember(try #require(SelectionBracketPair.pair(labeled: label)))
        }
        let labels = SelectionBracketPreference(defaults: defaults).orderedPairs.map(\.label)
        #expect(Array(labels.prefix(4)) == ["「」", "（）", "【】", "『』"])
        #expect(labels.count == 12)
        #expect(Set(labels).count == 12)

        preference.remember(try #require(SelectionBracketPair.pair(labeled: "【】")))
        #expect(Array(preference.orderedPairs.map(\.label).prefix(3)) == ["【】", "「」", "（）"])
        #expect(preference.history.count == 3)
    }

    /// The one bracket kept before the history starts it
    @Test
    func theBracketChosenBeforeStartsTheHistory() throws {
        let (preference, defaults, suite) = try preference()
        defer { defaults.removePersistentDomain(forName: suite) }
        defaults.set("『』", forKey: SelectionBracketPreference.defaultsKey)
        #expect(preference.orderedPairs.first?.label == "『』")
        defaults.set("unknown", forKey: SelectionBracketPreference.defaultsKey)
        #expect(preference.orderedPairs == SelectionBracketPair.all)
    }

    private func choice(
        pairs: [SelectionBracketPair] = SelectionBracketPair.all
    ) -> SelectionBracketChoice {
        SelectionBracketChoice(
            applicationIdentifier: "com.apple.TextEdit",
            selectedRange: NSRange(location: 3, length: 3),
            selectedText: "テスト",
            pairs: pairs
        )
    }

    /// The panel opens on the first pair, the one used last, and keys move
    /// through the pairs in their order, wrapping
    @Test
    func choiceStartsAtTheFirstPairAndWraps() {
        let pairs = Array(SelectionBracketPair.all.reversed())
        var choice = choice(pairs: pairs)
        #expect(choice.selectedPair.label == "“”")
        #expect(choice.handle(.previous) == .moved)
        #expect(choice.selectedPair == .standard)
        #expect(choice.handle(.next) == .moved)
        #expect(choice.selectedPair.label == "“”")
        #expect(choice.labels.count == 12)
    }

    @Test
    func enterAppliesTheSelectedPairAndEscCancels() {
        var choice = choice()
        _ = choice.handle(.next)

        #expect(choice.handle(.apply) == .apply(SelectionBracketPair.all[1]))
        #expect(choice.handle(.cancel) == .cancel)
    }

    /// 【】 is one step from the default 「」
    @Test
    func lenticularBracketsFollowTheDefault() {
        #expect(SelectionBracketPair.all.map(\.label).prefix(2) == ["「」", "【】"])
        #expect(SelectionBracketPair.all.count == 12)
        var choice = choice()
        _ = choice.handle(.next)
        #expect(choice.handle(.apply) == .apply(SelectionBracketPair.pair(labeled: "【】")!))
    }

    /// The brackets go in only where the panel was opened
    @Test
    func choiceAppliesOnlyToTheSameSelection() {
        let choice = choice()
        let range = NSRange(location: 3, length: 3)

        #expect(choice.appliesTo(
            applicationIdentifier: "com.apple.TextEdit",
            range: range,
            text: "テスト"
        ))
        #expect(!choice.appliesTo(
            applicationIdentifier: "com.google.Chrome",
            range: range,
            text: "テスト"
        ))
        #expect(!choice.appliesTo(
            applicationIdentifier: "com.apple.TextEdit",
            range: NSRange(location: 4, length: 3),
            text: "テスト"
        ))
        #expect(!choice.appliesTo(
            applicationIdentifier: "com.apple.TextEdit",
            range: range,
            text: "てすと"
        ))
    }

    @Test
    func findsAnotherFeatureUsingTheShortcut() {
        let assignments = [("calendar", "option+c"), ("bracket", "option+q")]

        #expect(ShortcutConflict.conflictingFeature(
            for: "option+c",
            assignedTo: "bracket",
            among: assignments
        ) == "calendar")
        #expect(ShortcutConflict.conflictingFeature(
            for: "option+q",
            assignedTo: "bracket",
            among: assignments
        ) == nil)
        #expect(ShortcutConflict.conflictingFeature(
            for: "option+shift+q",
            assignedTo: "bracket",
            among: assignments
        ) == nil)
    }
}
