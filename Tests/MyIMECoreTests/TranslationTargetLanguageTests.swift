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
}
