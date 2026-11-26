import Foundation

public struct InputFeatureSettings {
    private enum Key {
        static let nextInputPrediction = "NextInputPredictionEnabled"
        static let englishCompletion = "EnglishCompletionEnabled"
        static let appleTranslation = "AppleTranslationEnabled"
        static let translationLanguages = "TranslationTargetLanguages"
        static let legacyTranslationLanguage = "DefaultTranslationLanguage"
        static let webSearch = "WebSearchEnabled"
        static let externalInformationPanel = "ExternalInformationPanelEnabled"
        static let systemDictionaryPreview = "SystemDictionaryPreviewEnabled"
        static let systemDictionaryNames = "SystemDictionaryNames"
        static let fuzzyCandidates = "FuzzySuggestionsEnabled"
        static let dateTimeCandidates = "DateTimeCandidatesEnabled"
        static let emojiCandidates = "EmojiCandidatesEnabled"
        static let liveConversion = "LiveConversionEnabled"
        static let skkMode = "SKKModeEnabled"
        static let inputHistoryCount = "InputHistoryMaximumCount"
        static let passwordInputSourceRecovery =
            "PasswordInputSourceRecoveryEnabled"
        static let disabledImportedDictionaries = "DisabledImportedDictionaries"
    }

    private let defaults: UserDefaults

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    public var isNextInputPredictionEnabled: Bool {
        get { flag(Key.nextInputPrediction, default: true) }
        nonmutating set { setFlag(Key.nextInputPrediction, newValue) }
    }

    public var isEnglishCompletionEnabled: Bool {
        get { flag(Key.englishCompletion, default: true) }
        nonmutating set { setFlag(Key.englishCompletion, newValue) }
    }

    public var isAppleTranslationEnabled: Bool {
        get { flag(Key.appleTranslation, default: true) }
        nonmutating set { setFlag(Key.appleTranslation, newValue) }
    }

    public var isWebSearchEnabled: Bool {
        get { flag(Key.webSearch, default: false) }
        nonmutating set { setFlag(Key.webSearch, newValue) }
    }

    public var isExternalInformationPanelEnabled: Bool {
        get { flag(Key.externalInformationPanel, default: true) }
        nonmutating set { setFlag(Key.externalInformationPanel, newValue) }
    }

    public var isSystemDictionaryPreviewEnabled: Bool {
        get { flag(Key.systemDictionaryPreview, default: true) }
        nonmutating set { setFlag(Key.systemDictionaryPreview, newValue) }
    }

    public var isFuzzyCandidatesEnabled: Bool {
        get { flag(Key.fuzzyCandidates, default: false) }
        nonmutating set { setFlag(Key.fuzzyCandidates, newValue) }
    }

    /// Emoji among the conversion candidates
    public var isEmojiCandidatesEnabled: Bool {
        get { flag(Key.emojiCandidates, default: true) }
        nonmutating set { setFlag(Key.emojiCandidates, newValue) }
    }

    /// The composition converted as it is typed, offered as a candidate;
    /// on unless turned off
    public var isLiveConversionEnabled: Bool {
        get { flag(Key.liveConversion, default: true) }
        nonmutating set { setFlag(Key.liveConversion, newValue) }
    }

    /// A capital typed with Shift starts an SKK conversion and the next
    /// marks where its okurigana start; off unless turned on
    public var isSKKModeEnabled: Bool {
        get { flag(Key.skkMode, default: false) }
        nonmutating set { setFlag(Key.skkMode, newValue) }
    }

    /// How many commits the input history keeps, 1 to 100
    public var inputHistoryMaximumCount: Int {
        get {
            guard defaults.object(forKey: Key.inputHistoryCount) != nil else {
                return InputHistoryStore.defaultMaximumCount
            }
            return InputHistoryStore.clamped(defaults.integer(forKey: Key.inputHistoryCount))
        }
        nonmutating set {
            defaults.set(InputHistoryStore.clamped(newValue), forKey: Key.inputHistoryCount)
        }
    }

    public var isDateTimeCandidatesEnabled: Bool {
        get { flag(Key.dateTimeCandidates, default: false) }
        nonmutating set { setFlag(Key.dateTimeCandidates, newValue) }
    }

    public var isPasswordInputSourceRecoveryEnabled: Bool {
        get { flag(Key.passwordInputSourceRecovery, default: true) }
        nonmutating set {
            setFlag(Key.passwordInputSourceRecovery, newValue)
        }
    }

    public var translationLanguageIdentifiers: Set<String> {
        get {
            if let stored = defaults.stringArray(
                forKey: Key.translationLanguages
            ) {
                return Set(stored)
            }
            if let legacy = defaults.string(
                forKey: Key.legacyTranslationLanguage
            ) {
                return [legacy]
            }
            return ["en"]
        }
        nonmutating set {
            defaults.set(
                Array(newValue).sorted(),
                forKey: Key.translationLanguages
            )
            defaults.synchronize()
        }
    }

    public var translationTargetLanguages: [TranslationTargetLanguage] {
        TranslationTargetLanguage.languages(
            forIdentifiers: translationLanguageIdentifiers
        )
    }

    public func systemDictionaryNames(
        defaultNames: () -> [String]
    ) -> [String] {
        guard defaults.object(forKey: Key.systemDictionaryNames) != nil else {
            return defaultNames()
        }
        return defaults.stringArray(forKey: Key.systemDictionaryNames) ?? []
    }

    public func setSystemDictionaryNames(_ names: [String]) {
        defaults.set(names, forKey: Key.systemDictionaryNames)
    }

    public var disabledImportedDictionaryFilenames: Set<String> {
        Set(defaults.stringArray(
            forKey: Key.disabledImportedDictionaries
        ) ?? [])
    }

    public func setImportedDictionary(_ filename: String, enabled: Bool) {
        var disabled = disabledImportedDictionaryFilenames
        if enabled {
            disabled.remove(filename)
        } else {
            disabled.insert(filename)
        }
        defaults.set(
            disabled.sorted(),
            forKey: Key.disabledImportedDictionaries
        )
    }

    private func flag(_ key: String, default defaultValue: Bool) -> Bool {
        guard defaults.object(forKey: key) != nil else { return defaultValue }
        return defaults.bool(forKey: key)
    }

    private func setFlag(_ key: String, _ value: Bool) {
        defaults.set(value, forKey: key)
        defaults.synchronize()
    }
}
