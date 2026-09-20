import Testing
@testable import MyIMECore

@Suite
struct UserDictionaryEditorTests {
    @Test
    func acceptsPrintableSymbolsFromOptionKeyInput() {
        for symbol in ["•", "±", "©", "･", "→"] {
            #expect(UserDictionaryInputPolicy.accepts(
                symbol,
                hasCommandModifier: false,
                hasControlModifier: false
            ))
        }
        #expect(!UserDictionaryInputPolicy.accepts(
            "©",
            hasCommandModifier: true,
            hasControlModifier: false
        ))
        #expect(!UserDictionaryInputPolicy.accepts(
            "\n",
            hasCommandModifier: false,
            hasControlModifier: false
        ))
    }

    @Test
    func roundTripsCandidateContainingSymbols() throws {
        let entries = UserDictionaryEditor.adding(
            reading: "kigou",
            candidate: "価格：¥1,000 → ¥2,000",
            to: []
        )
        let text = DictionarySerializer.text(from: entries)

        #expect(try DictionaryParser().parse(text) == entries)
        #expect(ConversionEngine(entries: entries).candidates(for: "kigou")
            == ["価格：¥1,000 → ¥2,000"])
    }

    @Test
    func registersASymbolForASymbolOnlyReading() throws {
        let reading = try #require(UserDictionaryRegistrationReading.resolve(
            conversionReading: "",
            originalInput: "/"
        ))
        let entries = UserDictionaryEditor.adding(
            reading: reading,
            candidate: "･",
            to: []
        )

        #expect(reading == "/")
        #expect(ConversionEngine(entries: entries).candidates(for: "/") == ["･"])
        #expect(try DictionaryParser().parse(
            DictionarySerializer.text(from: entries)
        ) == entries)
    }

    @Test
    func looksUpARegisteredCandidateForRepeatedSymbols() throws {
        let originalInput = "///"
        let reading = try #require(UserDictionaryRegistrationReading.resolve(
            conversionReading: "",
            originalInput: originalInput
        ))
        let entries = UserDictionaryEditor.adding(
            reading: reading,
            candidate: "･･･",
            to: []
        )
        let lookupReading = UserDictionaryLookupReading.resolve(
            conversionReading: "",
            originalInput: originalInput
        )

        #expect(lookupReading == "///")
        #expect(ConversionEngine(entries: entries).candidates(
            for: lookupReading
        ) == ["･･･"])
    }

    @Test
    func keepsRomanReadingWhenTheInputAlsoContainsSymbols() {
        #expect(UserDictionaryRegistrationReading.resolve(
            conversionReading: "kigou",
            originalInput: "kigou/"
        ) == "kigou")
    }

    @Test
    func addsCandidateToExistingReading() {
        let entries = [
            DictionaryEntry(reading: "kouzou", candidates: ["構造"])
        ]
        let result = UserDictionaryEditor.adding(
            reading: "kouzou",
            candidate: "構想",
            to: entries
        )

        #expect(result[0].candidates == ["構造", "構想"])
    }

    @Test
    func addsAcronymReadingAndJapaneseCandidate() {
        let result = UserDictionaryEditor.adding(
            reading: "rlj",
            candidate: "リモートロックジャパン",
            to: []
        )

        #expect(
            ConversionEngine(entries: result).candidates(for: "rlj")
                == ["リモートロックジャパン"]
        )
    }

    @Test
    func treatsNormalizedReadingAsSameEntry() {
        let entries = [
            DictionaryEntry(reading: "shuusei", candidates: ["修正"])
        ]
        let result = UserDictionaryEditor.adding(
            reading: "syuusei",
            candidate: "修整",
            to: entries
        )

        #expect(result.count == 1)
        #expect(result[0].candidates == ["修正", "修整"])
    }

    @Test
    func doesNotDuplicateCandidate() {
        let entries = [
            DictionaryEntry(reading: "kenkyuu", candidates: ["研究"])
        ]
        let result = UserDictionaryEditor.adding(
            reading: "kenkyuu",
            candidate: "研究",
            to: entries
        )

        #expect(result == entries)
    }

    @Test
    func addsCandidateWithSeparateDisplayName() throws {
        let result = UserDictionaryEditor.adding(
            reading: "tomato",
            candidate: "https://example.com/tomato.jpg",
            display: "トマトの画像",
            to: []
        )
        let candidate = try #require(result.first?.candidates.first)
        #expect(DictionaryCandidateRepresentation.display(from: candidate) == "トマトの画像")
        #expect(DictionaryCandidateRepresentation.value(from: candidate) == "https://example.com/tomato.jpg")
    }

    @Test
    func removesCandidateFromMatchingReading() {
        let entries = [
            DictionaryEntry(
                reading: "kouzou",
                candidates: ["構造", "構想"]
            )
        ]
        let result = UserDictionaryEditor.removing(
            candidate: "構造",
            matchingReadings: ["kouzou"],
            from: entries
        )

        #expect(result == [
            DictionaryEntry(reading: "kouzou", candidates: ["構想"])
        ])
    }

    @Test
    func removesEntryWhenLastCandidateIsRemoved() {
        let entries = [
            DictionaryEntry(reading: "kenkyuu", candidates: ["研究"])
        ]
        let result = UserDictionaryEditor.removing(
            candidate: "研究",
            matchingReadings: ["kenkyuu"],
            from: entries
        )

        #expect(result.isEmpty)
    }

    @Test
    func leavesCandidatesForOtherReadingsUnchanged() {
        let entries = [
            DictionaryEntry(reading: "kouzou", candidates: ["構造"]),
            DictionaryEntry(reading: "shikumi", candidates: ["構造"])
        ]
        let result = UserDictionaryEditor.removing(
            candidate: "構造",
            matchingReadings: ["kouzou"],
            from: entries
        )

        #expect(result == [
            DictionaryEntry(reading: "shikumi", candidates: ["構造"])
        ])
    }

    @Test
    func removesCandidateRegardlessOfCurrentReading() {
        let entries = [
            DictionaryEntry(reading: "readme", candidates: ["README"]),
            DictionaryEntry(reading: "document", candidates: ["README", "文書"])
        ]
        let result = UserDictionaryEditor.removing(
            candidate: "README",
            from: entries
        )

        #expect(result == [
            DictionaryEntry(reading: "document", candidates: ["文書"])
        ])
    }

    @Test
    func leavesOtherUserCandidatesUnchangedWhenRemovingGlobally() {
        let entries = [
            DictionaryEntry(reading: "readme", candidates: ["README"]),
            DictionaryEntry(reading: "read", candidates: ["読む"])
        ]
        let result = UserDictionaryEditor.removing(
            candidate: "README",
            from: entries
        )

        #expect(result == [
            DictionaryEntry(reading: "read", candidates: ["読む"])
        ])
    }

    @Test
    func removesDisplayCandidateByInsertedValue() throws {
        let stored = try #require(DictionaryCandidateRepresentation.encoded(
            display: "ミルミル",
            value: "みるみる"
        ))
        let entries = [
            DictionaryEntry(reading: "miru", candidates: [stored])
        ]

        #expect(UserDictionaryEditor.removing(
            candidate: "みるみる",
            from: entries
        ).isEmpty)
    }
}
