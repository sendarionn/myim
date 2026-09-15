import Testing
@testable import MyIMECore

@Suite
struct InputFormConverterTests {
    @Test
    func convertsFunctionKeyForms() {
        #expect(InputFormConverter.convert("miru", to: .hiragana) == "みる")
        #expect(InputFormConverter.convert("miru", to: .fullWidthKatakana) == "ミル")
        #expect(InputFormConverter.convert("miru", to: .halfWidthKatakana) == "ﾐﾙ")
        #expect(InputFormConverter.convert("Miru12", to: .fullWidthAlphanumeric) == "Ｍｉｒｕ１２")
        #expect(InputFormConverter.convert("Miru12", to: .halfWidthAlphanumeric) == "Miru12")
        #expect(
            InputFormConverter.convert(
                "Miru１２-test",
                to: .halfWidthUppercaseAlphanumeric
            ) == "MIRU12-TEST"
        )
    }
}
