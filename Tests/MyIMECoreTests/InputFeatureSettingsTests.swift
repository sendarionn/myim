import Foundation
import Testing
@testable import MyIMECore

@Suite
struct InputFeatureSettingsTests {
    @Test
    func usesFeatureDefaultsUntilAValueIsStored() {
        let settings = makeSettings()

        #expect(settings.isNextInputPredictionEnabled)
        #expect(settings.isEnglishCompletionEnabled)
        #expect(settings.isAppleTranslationEnabled)
        #expect(settings.isExternalInformationPanelEnabled)
        #expect(settings.isSystemDictionaryPreviewEnabled)
        #expect(!settings.isWikipediaSuggestionsEnabled)
        #expect(!settings.isGoogleJapaneseInputEnabled)
        #expect(!settings.isWebSearchEnabled)
        #expect(!settings.isFuzzySuggestionsEnabled)
        #expect(!settings.isDateTimeCandidatesEnabled)
    }

    @Test
    func storesFlagsUnderTheExistingDefaultsKeys() {
        let defaults = makeDefaults()
        let settings = InputFeatureSettings(defaults: defaults)

        settings.isNextInputPredictionEnabled = false
        settings.isWebSearchEnabled = true

        #expect(defaults.object(forKey: "NextInputPredictionEnabled") as? Bool == false)
        #expect(defaults.object(forKey: "WebSearchEnabled") as? Bool == true)
        #expect(!settings.isNextInputPredictionEnabled)
        #expect(settings.isWebSearchEnabled)
    }

    @Test
    func readsTheLegacyTranslationLanguageBeforeFallingBackToEnglish() {
        let defaults = makeDefaults()
        let settings = InputFeatureSettings(defaults: defaults)
        #expect(settings.translationLanguageIdentifiers == ["en"])

        defaults.set("ko", forKey: "DefaultTranslationLanguage")
        #expect(settings.translationLanguageIdentifiers == ["ko"])

        settings.translationLanguageIdentifiers = ["zh-Hans", "en"]
        #expect(defaults.stringArray(forKey: "TranslationTargetLanguages")
            == ["en", "zh-Hans"])
    }

    @Test
    func usesDefaultSystemDictionaryNamesOnlyBeforeSelection() {
        let settings = makeSettings()
        #expect(settings.systemDictionaryNames { ["大辞林"] } == ["大辞林"])

        settings.setSystemDictionaryNames([])

        #expect(settings.systemDictionaryNames { ["大辞林"] }.isEmpty)
    }

    @Test
    func togglesImportedDictionariesByFilename() {
        let settings = makeSettings()

        settings.setImportedDictionary("SKK-JISYO.L", enabled: false)
        settings.setImportedDictionary("SKK-JISYO.S", enabled: false)
        settings.setImportedDictionary("SKK-JISYO.L", enabled: true)

        #expect(settings.disabledImportedDictionaryFilenames == ["SKK-JISYO.S"])
    }

    private func makeSettings() -> InputFeatureSettings {
        InputFeatureSettings(defaults: makeDefaults())
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "InputFeatureSettingsTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        return defaults
    }
}
