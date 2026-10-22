import Testing
@testable import MyIMECore

@Suite
struct SequentialConversionSplitTests {
    @Test(arguments: [
        ("watashiha,", "watashiha", ","),
        ("tokyo.", "tokyo", "."),
        ("sugoi!", "sugoi", "!"),
        ("nani?", "nani", "?"),
        ("watashiha!?", "watashiha", "!?"),
        ("example.com.", "example.com", "."),
        ("su-pa-.", "su-pa-", ".")
    ])
    func separatesTrailingPunctuationFromTheText(
        input: String,
        body: String,
        punctuation: String
    ) {
        #expect(SequentialConversionSplit.split(input)
            == SequentialConversionSplit(unit: body, remainder: punctuation))
    }

    @Test(arguments: [
        "example.com", "3.14", "hello,world", "yu-za-", ",", "!?",
        "100.", "e.g", "watashiha", "14:30"
    ])
    func keepsInputWithoutTrailingTextPunctuation(input: String) {
        #expect(SequentialConversionSplit.split(input) == nil)
    }

    @Test
    func carriedGroupWithoutCandidatesConvertsOneCharacterAtATime() {
        #expect(SequentialConversionSplit.split(
            "!?",
            isCarried: true
        ) == SequentialConversionSplit(unit: "!", remainder: "?"))
        #expect(SequentialConversionSplit.split(
            "!?",
            isCarried: true,
            convertsAsGroup: { _ in true }
        ) == nil)
        #expect(SequentialConversionSplit.split(
            ",",
            isCarried: true
        ) == nil)
    }

    /// Mirrors InputController: commit the text, carry the punctuation,
    /// then commit a symbol candidate for each step in typed order
    @Test(arguments: [
        ("watashiha,", "私は", ["、"], "私は、"),
        ("watashiha!?", "私は", ["！", "？"], "私は！？"),
        ("tokyo.", "東京", ["。"], "東京。")
    ])
    func commitsTheTextThenEachPunctuationInOrder(
        input: String,
        convertedBody: String,
        symbols: [String],
        expected: String
    ) throws {
        let split = try #require(SequentialConversionSplit.split(input))
        var session = InputSession()
        var committed = convertedBody
        session.carryRemainder(split.remainder)

        for symbol in symbols {
            let carried = SequentialConversionSplit.split(
                session.input,
                isCarried: true,
                convertsAsGroup: {
                    !JapaneseSymbolConverter.candidates(for: $0).isEmpty
                }
            )
            let target = carried?.unit ?? session.input
            #expect(JapaneseSymbolConverter.candidates(for: target)
                .contains(symbol))
            committed += symbol
            session.clear()
            if let rest = carried?.remainder {
                session.carryRemainder(rest)
            }
        }

        #expect(committed == expected)
        #expect(session.input.isEmpty)
    }

    /// The input already holds the punctuation, so only a selected
    /// candidate gets it appended for display
    @Test(arguments: [
        ("watashiha,", "私は", "私は,", ","),
        ("tokyo.", "東京", "東京.", "."),
        ("watashiha!?", "私は", "私は!?", "!?")
    ])
    func showsTrailingPunctuationOnceAtEveryStep(
        input: String,
        converted: String,
        selectedText: String,
        carriedText: String
    ) throws {
        let split = try #require(SequentialConversionSplit.split(input))

        #expect(CandidateSelectionProjection.unconvertedMarkedText(
            input: input
        ) == input)
        #expect(CandidateSelectionProjection.markedText(
            for: Candidate(storageText: converted),
            suffix: split.remainder
        ) == selectedText)

        var session = InputSession()
        session.carryRemainder(split.remainder)

        #expect(CandidateSelectionProjection.unconvertedMarkedText(
            input: session.input
        ) == carriedText)
    }

    @Test
    func carriedGroupShowsTheRestOnceAfterTheSelectedSymbol() throws {
        let carried = try #require(SequentialConversionSplit.split(
            "!?",
            isCarried: true
        ))

        #expect(CandidateSelectionProjection.unconvertedMarkedText(
            input: "!?"
        ) == "!?")
        #expect(CandidateSelectionProjection.markedText(
            for: Candidate(storageText: "！"),
            suffix: carried.remainder
        ) == "！?")
    }

    @Test
    func carriedPunctuationLastsUntilTheInputIsEdited() {
        var session = InputSession()
        session.carryRemainder("!?")

        #expect(session.input == "!?")
        #expect(session.carriesRemainder)

        session.insert("a")

        #expect(!session.carriesRemainder)

        session.carryRemainder(",")
        session.clear()

        #expect(!session.carriesRemainder)
    }

    // MARK: Numbers and symbols

    /// Every split keeps the input whole and in order
    @Test(arguments: [
        ("123+456", ["123", "+", "456"]),
        ("100*200", ["100", "*", "200"]),
        ("123#456", ["123", "#", "456"]),
        ("100cm+200cm", ["100cm", "+", "200cm"]),
        ("watashiha,100!", ["watashiha", ",", "100", "!"]),
        ("1+2+3", ["1", "+", "2", "+", "3"]),
        ("123+-456", ["123", "+", "-", "456"]),
        ("123#", ["123", "#"]),
        ("watashiha!?", ["watashiha", "!", "?"])
    ])
    func splitsIntoUnitsFromTheFront(input: String, units: [String]) {
        #expect(Self.units(of: input) == units)
        #expect(Self.units(of: input).joined() == input)
    }

    /// Input whose symbols belong to it, or that a conversion takes whole
    @Test(arguments: [
        "14:30", "3.14", "1,000", "1,00", "100cm", "1nin", "1+2=",
        "2026/10/22", "2026-10-22", "example.com", "user@example.com",
        "a-to", "a=to", "foo=bar", "c++", "hello,world", "kana"
    ])
    func keepsInputWithoutAUnitBoundaryWhole(input: String) {
        #expect(SequentialConversionSplit.split(input) == nil)
    }

    /// A number, unit, or registered word taken whole is not split even
    /// when it has a symbol beside a number
    @Test
    func keepsWhatAConversionTakesWhole() {
        #expect(SequentialConversionSplit.split(
            "123+456",
            convertsAsWhole: { $0 == "123+456" }
        ) == nil)
        // The remainder after a committed unit is split without that check
        #expect(SequentialConversionSplit.split(
            "456!",
            isCarried: true,
            convertsAsWhole: { _ in true }
        ) == SequentialConversionSplit(unit: "456", remainder: "!"))
    }

    /// Mirrors InputController: each step commits a candidate for the unit
    /// and carries the rest, so nothing is lost or committed twice
    @Test(arguments: [
        ("123+456", ["１２３", "＋", "四五六"], "１２３＋四五六"),
        ("100cm+200cm", ["100cm", "+", "200cm"], "100cm+200cm"),
        ("watashiha,100!", ["私は", "、", "100", "！"], "私は、100！")
    ])
    func commitsEachUnitInOrderOnce(
        input: String,
        converted: [String],
        expected: String
    ) {
        var session = InputSession()
        session.setInput(input)
        var committed = ""
        var steps = 0

        while !session.input.isEmpty, steps < converted.count {
            let split = SequentialConversionSplit.split(
                session.input,
                isCarried: session.carriesRemainder
            )
            committed += converted[steps]
            steps += 1
            session.clear()
            if let remainder = split?.remainder {
                session.carryRemainder(remainder)
            }
        }

        #expect(committed == expected)
        #expect(steps == converted.count)
        #expect(session.input.isEmpty)
        #expect(!session.carriesRemainder)
    }

    /// Editing the carried rest makes it ordinary input, checked again
    /// as a whole
    @Test
    func editedRemainderIsCheckedAsTypedInput() {
        var session = InputSession()
        session.carryRemainder("+456")
        #expect(SequentialConversionSplit.split(
            session.input,
            isCarried: session.carriesRemainder
        )?.unit == "+")

        session.insert("7")

        #expect(!session.carriesRemainder)
        #expect(SequentialConversionSplit.split(
            session.input,
            isCarried: session.carriesRemainder
        ) == nil)
    }

    private static func units(of input: String) -> [String] {
        var units: [String] = []
        var rest = input
        var isCarried = false
        while let split = SequentialConversionSplit.split(
            rest,
            isCarried: isCarried
        ) {
            units.append(split.unit)
            rest = split.remainder
            isCarried = true
        }
        units.append(rest)
        return units
    }
}
