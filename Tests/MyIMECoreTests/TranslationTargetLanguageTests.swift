import Testing
@testable import MyIMECore

@Suite
struct TranslationTargetLanguageTests {
    @Test
    func resolvesStoredLanguageIdentifier() {
        #expect(
            TranslationTargetLanguage.language(forIdentifier: "zh-Hant")?
                .name == "中国語（繁体字）"
        )
        #expect(
            TranslationTargetLanguage.language(forIdentifier: "unknown")
                == nil
        )
    }

    @Test
    func resolvesMultipleLanguagesInDisplayOrder() {
        #expect(TranslationTargetLanguage.languages(
            forIdentifiers: ["ko", "en", "unknown"]
        ).map(\.identifier) == ["en", "ko"])
    }
}
