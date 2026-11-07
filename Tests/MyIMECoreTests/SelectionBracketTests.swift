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

    private func choice(
        current: SelectionBracketPair = .standard
    ) -> SelectionBracketChoice {
        SelectionBracketChoice(
            applicationIdentifier: "com.apple.TextEdit",
            selectedRange: NSRange(location: 3, length: 3),
            selectedText: "テスト",
            current: current
        )
    }

    /// The panel opens on the pair chosen last and keys move around it
    @Test
    func choiceStartsAtTheCurrentPairAndWraps() {
        var choice = choice(current: SelectionBracketPair.all[11])
        #expect(choice.selectedIndex == 11)

        #expect(choice.handle(.next) == .moved)
        #expect(choice.selectedPair == .standard)

        #expect(choice.handle(.previous) == .moved)
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
