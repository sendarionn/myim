import Testing
@testable import MyIMECore

@Suite
struct MoraicNInputFormToggleTests {
    /// Presses the keys in turn the way F6 and F7 do, each showing the
    /// conversion of the reading the toggle gives
    private func shown(
        _ forms: [InputForm],
        reading: String,
        toggle: inout MoraicNInputFormToggle
    ) -> [String] {
        var selected: String?
        return forms.map { form in
            let converted = InputFormConverter.convert(
                toggle.reading(for: form, of: reading, selectedText: selected),
                to: form
            ) ?? ""
            toggle.didShow(converted)
            selected = converted
            return converted
        }
    }

    @Test(arguments: [
        ([InputForm.hiragana, .hiragana, .hiragana], ["しにゃ", "しんや", "しにゃ"]),
        ([.fullWidthKatakana, .fullWidthKatakana, .fullWidthKatakana],
         ["シニャ", "シンヤ", "シニャ"]),
        ([.fullWidthKatakana, .fullWidthKatakana, .hiragana],
         ["シニャ", "シンヤ", "しんや"])
    ])
    func repeatedKeySwitchesTheReadingOfNy(
        forms: [InputForm],
        expected: [String]
    ) {
        var toggle = MoraicNInputFormToggle()

        #expect(shown(forms, reading: "shinya", toggle: &toggle) == expected)
    }

    @Test(arguments: [
        ("konnyaku", "こんにゃく"),
        ("shin'ya", "しんや"),
        ("nyuugaku", "にゅうがく")
    ])
    func readingWithoutNyAfterAVowelStaysAsTyped(
        reading: String,
        expected: String
    ) {
        var toggle = MoraicNInputFormToggle()

        #expect(shown(
            [.hiragana, .hiragana, .hiragana],
            reading: reading,
            toggle: &toggle
        ) == [expected, expected, expected])
    }

    /// A new composition, an edit or another candidate chosen in between
    /// starts from the reading as typed again
    @Test
    func startsOverOnceTheShownTextIsNoLongerSelected() {
        var toggle = MoraicNInputFormToggle()
        _ = shown([.hiragana, .hiragana], reading: "shinya", toggle: &toggle)

        let afterOtherCandidate = toggle.reading(
            for: .hiragana,
            of: "shinya",
            selectedText: "深夜"
        )
        let afterCommit = toggle.reading(
            for: .hiragana,
            of: "shinya",
            selectedText: nil
        )

        #expect(afterOtherCandidate == "shinya")
        #expect(afterCommit == "shinya")
    }

    @Test
    func otherFormsUseTheReadingAsTypedAndStartOver() {
        var toggle = MoraicNInputFormToggle()
        _ = shown([.hiragana, .hiragana], reading: "shinya", toggle: &toggle)

        #expect(toggle.reading(
            for: .halfWidthKatakana,
            of: "shinya",
            selectedText: "しんや"
        ) == "shinya")
        #expect(shown([.hiragana], reading: "shinya", toggle: &toggle)
            == ["しにゃ"])
    }
}
