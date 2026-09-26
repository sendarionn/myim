import Testing
@testable import MyIMECore

@Suite
struct TranslationTargetLanguageTests {
    @Test
    func resolvesLanguagePrefixes() {
        #expect(
            TranslationTargetLanguage.language(forPrefix: "en")?.identifier
                == "en"
        )
        #expect(
            TranslationTargetLanguage.language(forPrefix: "ZH")?.identifier
                == "zh-Hans"
        )
        #expect(
            TranslationTargetLanguage.language(forPrefix: "zht")?.identifier
                == "zh-Hant"
        )
        #expect(
            TranslationTargetLanguage.language(forPrefix: "pt")?.identifier
                == "pt-BR"
        )
    }

    @Test
    func rejectsUnknownPrefix() {
        #expect(TranslationTargetLanguage.language(forPrefix: "ja") == nil)
        #expect(TranslationTargetLanguage.language(forPrefix: "") == nil)
    }

    @Test
    func resolvesStoredLanguageIdentifier() {
        #expect(
            TranslationTargetLanguage.language(forIdentifier: "zh-Hant")?
                .prefix == "zht"
        )
        #expect(
            TranslationTargetLanguage.language(forIdentifier: "unknown")
                == nil
        )
    }

    @Test
    func acceptsOnlyTranslationDirectiveSeparators() {
        #expect(
            TranslationTargetLanguage.language(
                forPrefix: "en",
                terminatedBy: " "
            )?.identifier == "en"
        )
        #expect(
            TranslationTargetLanguage.language(
                forPrefix: "zh",
                terminatedBy: "　"
            )?.identifier == "zh-Hans"
        )
        #expect(
            TranslationTargetLanguage.language(
                forPrefix: "ko",
                terminatedBy: "\t"
            )?.identifier == "ko"
        )
        #expect(
            TranslationTargetLanguage.language(
                forPrefix: "en",
                terminatedBy: "\n"
            ) == nil
        )
    }
}
