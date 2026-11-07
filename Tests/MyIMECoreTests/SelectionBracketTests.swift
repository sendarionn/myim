import Foundation
import Testing
@testable import MyIMECore

@Suite
struct SelectionBracketTests {
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
            ("「", "」"), ("『", "』"), ("（", "）"), ("(", ")"),
            ("［", "］"), ("[", "]"), ("【", "】"), ("｛", "｝"),
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

    @Test
    func remembersTheLastChosenPair() throws {
        let suite = "SelectionBracketTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let preference = SelectionBracketPreference(defaults: defaults)

        #expect(preference.pair == .standard)

        preference.remember(SelectionBracketPair.all[6])

        #expect(SelectionBracketPreference(defaults: defaults).pair.label
            == "【】")

        defaults.set("unknown", forKey: SelectionBracketPreference.defaultsKey)
        #expect(preference.pair == .standard)
    }

    @Test
    func choiceStartsAtTheCurrentPairAndWraps() {
        var choice = SelectionBracketChoice(
            selectedRange: NSRange(location: 3, length: 2),
            current: SelectionBracketPair.all[11]
        )
        #expect(choice.selectedIndex == 11)

        choice.move(by: 1)
        #expect(choice.selectedPair == .standard)

        choice.move(by: -1)
        #expect(choice.selectedPair.label == "“”")
        #expect(choice.labels.count == 12)
    }

    /// The choice applies only to the selection it was opened for
    @Test
    func choiceAppliesOnlyToTheSameSelection() {
        let choice = SelectionBracketChoice(
            selectedRange: NSRange(location: 3, length: 2),
            current: .standard
        )

        #expect(choice.appliesTo(currentRange: NSRange(location: 3, length: 2)))
        #expect(!choice.appliesTo(currentRange: NSRange(location: 3, length: 0)))
        #expect(!choice.appliesTo(currentRange: NSRange(location: 4, length: 2)))
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
