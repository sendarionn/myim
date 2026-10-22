import Testing
@testable import MyIMECore

@Suite
struct TrailingPunctuationSplitTests {
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
        #expect(TrailingPunctuationSplit.split(input)
            == TrailingPunctuationSplit(body: body, punctuation: punctuation))
    }

    @Test(arguments: [
        "example.com", "3.14", "hello,world", "yu-za-", ",", "!?",
        "100.", "e.g", "watashiha", "14:30"
    ])
    func keepsInputWithoutTrailingTextPunctuation(input: String) {
        #expect(TrailingPunctuationSplit.split(input) == nil)
    }

    @Test
    func carriedGroupWithoutCandidatesConvertsOneCharacterAtATime() {
        #expect(TrailingPunctuationSplit.splitCarried(
            "!?",
            convertsAsGroup: false
        ) == TrailingPunctuationSplit(body: "!", punctuation: "?"))
        #expect(TrailingPunctuationSplit.splitCarried(
            "!?",
            convertsAsGroup: true
        ) == nil)
        #expect(TrailingPunctuationSplit.splitCarried(
            ",",
            convertsAsGroup: false
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
        let split = try #require(TrailingPunctuationSplit.split(input))
        var session = InputSession()
        var committed = convertedBody
        session.carryTrailingPunctuation(split.punctuation)

        for symbol in symbols {
            let carried = TrailingPunctuationSplit.splitCarried(
                session.input,
                convertsAsGroup: !JapaneseSymbolConverter.candidates(
                    for: session.input
                ).isEmpty
            )
            let target = carried?.body ?? session.input
            #expect(JapaneseSymbolConverter.candidates(for: target)
                .contains(symbol))
            committed += symbol
            session.clear()
            if let rest = carried?.punctuation {
                session.carryTrailingPunctuation(rest)
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
        let split = try #require(TrailingPunctuationSplit.split(input))

        #expect(CandidateSelectionProjection.unconvertedMarkedText(
            input: input
        ) == input)
        #expect(CandidateSelectionProjection.markedText(
            for: Candidate(storageText: converted),
            suffix: split.punctuation
        ) == selectedText)

        var session = InputSession()
        session.carryTrailingPunctuation(split.punctuation)

        #expect(CandidateSelectionProjection.unconvertedMarkedText(
            input: session.input
        ) == carriedText)
    }

    @Test
    func carriedGroupShowsTheRestOnceAfterTheSelectedSymbol() throws {
        let carried = try #require(TrailingPunctuationSplit.splitCarried(
            "!?",
            convertsAsGroup: false
        ))

        #expect(CandidateSelectionProjection.unconvertedMarkedText(
            input: "!?"
        ) == "!?")
        #expect(CandidateSelectionProjection.markedText(
            for: Candidate(storageText: "！"),
            suffix: carried.punctuation
        ) == "！?")
    }

    @Test
    func carriedPunctuationLastsUntilTheInputIsEdited() {
        var session = InputSession()
        session.carryTrailingPunctuation("!?")

        #expect(session.input == "!?")
        #expect(session.carriesTrailingPunctuation)

        session.insert("a")

        #expect(!session.carriesTrailingPunctuation)

        session.carryTrailingPunctuation(",")
        session.clear()

        #expect(!session.carriesTrailingPunctuation)
    }
}
