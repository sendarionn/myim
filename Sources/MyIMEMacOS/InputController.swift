@preconcurrency import AppKit
@preconcurrency import InputMethodKit
import MyIMECore

@objc(MyIMEInputController)
final class InputController: IMKInputController {
    private struct TabDictionaryRegistration {
        let originalInput: String
        let reading: String
        var pastedCandidate: String?
        var confirmedCandidate: String?
    }

    private static let defaultDictionarySource = CosenseDictionarySource(
        project: "sendarionn-public",
        pageTitle: "dictionary"
    )
    private static let projectDefaultsKey = "CosenseExtensionProject"
    private static let nextInputEnabledDefaultsKey = "NextInputPredictionEnabled"
    private static let extensionDictionaryEnabledDefaultsKey =
        "ExtensionDictionaryEnabled"
    private static let englishCompletionEnabledDefaultsKey =
        "EnglishCompletionEnabled"
    private static let wikipediaSuggestionsEnabledDefaultsKey =
        "WikipediaSuggestionsEnabled"
    private static let appleTranslationEnabledDefaultsKey =
        "AppleTranslationEnabled"
    private static let translationModeEnabledDefaultsKey =
        "TranslationModeEnabled"
    private static let webSearchEnabledDefaultsKey = "WebSearchEnabled"
    private static let webSearchTemplateDefaultsKey = "WebSearchTemplate"
    private static let externalInformationPanelEnabledDefaultsKey =
        "ExternalInformationPanelEnabled"
    private static let legacyCosensePreviewEnabledDefaultsKey =
        "CosensePreviewEnabled"
    private static let externalInformationURLTemplateDefaultsKey =
        "ExternalInformationURLTemplate"
    private static let externalInformationDisplayDelayDefaultsKey =
        "ExternalInformationDisplayDelay"
    private static let systemDictionaryPreviewEnabledDefaultsKey =
        "SystemDictionaryPreviewEnabled"
    private static let fuzzySuggestionsEnabledDefaultsKey =
        "FuzzySuggestionsEnabled"
    private static let dateTimeCandidatesEnabledDefaultsKey =
        "DateTimeCandidatesEnabled"
    private static let dateCandidateFormatsDefaultsKey =
        "DateCandidateFormats"
    private static let timeCandidateFormatsDefaultsKey =
        "TimeCandidateFormats"
    private static let dateTimeCandidateFormatsDefaultsKey =
        "DateTimeCandidateFormats"
    private static let maximumCandidateCount = 7
    private static let maximumIMEDictionaryPrefixCandidates = 2048
    private static let nextInputDismissInterval: TimeInterval = 5
    private static let sharedBasicEntries = loadBasicEntries()
    private static let sharedBasicConversionEngine = ConversionEngine(
        entries: sharedBasicEntries
    )
    private static let sharedIMEConversionEngine = loadIMEDictionaryEngine()
    private static let sharedSupplementalConversionEngine = ConversionEngine(
        entries: SupplementalDictionary.entries
    )
    private static let sharedVerbInflectionGenerator =
        VerbInflectionCandidateGenerator(entries: sharedBasicEntries)
    private static let fuzzyEngineRepository = FuzzyEngineRepository()
    private static let basicDictionaryUpdateCoordinator =
        BasicDictionaryUpdateCoordinator()

    private var inputBuffer = ""
    private var inputCursor = 0
    private var reconversionOriginal: String?
    private var translationDraft: String?
    private var translationTask: Task<Void, Never>?
    private var activatedAt: TimeInterval?
    private var currentCandidates: [String] = []
    private var selectedCandidateIndex: Int?
    private var fuzzySuggestions: [FuzzySuggestion] = []
    private var selectedFuzzySuggestionIndex: Int?
    private var dictionarySource: CosenseDictionarySource
    private var userEntries: [DictionaryEntry]
    private var basicEntries: [DictionaryEntry]
    private var extensionEntries: [DictionaryEntry]
    private var userConversionEngine: ConversionEngine
    private var extensionConversionEngine: ConversionEngine
    private var basicConversionEngine: ConversionEngine
    private let imeConversionEngine: IndexedDictionaryEngine
    private let supplementalConversionEngine: ConversionEngine
    private var verbInflectionGenerator: VerbInflectionCandidateGenerator
    private var fuzzyEngineBuildTask: Task<Void, Never>?
    private let cosenseSettingsController: CosenseSettingsController
    private let settingsDialogController = SettingsDialogController()
    private var cosenseCredential: CosenseCredential?
    private var candidateSelectionHistory: CandidateSelectionHistory
    private let candidateSelectionHistoryWriter:
        DeferredJSONFileWriter<[String: Int]>
    private var nextInputPredictionModel: NextInputPredictionModel
    private let nextInputPredictionWriter:
        DeferredJSONFileWriter<NextInputPredictionModel>
    private var nextInputCandidates: [String] = []
    private var selectedNextInputIndex: Int?
    private var nextInputDismissTimer: Timer?
    private let suggestionSearchSession = SuggestionSearchSession()
    private var officialCandidates: [String] = []
    private var tabDictionaryRegistration: TabDictionaryRegistration?
    private var cosenseSyncStatus = "未実行"
    private var basicDictionaryStatus = "未確認"
    private let candidateWindow = CandidateWindowController()
    private let modeStatusWindow = ModeStatusWindowController()
    private let fuzzySuggestionWindow = FuzzySuggestionWindowController()
    private let previewWindow = ExternalInformationWindowController()
    private let definitionProvider = SystemDictionaryDefinitionProvider()
    private let romajiConverter = RomajiConverter()
    private var settingsWindow: NSWindow?

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let source = Self.loadDictionarySource()
        let cosenseSettingsController = CosenseSettingsController()
        let cachedUserEntries = Self.loadUserEntries()
        let bundledEntries = Self.sharedBasicEntries
        let indexedIMEEngine = Self.sharedIMEConversionEngine
        let cachedExtensionEntries = Self.loadExtensionEntries(for: source)
        let selectionHistory = Self.loadCandidateSelectionHistory()
        let nextInputModel = Self.loadNextInputPredictionModel()

        dictionarySource = source
        self.cosenseSettingsController = cosenseSettingsController
        cosenseCredential = cosenseSettingsController.credential(
            for: source.project
        )
        userEntries = cachedUserEntries
        basicEntries = bundledEntries
        extensionEntries = cachedExtensionEntries
        candidateSelectionHistory = selectionHistory
        candidateSelectionHistoryWriter = DeferredJSONFileWriter(
            fileURL: Self.candidateSelectionHistoryURL(),
            queueLabel: "myim.candidate-selection-history",
            errorHandler: {
                NSLog(
                    "候補選択履歴の保存に失敗: %@",
                    $0.localizedDescription
                )
            }
        )
        nextInputPredictionModel = nextInputModel
        nextInputPredictionWriter = DeferredJSONFileWriter(
            fileURL: Self.nextInputPredictionModelURL(),
            queueLabel: "myim.next-input-history",
            errorHandler: {
                NSLog(
                    "次入力履歴の保存に失敗: %@",
                    $0.localizedDescription
                )
            }
        )
        userConversionEngine = ConversionEngine(entries: cachedUserEntries)
        extensionConversionEngine = ConversionEngine(
            entries: cachedExtensionEntries
        )
        basicConversionEngine = Self.sharedBasicConversionEngine
        imeConversionEngine = indexedIMEEngine
        supplementalConversionEngine = Self.sharedSupplementalConversionEngine
        verbInflectionGenerator = Self.sharedVerbInflectionGenerator
        super.init(server: server, delegate: delegate, client: inputClient)

        basicDictionaryStatus = bundledEntries.isEmpty
            ? "読込失敗"
            : "読込済み（TKGJE \(bundledEntries.count)＋Mozc \(indexedIMEEngine.readingCount)読み）"
        rebuildFuzzyConversionEngine()
        updateBasicDictionaryIfNeeded(nil)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let sender else {
            return false
        }

        guard event.type == .keyDown else {
            return false
        }

        if previewWindow.isInteractionActive {
            previewWindow.finishInteraction()
            if event.keyCode == 53 {
                return true
            }
        }

        if isSystemUndoRedoShortcut(event) {
            if !inputBuffer.isEmpty || tabDictionaryRegistration != nil {
                clearCompositionForSystemPaste(in: sender)
            }
            if !nextInputCandidates.isEmpty {
                dismissNextInputSuggestions(clearMarkedTextIn: sender)
            }
            return false
        }

        if isTranslationModeShortcut(event) {
            toggleTranslationMode(nil)
            if !inputBuffer.isEmpty {
                refreshCandidates(client: sender)
            }
            return true
        }

        if interactionState == .registeringDictionary {
            return handleTabDictionaryRegistration(event, client: sender)
        }

        commitSelectedNextInputBeforeNewInput(event, client: sender)

        if shouldDismissNextInputSuggestions(for: event) {
            dismissNextInputSuggestions(clearMarkedTextIn: sender)
        }

        if event.keyCode == 15,
           event.modifierFlags.contains([.command, .option, .control]) {
            syncCosenseDictionary(nil)
            return true
        }

        if isUserDictionaryDeletionShortcut(event),
           !inputBuffer.isEmpty {
            removeSelectedUserDictionaryCandidate(client: sender)
            return true
        }

        if isOpenExternalInformationShortcut(event),
           !inputBuffer.isEmpty {
            if !previewWindow.openDisplayedPageInDefaultBrowser() {
                NSSound.beep()
            }
            return true
        }

        if isWebSearchShortcut(event),
           openSelectedWebSearch(client: sender) {
            return true
        }

        if isTabDictionaryRegistrationShortcut(event),
           !inputBuffer.isEmpty,
           selectedCandidateIndex == nil {
            return beginTabDictionaryRegistration(client: sender)
        }

        if handleInputFormFunctionKey(event, client: sender) {
            return true
        }

        if let handled = handleFuzzySuggestionSelection(
            event,
            client: sender
        ) {
            return handled
        }

        if isFuzzySuggestionEntryShortcut(event),
           !fuzzySuggestions.isEmpty {
            return selectFuzzySuggestion(index: 0, client: sender)
        }

        switch event.keyCode {
        case 48:
            return handleTab(event, client: sender)
        case 49:
            let space = isFullWidthSpaceShortcut(event) ? "　" : " "
            if space == " ", inputBuffer.isEmpty,
               shouldSuppressActivationSpace(event) {
                activatedAt = nil
                return true
            }
            return isTranslationModeEnabled
                ? handleTranslationSpace(space: space, client: sender)
                : handleSpace(space: space, client: sender)
        case 123:
            return selectedCandidateIndex == nil
                ? moveInputCursor(by: -1, client: sender)
                : moveCandidate(.left, client: sender)
        case 124:
            return selectedCandidateIndex == nil
                ? moveInputCursor(by: 1, client: sender)
                : moveCandidate(.right, client: sender)
        case 125:
            return selectedCandidateIndex == nil
                ? false
                : moveCandidate(.down, client: sender)
        case 126:
            return selectedCandidateIndex == nil
                ? false
                : moveCandidate(.up, client: sender)
        case 36, 76:
            return isTranslationModeEnabled
                ? handleTranslationReturn(client: sender)
                : commitFirstCandidateOrInput(to: sender)
        case 51:
            return deleteBackward(
                from: sender,
                unit: deletionUnit(for: event)
            )
        case 53:
            if translationDraft != nil, inputBuffer.isEmpty {
                finishTranslationDraftAsJapanese(client: sender)
                return true
            }
            return cancelInput(in: sender)
        default:
            break
        }

        guard
            event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
            let characters = event.characters,
            !characters.isEmpty
        else {
            if !inputBuffer.isEmpty {
                commit(inputBuffer, to: sender)
            }
            return false
        }

        if let selectedValue = selectedCandidateValue {
            if isTranslationModeEnabled {
                appendCurrentInputToTranslationDraft(
                    suffix: "",
                    client: sender
                )
            } else {
                recordSelectedCandidate()
                commit(selectedValue, to: sender)
            }
        }

        let isASCIIInput = characters.unicodeScalars.allSatisfy {
            (0x21...0x7e).contains($0.value)
        }
        guard isASCIIInput else {
            if !inputBuffer.isEmpty {
                commit(inputBuffer, to: sender)
            }
            return false
        }

        insertIntoInputBuffer(characters)
        selectedCandidateIndex = nil
        previewWindow.hide()
        updateMarkedText(in: sender)
        refreshCandidates(client: sender)
        return true
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        currentCandidates
    }

    override func doCommand(
        by aSelector: Selector!,
        command infoDictionary: [AnyHashable: Any]!
    ) {
        guard let aSelector, responds(to: aSelector) else {
            super.doCommand(by: aSelector, command: infoDictionary)
            return
        }
        perform(aSelector, with: infoDictionary)
    }

    override func menu() -> NSMenu! {
        InputSourceMenuBuilder.make(
            actions: InputSourceMenuBuilder.Actions(
                openSettings: #selector(openSettingsWindow(_:)),
                toggleTranslationMode: #selector(toggleTranslationMode(_:)),
                translationModeEnabled: isTranslationModeEnabled,
                syncCosenseDictionary: #selector(syncCosenseDictionary(_:)),
                showStatus: #selector(showStatus(_:))
            )
        )
    }

    @objc
    private func openSettingsWindow(_ sender: Any?) {
        if let settingsWindow {
            resetSettingsScrollPosition(settingsWindow)
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let panel = SettingsWindowBuilder.make(
            target: self,
            states: settingsFeatureStates,
            actions: settingsActions
        )
        settingsWindow = panel
        resetSettingsScrollPosition(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func resetSettingsScrollPosition(_ window: NSWindow) {
        guard let scrollView = window.contentView as? NSScrollView else {
            return
        }
        window.layoutIfNeeded()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private var settingsFeatureStates: SettingsWindowBuilder.FeatureStates {
        SettingsWindowBuilder.FeatureStates(
            extensionDictionary: isExtensionDictionaryEnabled,
            englishCompletion: isEnglishCompletionEnabled,
            wikipediaSuggestions: isWikipediaSuggestionsEnabled,
            appleTranslation: isAppleTranslationEnabled,
            nextInputPrediction: isNextInputPredictionEnabled,
            fuzzySuggestions: isFuzzySuggestionsEnabled,
            dateTimeCandidates: isDateTimeCandidatesEnabled,
            externalInformationPanel: isExternalInformationPanelEnabled,
            systemDictionaryPreview: isSystemDictionaryPreviewEnabled,
            webSearch: isWebSearchEnabled
        )
    }

    private var settingsActions: SettingsWindowBuilder.Actions {
        SettingsWindowBuilder.Actions(
            toggleExtensionDictionary: #selector(toggleExtensionDictionary(_:)),
            toggleEnglishCompletion: #selector(toggleEnglishCompletion(_:)),
            toggleWikipediaSuggestions: #selector(toggleWikipediaSuggestions(_:)),
            toggleAppleTranslation: #selector(toggleAppleTranslation(_:)),
            toggleNextInputPrediction: #selector(toggleNextInputPrediction(_:)),
            toggleFuzzySuggestions: #selector(toggleFuzzySuggestions(_:)),
            toggleDateTimeCandidates: #selector(toggleDateTimeCandidates(_:)),
            configureDateTimeFormats: #selector(configureDateTimeCandidateFormats(_:)),
            configureWebSearch: #selector(configureWebSearch(_:)),
            clearNextInputHistory: #selector(clearNextInputPredictionHistory(_:)),
            toggleExternalInformationPanel: #selector(toggleExternalInformationPanel(_:)),
            toggleSystemDictionaryPreview: #selector(toggleSystemDictionaryPreview(_:)),
            toggleWebSearch: #selector(toggleWebSearch(_:)),
            configureExternalInformationPanel: #selector(configureExternalInformationPanel(_:)),
            updateBasicDictionary: #selector(updateBasicDictionaryIfNeeded(_:)),
            configureCosenseProject: #selector(configureCosenseProject(_:)),
            configureCosenseAuthentication: #selector(configureCosenseAuthentication(_:)),
            syncCosenseDictionary: #selector(syncCosenseDictionary(_:))
        )
    }

    @objc
    private func showStatus(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "myimの状態"
        alert.informativeText = [
            "ユーザー辞書: \(userEntries.count)読み",
            "拡張辞書: \(dictionarySource.projectURLDescription)",
            "Cosense認証: \(cosenseAuthenticationStatus)",
            "Cosense更新: \(cosenseSyncStatus)",
            "TKGJE更新: \(basicDictionaryStatus)"
        ].joined(separator: "\n")
        alert.addButton(withTitle: "閉じる")
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        _ = alert.runModal()
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        guard let candidate = candidateString?.string else {
            previewWindow.hide()
            return
        }

        selectedCandidateIndex = currentCandidates.firstIndex(of: candidate)
        showPreview(for: candidate)
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let candidate = candidateString?.string else {
            return
        }

        recordCandidateSelection(candidate)
        if isTranslationModeEnabled {
            selectedCandidateIndex = currentCandidates.firstIndex(of: candidate)
            appendCurrentInputToTranslationDraft(
                suffix: "",
                client: client() as Any
            )
            return
        }
        commit(
            candidateValueForCommit(candidate) + conversionSuffix,
            to: client() as Any
        )
    }

    override func commitComposition(_ sender: Any!) {
        guard let sender else {
            return
        }

        if reconversionOriginal != nil {
            restoreReconversionOriginal(client: sender)
            return
        }
        if translationDraft != nil {
            finishTranslationDraftAsJapanese(client: sender)
            return
        }
        tabDictionaryRegistration = nil
        if inputBuffer.isEmpty {
            dismissNextInputSuggestions(clearMarkedTextIn: sender)
            return
        }

        commit(inputBuffer, to: sender)
    }

    override func activateServer(_ sender: Any!) {
        activatedAt = ProcessInfo.processInfo.systemUptime
        super.activateServer(sender)
    }

    override func deactivateServer(_ sender: Any!) {
        if previewWindow.shouldPreserveForExternalInteraction() {
            super.deactivateServer(sender)
            return
        }
        if !inputBuffer.isEmpty {
            if reconversionOriginal != nil {
                restoreReconversionOriginal(client: sender as Any)
            } else if translationDraft != nil {
                finishTranslationDraftAsJapanese(client: sender as Any)
            } else {
                commit(inputBuffer, to: sender as Any)
            }
        } else if translationDraft != nil {
            finishTranslationDraftAsJapanese(client: sender as Any)
        }
        resetTransientInteractionState()
        modeStatusWindow.hide()
        translationTask?.cancel()
        translationTask = nil
        translationDraft = nil
        nextInputPredictionModel.breakSequence()
        flushPendingHistoryWrites()
        super.deactivateServer(sender)
    }

    override func inputControllerWillClose() {
        if previewWindow.shouldPreserveForExternalInteraction() {
            super.inputControllerWillClose()
            return
        }
        resetTransientInteractionState()
        modeStatusWindow.hide()
        translationTask?.cancel()
        translationTask = nil
        translationDraft = nil
        fuzzyEngineBuildTask?.cancel()
        flushPendingHistoryWrites()
        super.inputControllerWillClose()
    }

    @objc
    private func configureCosenseProject(_ sender: Any?) {
        guard let configuration = cosenseSettingsController.chooseProject(
            currentURLDescription: dictionarySource.projectURLDescription
        ) else {
            return
        }

        dictionarySource = configuration.dictionarySource
        cosenseCredential = cosenseSettingsController.credential(
            for: configuration.project
        )
        UserDefaults.standard.set(
            configuration.project,
            forKey: Self.projectDefaultsKey
        )
        extensionEntries = Self.loadExtensionEntries(for: dictionarySource)
        rebuildConversionEngine()
        cosenseSyncStatus = "未実行"

        if !inputBuffer.isEmpty, let inputClient = client() {
            selectedCandidateIndex = nil
            previewWindow.hide()
            refreshCandidates(client: inputClient)
        }

        syncCosenseDictionary(nil)
    }

    @objc
    private func configureCosenseAuthentication(_ sender: Any?) {
        switch cosenseSettingsController.updateCredential(
            current: cosenseCredential,
            project: dictionarySource.project
        ) {
        case .cancelled:
            return
        case .updated(let credential):
            cosenseCredential = credential
            cosenseSyncStatus = "未実行"
            syncCosenseDictionary(nil)
        }
    }

    @objc
    private func syncCosenseDictionary(_ sender: Any?) {
        guard cosenseSyncStatus != "更新中" else {
            return
        }

        cosenseSyncStatus = "更新中"
        let source = dictionarySource

        Task { @MainActor [weak self] in
            do {
                let dictionaryText = try await CosenseDictionaryClient().fetch(
                    from: source,
                    credential: self?.cosenseCredential
                )
                let entries = try DictionaryParser().parse(dictionaryText)
                guard !entries.isEmpty else {
                    throw CosenseDictionaryError.emptyDictionary
                }

                let cache = try Self.extensionCache(for: source)
                try cache.save(
                    dictionaryText: dictionaryText,
                    metadata: DictionaryCacheMetadata(
                        syncedAt: Date(),
                        entryCount: entries.count
                    )
                )

                guard let self else {
                    return
                }
                guard dictionarySource == source else {
                    return
                }
                extensionEntries = entries
                rebuildConversionEngine()
                cosenseSyncStatus = "完了（\(entries.count)読み）"

                if !inputBuffer.isEmpty, let inputClient = client() {
                    selectedCandidateIndex = nil
                    previewWindow.hide()
                    refreshCandidates(client: inputClient)
                }
            } catch {
                if case CosenseDictionaryError.HTTPStatus(401) = error {
                    self?.cosenseSyncStatus = "認証が必要"
                } else if case CosenseDictionaryError.HTTPStatus(403) = error {
                    self?.cosenseSyncStatus = "権限なし"
                } else {
                    self?.cosenseSyncStatus = "失敗"
                }
                NSLog("Cosense辞書の更新に失敗: %@", error.localizedDescription)
            }
        }
    }

    @objc
    private func toggleNextInputPrediction(_ sender: Any?) {
        let enabled = !isNextInputPredictionEnabled
        UserDefaults.standard.set(
            enabled,
            forKey: Self.nextInputEnabledDefaultsKey
        )
        if !enabled {
            dismissNextInputSuggestions(clearMarkedTextIn: client())
            nextInputPredictionModel.breakSequence()
        }
    }

    @objc
    private func toggleFuzzySuggestions(_ sender: Any?) {
        UserDefaults.standard.set(
            !isFuzzySuggestionsEnabled,
            forKey: Self.fuzzySuggestionsEnabledDefaultsKey
        )
        cancelFuzzySuggestionSearch()
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            fuzzySuggestionWindow.hide()
            return
        }
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleDateTimeCandidates(_ sender: Any?) {
        UserDefaults.standard.set(
            !isDateTimeCandidatesEnabled,
            forKey: Self.dateTimeCandidatesEnabledDefaultsKey
        )
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            return
        }
        refreshCandidates(client: inputClient)
    }

    @objc
    private func configureDateTimeCandidateFormats(_ sender: Any?) {
        guard let formats = settingsDialogController.dateTimeFormats(
            current: DateTimeCandidateGenerator.Formats(
                date: dateCandidateFormats,
                time: timeCandidateFormats,
                dateTime: dateTimeCandidateFormats
            )
        ) else {
            return
        }
        UserDefaults.standard.set(
            formats.date,
            forKey: Self.dateCandidateFormatsDefaultsKey
        )
        UserDefaults.standard.set(
            formats.time,
            forKey: Self.timeCandidateFormatsDefaultsKey
        )
        UserDefaults.standard.set(
            formats.dateTime,
            forKey: Self.dateTimeCandidateFormatsDefaultsKey
        )
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            return
        }
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleExtensionDictionary(_ sender: Any?) {
        toggleCandidateSource(
            defaultsKey: Self.extensionDictionaryEnabledDefaultsKey,
            currentlyEnabled: isExtensionDictionaryEnabled
        )
    }

    @objc
    private func toggleEnglishCompletion(_ sender: Any?) {
        toggleCandidateSource(
            defaultsKey: Self.englishCompletionEnabledDefaultsKey,
            currentlyEnabled: isEnglishCompletionEnabled
        )
    }

    @objc
    private func toggleWikipediaSuggestions(_ sender: Any?) {
        let enabled = !isWikipediaSuggestionsEnabled
        UserDefaults.standard.set(
            enabled,
            forKey: Self.wikipediaSuggestionsEnabledDefaultsKey
        )
        resetOfficialCandidates()
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            return
        }
        selectedCandidateIndex = nil
        updateMarkedText(in: inputClient)
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleAppleTranslation(_ sender: Any?) {
        UserDefaults.standard.set(
            !isAppleTranslationEnabled,
            forKey: Self.appleTranslationEnabledDefaultsKey
        )
        resetOfficialCandidates()
        guard !inputBuffer.isEmpty, let inputClient = client() else { return }
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleTranslationMode(_ sender: Any?) {
#if canImport(Translation)
        guard #available(macOS 15.0, *) else {
            NSSound.beep()
            return
        }
        let wasEnabled = isTranslationModeEnabled
        let enabled = !wasEnabled
        UserDefaults.standard.set(
            enabled,
            forKey: Self.translationModeEnabledDefaultsKey
        )
        if wasEnabled,
           !enabled,
           let inputClient = client(),
           translationDraft != nil || !inputBuffer.isEmpty {
            finishTranslationDraftAsJapanese(client: inputClient)
        } else {
            translationTask?.cancel()
            translationTask = nil
        }
        if let inputClient = client() {
            modeStatusWindow.show(
                enabled: enabled,
                near: inputLocation(for: inputClient)
            )
        }
#else
        NSSound.beep()
#endif
    }

    @objc
    private func toggleWebSearch(_ sender: Any?) {
        UserDefaults.standard.set(!isWebSearchEnabled, forKey: Self.webSearchEnabledDefaultsKey)
    }

    @objc
    private func configureWebSearch(_ sender: Any?) {
        guard let value = settingsDialogController.webSearchTemplate(
            current: webSearchTemplate
        ) else { return }
        UserDefaults.standard.set(
            value,
            forKey: Self.webSearchTemplateDefaultsKey
        )
    }

    private func resetOfficialCandidates() {
        suggestionSearchSession.cancel(.official)
        officialCandidates = []
    }

    private func toggleCandidateSource(
        defaultsKey: String,
        currentlyEnabled: Bool
    ) {
        UserDefaults.standard.set(!currentlyEnabled, forKey: defaultsKey)
        rebuildFuzzyConversionEngine()
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            return
        }
        selectedCandidateIndex = nil
        previewWindow.hide()
        updateMarkedText(in: inputClient)
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleExternalInformationPanel(_ sender: Any?) {
        UserDefaults.standard.set(
            !isExternalInformationPanelEnabled,
            forKey: Self.externalInformationPanelEnabledDefaultsKey
        )
        refreshExperimentalPreview()
    }

    @objc
    private func configureExternalInformationPanel(_ sender: Any?) {
        guard let settings = settingsDialogController.externalInformation(
            urlTemplate: externalInformationURLTemplate,
            displayDelay: externalInformationDisplayDelay
        ) else {
            return
        }
        UserDefaults.standard.set(
            settings.urlTemplate,
            forKey: Self.externalInformationURLTemplateDefaultsKey
        )
        UserDefaults.standard.set(
            settings.displayDelay,
            forKey: Self.externalInformationDisplayDelayDefaultsKey
        )
        refreshExperimentalPreview()
    }

    @objc
    private func toggleSystemDictionaryPreview(_ sender: Any?) {
        UserDefaults.standard.set(
            !isSystemDictionaryPreviewEnabled,
            forKey: Self.systemDictionaryPreviewEnabledDefaultsKey
        )
        refreshExperimentalPreview()
    }

    private func refreshExperimentalPreview() {
        previewWindow.hide()
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            return
        }
        if let selectedCandidateIndex,
           currentCandidates.indices.contains(selectedCandidateIndex) {
            showPreview(for: currentCandidates[selectedCandidateIndex])
        } else {
            showInputPreview(client: inputClient)
        }
    }

    @objc
    private func clearNextInputPredictionHistory(_ sender: Any?) {
        dismissNextInputSuggestions(clearMarkedTextIn: client())
        nextInputPredictionModel.removeAll()
        do {
            try nextInputPredictionWriter.writeImmediately(
                nextInputPredictionModel
            )
        } catch {
            NSLog(
                "次入力履歴の削除に失敗: %@",
                error.localizedDescription
            )
            NSSound.beep()
        }
    }

    @objc
    private func updateBasicDictionaryIfNeeded(_ sender: Any?) {
        guard basicDictionaryStatus != "確認中" else {
            return
        }

        basicDictionaryStatus = "確認中"
        let force = sender != nil
        Task { @MainActor [weak self] in
            do {
                guard let snapshot = try await Self
                    .basicDictionaryUpdateCoordinator
                    .fetchIfNeeded(force: force) else {
                    guard let self else {
                        return
                    }
                    basicDictionaryStatus =
                        "確認済み（\(basicEntries.count)読み）"
                    return
                }
                let cache = try Self.basicDictionaryCache()
                let currentRevision = try cache.loadMetadata()?.sourceRevision
                    ?? Self.bundledBasicDictionaryRevision()

                guard currentRevision.map({
                    snapshot.generatedAt > $0
                }) ?? true else {
                    if let self, basicEntries.isEmpty {
                        basicEntries = snapshot.entries
                        rebuildConversionEngine(basicDictionaryChanged: true)
                    }
                    self?.basicDictionaryStatus =
                        "最新版（\(snapshot.entries.count)読み）"
                    return
                }

                try cache.save(
                    dictionaryText: snapshot.dictionaryText,
                    metadata: DictionaryCacheMetadata(
                        syncedAt: Date(),
                        entryCount: snapshot.entries.count,
                        sourceRevision: snapshot.generatedAt,
                        sourceEntryCount: snapshot.sourceEntryCount
                    )
                )

                guard let self else {
                    return
                }
                basicEntries = snapshot.entries
                rebuildConversionEngine(basicDictionaryChanged: true)
                basicDictionaryStatus = "更新完了（\(snapshot.entries.count)読み）"

                if !inputBuffer.isEmpty, let inputClient = client() {
                    selectedCandidateIndex = nil
                    previewWindow.hide()
                    refreshCandidates(client: inputClient)
                }
            } catch {
                self?.basicDictionaryStatus = "確認失敗"
                NSLog("TKGJE基本辞書の更新に失敗: %@", error.localizedDescription)
            }
        }
    }

    private func handleSpace(space: String, client sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            if let selectedNextInputIndex,
               nextInputCandidates.indices.contains(selectedNextInputIndex) {
                let value = nextInputCandidates[selectedNextInputIndex]
                commit(value + space, to: sender, historyValue: value)
                return true
            }
            guard space == "　" else { return false }
            commit(space, to: sender)
            return true
        }
        let value = selectedCandidateValue ?? inputBuffer
        recordSelectedCandidate()
        commit(value + space, to: sender, historyValue: value)
        return true
    }

    private func handleTranslationSpace(
        space: String,
        client sender: Any
    ) -> Bool {
        guard !inputBuffer.isEmpty else {
            guard translationDraft != nil else {
                guard space == "　" else { return false }
                commit(space, to: sender)
                return true
            }
            translationDraft?.append(space)
            updateMarkedText(in: sender)
            showTranslationDraft(client: sender)
            return true
        }
        appendCurrentInputToTranslationDraft(suffix: space, client: sender)
        return true
    }

    private func isFullWidthSpaceShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(
            [.command, .control, .option, .shift]
        )
        return flags == [.shift]
    }

    private func handleTranslationReturn(client sender: Any) -> Bool {
        if !inputBuffer.isEmpty {
            appendCurrentInputToTranslationDraft(suffix: "", client: sender)
            return true
        }
        guard translationDraft != nil else { return false }
        return translateDraft(client: sender)
    }

    private func appendCurrentInputToTranslationDraft(
        suffix: String,
        client sender: Any
    ) {
        let value: String
        if let selectedCandidateValue {
            value = candidateValueForCommit(selectedCandidateValue)
                + conversionSuffix
        } else {
            value = inputBuffer
        }
        recordSelectedCandidate()
        translationDraft = (translationDraft ?? "")
            + value
            + suffix
        inputBuffer = ""
        inputCursor = 0
        currentCandidates = []
        selectedCandidateIndex = nil
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
        fuzzySuggestionWindow.hide()
        previewWindow.hide()
        updateMarkedText(in: sender)
        showTranslationDraft(client: sender)
    }

    private func showTranslationDraft(client sender: Any) {
        guard let translationDraft else { return }
        candidateWindow.show(
            candidates: [translationDraft],
            selectedIndex: nil,
            near: inputLocation(for: sender),
            guide: "↩ 翻訳して確定　Esc 日本語で確定\n⌥T 翻訳モード終了",
            modeTitle: "翻訳する日本語"
        )
    }

    private func translateDraft(client sender: Any) -> Bool {
        guard translationTask == nil,
              let source = translationDraft,
              !source.isEmpty else {
            return true
        }
        candidateWindow.show(
            candidates: [source],
            selectedIndex: nil,
            near: inputLocation(for: sender),
            guide: "翻訳中…",
            modeTitle: "翻訳する日本語"
        )
        translationTask = Task { @MainActor [weak self] in
            guard let self else { return }
#if canImport(Translation)
            if #available(macOS 15.0, *) {
                let provider = AppleTranslationCandidateProvider()
                let translated = await provider.translateJapaneseToEnglish(source)
                guard !Task.isCancelled,
                      self.translationDraft == source else {
                    self.translationTask = nil
                    return
                }
                if let translated {
                    let value = translated.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    if !value.isEmpty {
                        self.translationDraft = nil
                        self.translationTask = nil
                        self.commit(
                            value,
                            to: sender,
                            replacingMarkedText: true
                        )
                        return
                    }
                }
            }
#endif
            self.translationTask = nil
            self.showTranslationDraft(client: sender)
            NSSound.beep()
        }
        return true
    }

    private func finishTranslationDraftAsJapanese(client sender: Any) {
        translationTask?.cancel()
        translationTask = nil
        let currentInput: String
        if let selectedCandidateValue {
            currentInput = candidateValueForCommit(selectedCandidateValue)
                + conversionSuffix
        } else {
            currentInput = inputBuffer
        }
        let value = (translationDraft ?? "") + currentInput
        guard !value.isEmpty else { return }
        translationDraft = nil
        commit(value, to: sender, replacingMarkedText: true)
    }

    private func handleInputFormFunctionKey(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool {
        guard !inputBuffer.isEmpty else { return false }
        let form: InputForm
        let source: String
        let suffix: String
        switch event.keyCode {
        case 97:
            form = .hiragana
            source = conversionReading
            suffix = conversionSuffix
        case 98:
            form = .fullWidthKatakana
            source = conversionReading
            suffix = conversionSuffix
        case 100:
            form = .halfWidthKatakana
            source = conversionReading
            suffix = conversionSuffix
        case 101:
            form = .fullWidthAlphanumeric
            source = inputBuffer
            suffix = ""
        case 109:
            form = .halfWidthAlphanumeric
            source = inputBuffer
            suffix = ""
        default:
            return false
        }
        guard let converted = InputFormConverter.convert(source, to: form) else {
            return true
        }
        let candidate = converted + suffix
        let index: Int
        if let existingIndex = currentCandidates.firstIndex(of: candidate) {
            index = existingIndex
        } else {
            currentCandidates.insert(candidate, at: 0)
            index = 0
        }
        selectedCandidateIndex = index
        cancelAuxiliarySuggestionSearches()
        candidateWindow.hide()
        fuzzySuggestionWindow.hide()
        previewWindow.hide()
        setMarkedText(
            compositionPrefix + candidate,
            in: sender
        )
        return true
    }

    private func shouldDismissNextInputSuggestions(
        for event: NSEvent
    ) -> Bool {
        guard !nextInputCandidates.isEmpty else {
            return false
        }
        let nextInputControlKeyCodes: Set<UInt16> = [
            36, 48, 49, 53, 76, 123, 124, 125, 126
        ]
        return !nextInputControlKeyCodes.contains(event.keyCode)
    }

    private func commitSelectedNextInputBeforeNewInput(
        _ event: NSEvent,
        client sender: Any
    ) {
        guard
            shouldDismissNextInputSuggestions(for: event),
            let selectedNextInputIndex,
            nextInputCandidates.indices.contains(selectedNextInputIndex),
            event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
            let characters = event.characters,
            !characters.isEmpty
        else {
            return
        }
        commit(nextInputCandidates[selectedNextInputIndex], to: sender)
    }

    private func handleTab(_ event: NSEvent, client sender: Any) -> Bool {
        let flags = event.modifierFlags.intersection(
            [.command, .control, .option, .shift]
        )
        if inputBuffer.isEmpty {
            if selectedNextInputIndex != nil,
               flags.isEmpty || flags == [.shift] {
                let offset = flags.contains(.shift) ? -1 : 1
                return selectNextInputCandidate(offset: offset, client: sender)
            }
            if flags.isEmpty,
               beginReconversionIfPossible(client: sender) {
                return true
            }
            if (flags.isEmpty || flags == [.shift]),
               !nextInputCandidates.isEmpty {
                let offset = flags.contains(.shift) ? -1 : 1
                return selectNextInputCandidate(offset: offset, client: sender)
            }
            return false
        }

        guard flags.isEmpty || flags == [.shift] else { return false }
        guard !currentCandidates.isEmpty else {
            return true
        }
        let offset = event.modifierFlags.contains(.shift) ? -1 : 1
        let nextIndex = (
            (selectedCandidateIndex ?? (offset > 0 ? -1 : 0))
                + offset
                + currentCandidates.count
        ) % currentCandidates.count
        return selectCandidate(index: nextIndex, client: sender)
    }

    private func beginReconversionIfPossible(client sender: Any) -> Bool {
        guard let candidate = selectedText(from: sender) else { return false }
        let readings = reconversionReadings(for: candidate)
        guard let reading = readings.first else { return false }

        reconversionOriginal = candidate
        inputBuffer = reading
        inputCursor = reading.count
        selectedCandidateIndex = nil
        setMarkedText(reading, in: sender, selectionOffset: inputCursor)
        refreshCandidates(client: sender)
        guard !currentCandidates.isEmpty else {
            restoreReconversionOriginal(client: sender)
            return true
        }
        return selectCandidate(index: 0, client: sender)
    }

    private func reconversionReadings(for candidate: String) -> [String] {
        var seen = Set<String>()
        var result: [String] = []
        func append(_ readings: [String]) {
            for reading in readings where seen.insert(reading).inserted {
                result.append(reading)
            }
        }
        append(userConversionEngine.readings(for: candidate))
        if isExtensionDictionaryEnabled {
            append(extensionConversionEngine.readings(for: candidate))
        }
        append(basicConversionEngine.readings(for: candidate))
        append(supplementalConversionEngine.readings(for: candidate))
        append(imeConversionEngine.readings(for: candidate).compactMap(
            romanizedReading(from:)
        ))
        return result
    }

    private func romanizedReading(from kana: String) -> String? {
        guard var value = kana.applyingTransform(.toLatin, reverse: false)?
            .lowercased() else {
            return nil
        }
        let macrons: [(String, String)] = [
            ("ā", "a-"), ("ī", "i-"), ("ū", "u-"),
            ("ē", "e-"), ("ō", "o-")
        ]
        for (macron, replacement) in macrons {
            value = value.replacingOccurrences(of: macron, with: replacement)
        }
        value = value.replacingOccurrences(of: " ", with: "")
        return value.unicodeScalars.allSatisfy {
            $0.isASCII && ($0.properties.isAlphabetic || $0 == "-" || $0 == "'")
        } ? value : nil
    }

    private func selectedText(from sender: Any) -> String? {
        guard let textClient = sender as? IMKTextInput else { return nil }
        let range = textClient.selectedRange()
        guard range.location != NSNotFound, range.length > 0,
              let value = textClient.attributedSubstring(from: range)?.string,
              !value.isEmpty else {
            return nil
        }
        return value
    }

    private func restoreReconversionOriginal(client sender: Any) {
        guard let original = reconversionOriginal else { return }
        commit(original, to: sender, replacingMarkedText: true)
    }

    private func beginTabDictionaryRegistration(client sender: Any) -> Bool {
        tabDictionaryRegistration = TabDictionaryRegistration(
            originalInput: inputBuffer,
            reading: conversionReading.lowercased()
        )
        inputBuffer = ""
        inputCursor = 0
        currentCandidates = []
        previewWindow.hide()
        setMarkedText("", in: sender)
        showTabDictionaryRegistration(client: sender)
        return true
    }

    private func isTabDictionaryRegistrationShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(
            [.command, .control, .option, .shift]
        )
        return (event.keyCode == 36 || event.keyCode == 76)
            && flags == [.option]
    }

    private func handleTabDictionaryRegistration(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool {
        guard var registration = tabDictionaryRegistration else {
            return false
        }

        if handleInputFormFunctionKey(event, client: sender) {
            return true
        }

        switch event.keyCode {
        case 36, 76:
            let currentCandidate = registration.pastedCandidate
                ?? selectedCandidateValue
                ?? inputBuffer.nilIfEmpty
            if currentCandidate == nil,
               let confirmedCandidate = registration.confirmedCandidate {
                do {
                    try saveUserDictionaryEntry(
                        reading: registration.reading,
                        candidate: confirmedCandidate
                    )
                    tabDictionaryRegistration = nil
                    commit(
                        confirmedCandidate,
                        to: sender,
                        replacingMarkedText: true
                    )
                } catch {
                    NSLog(
                        "ユーザー辞書の保存に失敗: %@",
                        error.localizedDescription
                    )
                    NSSound.beep()
                }
                return true
            }
            guard let currentCandidate else {
                NSSound.beep()
                return true
            }
            registration.confirmedCandidate =
                (registration.confirmedCandidate ?? "") + currentCandidate
            registration.pastedCandidate = nil
            tabDictionaryRegistration = registration
            inputBuffer = ""
            inputCursor = 0
            currentCandidates = []
            selectedCandidateIndex = nil
            showTabDictionaryRegistration(client: sender)
            return true
        case 49:
            if inputBuffer.isEmpty,
               registration.pastedCandidate == nil {
                registration.confirmedCandidate =
                    (registration.confirmedCandidate ?? "") + " "
                tabDictionaryRegistration = registration
                setMarkedText(registration.confirmedCandidate ?? "", in: sender)
                showTabDictionaryRegistration(client: sender)
                return true
            }
            let currentCandidate = registration.pastedCandidate
                ?? selectedCandidateValue
                ?? inputBuffer
            registration.confirmedCandidate =
                (registration.confirmedCandidate ?? "")
                + currentCandidate
                + " "
            registration.pastedCandidate = nil
            tabDictionaryRegistration = registration
            inputBuffer = ""
            inputCursor = 0
            currentCandidates = []
            selectedCandidateIndex = nil
            setMarkedText(registration.confirmedCandidate ?? "", in: sender)
            showTabDictionaryRegistration(client: sender)
            return true
        case 48:
            return handleTab(event, client: sender)
        case 123:
            return selectedCandidateIndex == nil
                ? moveInputCursor(by: -1, client: sender)
                : moveCandidate(.left, client: sender)
        case 124:
            return selectedCandidateIndex == nil
                ? moveInputCursor(by: 1, client: sender)
                : moveCandidate(.right, client: sender)
        case 125:
            return selectedCandidateIndex == nil
                ? false
                : moveCandidate(.down, client: sender)
        case 126:
            return selectedCandidateIndex == nil
                ? false
                : moveCandidate(.up, client: sender)
        case 51:
            if inputBuffer.isEmpty,
               registration.pastedCandidate == nil,
               var confirmedCandidate = registration.confirmedCandidate,
               !confirmedCandidate.isEmpty {
                confirmedCandidate = InputBufferDeletion.deletingBackward(
                    from: confirmedCandidate,
                    unit: deletionUnit(for: event)
                )
                registration.confirmedCandidate = confirmedCandidate.nilIfEmpty
                tabDictionaryRegistration = registration
                setMarkedText(confirmedCandidate, in: sender)
                showTabDictionaryRegistration(client: sender)
                return true
            }
            registration.pastedCandidate = nil
            tabDictionaryRegistration = registration
            if inputBuffer.isEmpty {
                return true
            }
            return deleteBackward(
                from: sender,
                unit: deletionUnit(for: event)
            )
        case 53:
            tabDictionaryRegistration = nil
            inputBuffer = registration.originalInput
            inputCursor = inputBuffer.count
            currentCandidates = []
            selectedCandidateIndex = nil
            updateMarkedText(in: sender)
            refreshCandidates(client: sender)
            return true
        default:
            break
        }

        if isPasteShortcut(event) {
            let pasted = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !pasted.isEmpty else {
                NSSound.beep()
                return true
            }
            registration.pastedCandidate = pasted
            tabDictionaryRegistration = registration
            inputBuffer = ""
            inputCursor = 0
            currentCandidates = []
            selectedCandidateIndex = nil
            setMarkedText(
                (registration.confirmedCandidate ?? "") + pasted,
                in: sender
            )
            showTabDictionaryRegistration(client: sender)
            return true
        }

        guard
            event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
            let characters = event.characters,
            !characters.isEmpty
        else {
            return true
        }
        if let selectedValue = selectedCandidateValue {
            registration.confirmedCandidate =
                (registration.confirmedCandidate ?? "") + selectedValue
            inputBuffer = ""
            inputCursor = 0
            currentCandidates = []
            selectedCandidateIndex = nil
        }
        registration.pastedCandidate = nil
        tabDictionaryRegistration = registration
        insertIntoInputBuffer(characters)
        selectedCandidateIndex = nil
        setMarkedText(
            (registration.confirmedCandidate ?? "") + inputBuffer,
            in: sender,
            selectionOffset: (registration.confirmedCandidate ?? "")
                .utf16.count + inputCursor
        )
        refreshCandidates(client: sender)
        return true
    }

    private func showTabDictionaryRegistration(client sender: Any) {
        guard let registration = tabDictionaryRegistration else {
            return
        }
        if let confirmedCandidate = registration.confirmedCandidate,
           inputBuffer.isEmpty,
           registration.pastedCandidate == nil {
            candidateWindow.show(
                candidates: [
                    "読み: \(registration.reading)",
                    "登録: \(confirmedCandidate)"
                ],
                selectedIndex: nil,
                near: inputLocation(for: sender),
                guide: "↩ 登録を確定　Esc 中止",
                modeTitle: "登録したい文字列を入力"
            )
            return
        }
        let candidate = registration.pastedCandidate ?? inputBuffer.nilIfEmpty
        let candidateDisplay = candidate == nil
            ? "候補を入力 / ⌘Vで貼付"
            : candidate!
        candidateWindow.show(
            candidates: [
                "読み: \(registration.reading)",
                candidateDisplay
            ],
            selectedIndex: nil,
            near: inputLocation(for: sender),
            guide: "↩ 入力を追加　⌘V 貼付　Esc 中止",
            modeTitle: "登録したい文字列を入力"
        )
    }

    private func shouldSuppressActivationSpace(_ event: NSEvent) -> Bool {
        let switchModifiers: NSEvent.ModifierFlags = [
            .command, .control, .option
        ]
        if !event.modifierFlags.intersection(switchModifiers).isEmpty {
            return true
        }
        guard let activatedAt else {
            return false
        }
        return ProcessInfo.processInfo.systemUptime - activatedAt < 0.2
    }

    private func moveCandidate(
        _ direction: CandidateNavigationDirection,
        client sender: Any
    ) -> Bool {
        guard !inputBuffer.isEmpty else {
            return moveNextInputCandidate(direction, client: sender)
        }

        guard !currentCandidates.isEmpty else {
            return true
        }

        guard let selectedCandidateIndex else {
            return selectCandidate(index: 0, client: sender)
        }

        let pageStart = selectedCandidateIndex
            / Self.maximumCandidateCount
            * Self.maximumCandidateCount
        let localIndex = selectedCandidateIndex - pageStart
        let fallbackOffset: Int
        switch direction {
        case .left:
            fallbackOffset = -1
        case .right:
            fallbackOffset = 1
        case .up:
            fallbackOffset = -Self.maximumCandidateCount
        case .down:
            fallbackOffset = Self.maximumCandidateCount
        }
        let nextIndex: Int
        if let localNextIndex = candidateWindow.adjacentIndex(
            from: localIndex,
            direction: direction
        ) {
            nextIndex = pageStart + localNextIndex
        } else {
            nextIndex = (
                selectedCandidateIndex
                    + fallbackOffset
                    + currentCandidates.count
            ) % currentCandidates.count
        }

        return selectCandidate(index: nextIndex, client: sender)
    }

    private func selectCandidate(index: Int, client sender: Any) -> Bool {
        guard currentCandidates.indices.contains(index) else {
            return true
        }

        selectedCandidateIndex = index
        cancelAuxiliarySuggestionSearches()
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
        fuzzySuggestionWindow.hide()
        showCandidateWindow(client: sender)
        let registrationPrefix = tabDictionaryRegistration?
            .confirmedCandidate ?? translationDraft ?? ""
        setMarkedText(
            registrationPrefix + currentCandidates[index] + conversionSuffix,
            in: sender
        )
        showPreview(for: currentCandidates[index])
        return true
    }

    private func refreshCandidates(client sender: Any) {
        cancelFuzzySuggestionSearch()
        fuzzySuggestionWindow.hide()
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
        let calculatorCandidates = CalculatorCandidateGenerator.candidates(
            for: inputBuffer
        )
        if !calculatorCandidates.isEmpty {
            currentCandidates = calculatorCandidates
            showCandidateWindow(client: sender)
            return
        }
        let numberCandidates = JapaneseNumberConverter.candidates(
            for: inputBuffer
        )
        if !numberCandidates.isEmpty {
            currentCandidates = numberCandidates
            showCandidateWindow(client: sender)
            return
        }
        let symbolCandidates = JapaneseSymbolConverter.candidates(
            for: inputBuffer
        )
        if !symbolCandidates.isEmpty {
            currentCandidates = symbolCandidates
            showCandidateWindow(client: sender)
            return
        }

        let suggestionInput = conversionReading
        defer {
            updateOfficialCandidatesIfNeeded(for: suggestionInput)
        }

        let normalizedReading = RomanizedReadingNormalizer.dictionaryReading(
            from: conversionReading
        )
        let lookupReadings =
            RomanizedReadingNormalizer.dictionaryLookupReadings(
                from: normalizedReading
            )
        let dateTimeCandidates = isDateTimeCandidatesEnabled
            ? DateTimeCandidateGenerator().candidates(
                for: normalizedReading,
                formats: DateTimeCandidateGenerator.Formats(
                    date: dateCandidateFormats,
                    time: timeCandidateFormats,
                    dateTime: dateTimeCandidateFormats
                )
            )
            : []
        let userCandidates = mergedCandidateGroups(
            lookup: { userConversionEngine.candidateGroups(matching: $0) },
            readings: lookupReadings
        )
        let extensionCandidates = isExtensionDictionaryEnabled
            ? mergedCandidateGroups(
                lookup: {
                    extensionConversionEngine.candidateGroups(matching: $0)
                },
                readings: lookupReadings
            )
            : DictionaryCandidateGroups()
        let basicCandidates = mergedCandidateGroups(
            lookup: { basicConversionEngine.candidateGroups(matching: $0) },
            readings: lookupReadings
        )
        let kanaLookupReadings = lookupReadings.compactMap {
            romajiConverter.hiragana(from: $0)
        }
        let imeCandidates = mergedCandidateGroups(
            lookup: {
                imeConversionEngine.candidateGroups(
                    matching: $0,
                    limit: Self.maximumIMEDictionaryPrefixCandidates
                )
            },
            readings: kanaLookupReadings
        )
        let supplementalCandidates = mergedCandidateGroups(
            lookup: {
                supplementalConversionEngine.candidateGroups(matching: $0)
            },
            readings: lookupReadings
        )
        let englishCandidates = isEnglishCompletionEnabled
            ? englishCompletions(for: conversionReading)
            : []
        let remoteCandidates = suggestionSearchSession.query(for: .official)
            == conversionReading
            ? officialCandidates
            : []
        let inflectionCandidates = mergedCandidates(
            lookup: {
                verbInflectionGenerator.candidates(for: $0)
                    + VerbInflectionCandidateGenerator.candidates(for: $0) {
                        imeConversionEngine.candidates(for: $0)
                    }
            },
            readings: lookupReadings
        )
        var kanaCandidates: [String] = []
        if let hiragana = romajiConverter.hiragana(
            from: conversionReading
        ) {
            let katakana = romajiConverter.katakana(
                from: conversionReading
            )
            kanaCandidates = [hiragana, katakana]
                .compactMap { $0 }
        }
        let directCandidates = userCandidates.exact
            + extensionCandidates.exact
            + dateTimeCandidates
            + imeCandidates.exact
            + basicCandidates.exact
            + inflectionCandidates
            + supplementalCandidates.exact
        let otherCandidates = userCandidates.prefix
            + extensionCandidates.prefix
            + supplementalCandidates.prefix
            + englishCandidates
            + remoteCandidates
            + imeCandidates.prefix
            + basicCandidates.prefix
        let contextualCandidates = isNextInputPredictionEnabled
            ? nextInputPredictionModel.candidatesAfterLastInput(
                limit: NextInputPredictionModel.maximumFollowersPerContext
            )
            : []
        currentCandidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: kanaCandidates,
                direct: directCandidates,
                other: otherCandidates,
                recencyRanks: candidateSelectionHistory.ranks,
                contextualCandidates: contextualCandidates,
                prioritizeKana: kanaCandidates.first?.count == 1
            )
        )

        guard !currentCandidates.isEmpty else {
            selectedCandidateIndex = nil
            candidateWindow.hide()
            showInputPreview(client: sender)
            return
        }

        showCandidateWindow(client: sender)
        let auxiliaryAnchorFrame = candidateAndInputFrame(for: sender)
        updateFuzzySuggestionsIfNeeded(near: auxiliaryAnchorFrame)
        showInputPreview(client: sender)
    }

    private func updateFuzzySuggestionsIfNeeded(near anchorFrame: NSRect) {
        suggestionSearchSession.cancel(.fuzzy)
        guard isFuzzySuggestionsEnabled,
              conversionReading.count >= 2 else {
            fuzzySuggestionWindow.hide()
            fuzzySuggestions = []
            selectedFuzzySuggestionIndex = nil
            return
        }

        let query = conversionReading
        let imeDictionary = imeConversionEngine
        let visibleCandidates = Set(currentCandidates)
        let token = suggestionSearchSession.begin(.fuzzy, query: query)
        let task = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(80))
                let matches = await Task.detached(priority: .userInitiated) {
                    let keyboardMatches =
                        RomajiKeyboardTypoGenerator.dictionaryMatches(
                            for: query,
                            dictionary: imeDictionary
                        )
                    var seenReadings = Set<String>()
                    let fuzzyMatches = Self.fuzzyEngineRepository.matches(
                        for: query,
                        limit: 6
                    )
                    let combined = (keyboardMatches
                        + fuzzyMatches).filter {
                            seenReadings.insert($0.reading).inserted
                        }
                    return Array(FuzzyConversionMatchFilter.filtered(
                        combined,
                        excluding: visibleCandidates
                    ))
                }.value
                try Task.checkCancellation()
                guard let self,
                      suggestionSearchSession.isCurrent(token),
                      conversionReading == query,
                      isFuzzySuggestionsEnabled else {
                    return
                }
                applySpellingSuggestions(matches, near: anchorFrame)
            } catch is CancellationError {
                return
            } catch {
                NSLog("誤入力補完に失敗: %@", error.localizedDescription)
            }
        }
        suggestionSearchSession.attach(task, to: token)
    }

    private func applySpellingSuggestions(
        _ matches: [FuzzyConversionMatch],
        near anchorFrame: NSRect
    ) {
        let spellingSuggestions = matches.compactMap { match in
            match.candidates.first.map {
                FuzzySuggestion(
                    candidate: $0,
                    reading: match.reading,
                    distance: match.distance
                )
            }
        }
        let orderedIndices = CandidateRecencyOrderer.orderedIndices(
            spellingSuggestions.map(\.candidate),
            ranks: candidateSelectionHistory.ranks
        )
        fuzzySuggestions = Array(orderedIndices
            .prefix(3)
            .map { spellingSuggestions[$0] })
        selectedFuzzySuggestionIndex = nil
        guard !fuzzySuggestions.isEmpty else {
            fuzzySuggestionWindow.hide()
            return
        }
        fuzzySuggestionWindow.show(
            suggestions: fuzzySuggestions,
            selectedIndex: nil,
            near: anchorFrame
        )
    }

    private func handleFuzzySuggestionSelection(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool? {
        guard interactionState == .selectingFuzzySuggestion,
              let selectedFuzzySuggestionIndex,
              fuzzySuggestions.indices.contains(selectedFuzzySuggestionIndex) else {
            return nil
        }
        switch event.keyCode {
        case 36, 76:
            let candidate = fuzzySuggestions[selectedFuzzySuggestionIndex].candidate
            recordCandidateSelection(candidate)
            commit(candidate + conversionSuffix, to: sender)
            return true
        case 48, 125, 124:
            let next = (selectedFuzzySuggestionIndex + 1)
                % fuzzySuggestions.count
            return selectFuzzySuggestion(index: next, client: sender)
        case 49:
            let candidate = fuzzySuggestions[selectedFuzzySuggestionIndex].candidate
            recordCandidateSelection(candidate)
            commit(candidate + conversionSuffix + " ", to: sender)
            return true
        case 126, 123:
            let next = (
                selectedFuzzySuggestionIndex
                    - 1
                    + fuzzySuggestions.count
            ) % fuzzySuggestions.count
            return selectFuzzySuggestion(index: next, client: sender)
        case 53:
            self.selectedFuzzySuggestionIndex = nil
            updateMarkedText(in: sender)
            showCandidateWindow(client: sender)
            fuzzySuggestionWindow.show(
                suggestions: fuzzySuggestions,
                selectedIndex: nil,
                near: candidateAndInputFrame(for: sender)
            )
            return true
        default:
            let flags = event.modifierFlags.intersection([
                .command, .control, .option
            ])
            guard flags.isEmpty,
                  let characters = event.characters,
                  !characters.isEmpty else {
                return false
            }
            let candidate = fuzzySuggestions[selectedFuzzySuggestionIndex].candidate
            recordCandidateSelection(candidate)
            commit(candidate + conversionSuffix, to: sender)
            return nil
        }
    }

    private func isFuzzySuggestionEntryShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(
            [.command, .control, .option, .shift]
        )
        return event.keyCode == 48 && flags == [.shift]
    }

    private func selectFuzzySuggestion(index: Int, client sender: Any) -> Bool {
        guard fuzzySuggestions.indices.contains(index) else {
            return true
        }
        selectedFuzzySuggestionIndex = index
        candidateWindow.clearSelection()
        let suggestion = fuzzySuggestions[index]
        setMarkedText(suggestion.candidate + conversionSuffix, in: sender)
        fuzzySuggestionWindow.show(
            suggestions: fuzzySuggestions,
            selectedIndex: index,
            near: candidateAndInputFrame(for: sender)
        )
        showPreview(for: suggestion.candidate)
        return true
    }

    private func englishCompletions(for input: String) -> [String] {
        guard
            !input.isEmpty,
            input.unicodeScalars.allSatisfy({
                CharacterSet.letters.contains($0) && $0.isASCII
            })
        else {
            return []
        }

        let lookupInput = input.lowercased()
        let candidates = NSSpellChecker.shared.completions(
            forPartialWordRange: NSRange(
                location: 0,
                length: lookupInput.utf16.count
            ),
            in: lookupInput,
            language: "en",
            inSpellDocumentWithTag: 0
        ) ?? []
        return candidates.map {
            EnglishCandidateCaseRestorer.restore(
                typedInput: input,
                in: $0
            )
        }
    }

    private func updateOfficialCandidatesIfNeeded(for input: String) {
        guard isWikipediaSuggestionsEnabled || isAppleTranslationEnabled,
              input.count >= 2,
              suggestionSearchSession.query(for: .official) != input else {
            return
        }
        officialCandidates = []
        let japaneseInput = romajiConverter.hiragana(from: input) ?? input
        let token = suggestionSearchSession.begin(.official, query: input)
        let task = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                guard let self else { return }
                async let wikipedia: [String] = isWikipediaSuggestionsEnabled
                    ? (try? await WikipediaSuggestionClient().suggestions(for: japaneseInput)) ?? []
                    : []
                let apple = await appleTranslationCandidate(
                    for: japaneseInput,
                    sentenceMode: false
                )
                let suggestions = await wikipedia + apple
                try Task.checkCancellation()
                guard suggestionSearchSession.isCurrent(token),
                      isWikipediaSuggestionsEnabled || isAppleTranslationEnabled,
                      conversionReading == input else {
                    return
                }
                var seen = Set<String>()
                officialCandidates = suggestions.filter { seen.insert($0).inserted }
                if let inputClient = client() {
                    refreshCandidates(client: inputClient)
                }
            } catch is CancellationError {
                return
            } catch {
                NSLog(
                    "公式外部候補の取得に失敗: %@",
                    error.localizedDescription
                )
            }
        }
        suggestionSearchSession.attach(task, to: token)
    }

    private func appleTranslationCandidate(
        for text: String,
        sentenceMode: Bool
    ) async -> [String] {
        guard isAppleTranslationEnabled || sentenceMode else { return [] }
#if canImport(Translation)
        if #available(macOS 15.0, *) {
            let provider = await MainActor.run {
                AppleTranslationCandidateProvider()
            }
            if let value = await provider.translateJapaneseToEnglish(text) {
                if sentenceMode {
                    let trimmed = value.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    )
                    return trimmed.isEmpty ? [] : [trimmed]
                }
                if let normalized = TranslationCandidateNormalizer
                    .wordCandidate(from: value) {
                    return [normalized]
                }
            }
        }
#endif
        return []
    }

    private func isWebSearchShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        return flags == [.command]
            && (event.keyCode == 36 || event.keyCode == 76)
    }

    private func isOpenExternalInformationShortcut(
        _ event: NSEvent
    ) -> Bool {
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        return flags == [.command]
            && (event.keyCode == 31
                || event.charactersIgnoringModifiers?.lowercased() == "o")
    }

    private func openSelectedWebSearch(client sender: Any) -> Bool {
        guard isWebSearchEnabled,
              let selectedCandidateIndex,
              currentCandidates.indices.contains(selectedCandidateIndex) else {
            return false
        }
        let candidate = currentCandidates[selectedCandidateIndex]
        guard let template = try? SearchURLTemplate(webSearchTemplate),
              let url = try? template.url(for: candidate) else {
            return false
        }
        recordCandidateSelection(candidate)
        commit(candidateValueForCommit(candidate), to: sender)
        NSWorkspace.shared.open(url)
        return true
    }

    private func saveUserDictionaryEntry(
        reading: String,
        candidate: String
    ) throws {
        userEntries = UserDictionaryEditor.adding(
            reading: reading,
            candidate: candidate,
            to: userEntries
        )
        let cache = try Self.userDictionaryCache()
        try cache.save(
            dictionaryText: DictionarySerializer.text(from: userEntries),
            metadata: DictionaryCacheMetadata(
                syncedAt: Date(),
                entryCount: userEntries.count
            )
        )
        rebuildConversionEngine()
    }

    private func removeSelectedUserDictionaryCandidate(client sender: Any) {
        guard
            let selectedCandidateIndex,
            currentCandidates.indices.contains(selectedCandidateIndex)
        else {
            NSSound.beep()
            return
        }
        let candidate = currentCandidates[selectedCandidateIndex]
        let updatedEntries = UserDictionaryEditor.removing(
            candidate: candidate,
            from: userEntries
        )
        guard updatedEntries != userEntries else {
            NSSound.beep()
            return
        }

        do {
            userEntries = updatedEntries
            try persistUserDictionary()
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(candidate, forType: .string)
            self.selectedCandidateIndex = nil
            updateMarkedText(in: sender)
            refreshCandidates(client: sender)
        } catch {
            NSLog(
                "ユーザー辞書候補の削除に失敗: %@",
                error.localizedDescription
            )
            userEntries = Self.loadUserEntries()
            rebuildConversionEngine()
            NSSound.beep()
        }
    }

    private func persistUserDictionary() throws {
        let cache = try Self.userDictionaryCache()
        try cache.save(
            dictionaryText: DictionarySerializer.text(from: userEntries),
            metadata: DictionaryCacheMetadata(
                syncedAt: Date(),
                entryCount: userEntries.count
            )
        )
        rebuildConversionEngine()
    }

    private func clearCompositionForSystemPaste(in sender: Any) {
        guard let textClient = sender as? IMKTextInput else {
            return
        }
        textClient.setMarkedText(
            "",
            selectionRange: NSRange(location: 0, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        inputBuffer = ""
        inputCursor = 0
        reconversionOriginal = nil
        tabDictionaryRegistration = nil
        currentCandidates = []
        selectedCandidateIndex = nil
        suggestionSearchSession.cancelAll()
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
        candidateWindow.hide()
        fuzzySuggestionWindow.hide()
        previewWindow.hide()
    }

    private func isSystemUndoRedoShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        guard flags == [.command] || flags == [.command, .shift] else {
            return false
        }
        return event.keyCode == 6
            || event.charactersIgnoringModifiers?.lowercased() == "z"
    }

    private func isPasteShortcut(
        _ event: NSEvent
    ) -> Bool {
        let deviceIndependentFlags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        guard deviceIndependentFlags == [.command] else {
            return false
        }
        return event.keyCode == 9
            || event.charactersIgnoringModifiers?.lowercased() == "v"
    }

    private func isUserDictionaryDeletionShortcut(_ event: NSEvent) -> Bool {
        let deviceIndependentFlags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        guard deviceIndependentFlags == [.command] else {
            return false
        }
        return event.keyCode == 7
            || event.charactersIgnoringModifiers?.lowercased() == "x"
    }

    private func isTranslationModeShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        return flags == [.option]
            && (event.keyCode == 17
                || event.charactersIgnoringModifiers?.lowercased() == "t")
    }

    private func showCandidateWindow(client sender: Any) {
        let selectedIndex = selectedCandidateIndex ?? 0
        let pageStart = selectedIndex / Self.maximumCandidateCount
            * Self.maximumCandidateCount
        let pageEnd = min(
            pageStart + Self.maximumCandidateCount,
            currentCandidates.count
        )
        guard pageStart < pageEnd else {
            candidateWindow.hide()
            return
        }

        let isDictionaryRegistration = tabDictionaryRegistration != nil
        let isTranslationInput = isTranslationModeEnabled
        let guide: String
        if isDictionaryRegistration {
            guide = selectedCandidateIndex == nil
                ? "Tab 候補選択　↩ 入力を追加\nEsc 登録中止"
                : "Tab / ⇧Tab / 矢印 移動\n↩ 入力を追加　Esc 登録中止"
        } else if isTranslationInput {
            guide = selectedCandidateIndex == nil
                ? "Tab 候補選択　↩ 日本語を追加\nEsc 日本語で確定　⌥T 翻訳モード終了"
                : "Tab / ⇧Tab / 矢印 移動　↩ 日本語を追加\nEsc 日本語で確定　⌥T 翻訳モード終了"
        } else {
            guide = selectedCandidateIndex == nil
                ? "Tab 選択　⌥↩ 辞書登録\nF6–F10 文字種変換　⌘O 外部ページ"
                : "Tab / ⇧Tab / 矢印 移動　↩ 確定　Esc 解除\n⌘X 削除　⌘↩ Web検索　⌘O 外部ページ"
        }

        candidateWindow.show(
            candidates: currentCandidates[pageStart..<pageEnd].map {
                candidateValueForCommit($0)
            },
            selectedIndex: selectedCandidateIndex.map { $0 - pageStart },
            near: inputLocation(for: sender),
            guide: guide,
            modeTitle: isDictionaryRegistration
                ? "登録したい文字列を入力"
                : (isTranslationInput ? "翻訳する日本語" : nil)
        )
    }

    private func inputLocation(for sender: Any) -> NSRect {
        guard let textClient = sender as? IMKTextInput else {
            return .zero
        }

        var lineRect = NSRect.zero
        _ = textClient.attributes(
            forCharacterIndex: 0,
            lineHeightRectangle: &lineRect
        )
        return lineRect
    }

    private func candidateAndInputFrame(for sender: Any) -> NSRect {
        let inputFrame = inputLocation(for: sender)
        guard inputFrame != .zero else {
            return candidateWindow.frame
        }
        return candidateWindow.frame.union(inputFrame)
    }

    private func commitFirstCandidateOrInput(to sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            guard
                let selectedNextInputIndex,
                nextInputCandidates.indices.contains(selectedNextInputIndex)
            else {
                return false
            }
            commit(nextInputCandidates[selectedNextInputIndex], to: sender)
            return true
        }

        let value = selectedCandidateValue ?? inputBuffer
        recordSelectedCandidate()
        commit(value, to: sender)
        return true
    }

    private func recordSelectedCandidate() {
        guard
            let selectedCandidateIndex,
            currentCandidates.indices.contains(selectedCandidateIndex)
        else {
            return
        }
        recordCandidateSelection(currentCandidates[selectedCandidateIndex])
    }

    private func recordCandidateSelection(_ candidate: String) {
        candidateSelectionHistory.record(candidate)
        candidateSelectionHistoryWriter.schedule(
            candidateSelectionHistory.ranks
        )
    }

    private func candidatesOrderedByRecency(
        _ candidates: [String]
    ) -> [String] {
        CandidateRecencyOrderer.ordered(
            candidates,
            ranks: candidateSelectionHistory.ranks
        )
    }

    private func mergedCandidates(
        lookup: (String) -> [String],
        readings: [String]
    ) -> [String] {
        var seen = Set<String>()
        return readings.flatMap(lookup).filter {
            seen.insert($0).inserted
        }
    }

    private func mergedCandidateGroups(
        lookup: (String) -> DictionaryCandidateGroups,
        readings: [String]
    ) -> DictionaryCandidateGroups {
        var exact: [String] = []
        var prefix: [String] = []
        var exactSet = Set<String>()
        var prefixSet = Set<String>()

        for reading in readings {
            let groups = lookup(reading)
            for candidate in groups.exact
            where exactSet.insert(candidate).inserted {
                exact.append(candidate)
            }
            for candidate in groups.prefix
            where prefixSet.insert(candidate).inserted {
                prefix.append(candidate)
            }
        }

        prefix.removeAll { exactSet.contains($0) }
        return DictionaryCandidateGroups(exact: exact, prefix: prefix)
    }

    private func deletionUnit(for event: NSEvent) -> InputBufferDeletionUnit {
        if event.modifierFlags.contains(.command) {
            return .all
        }
        if event.modifierFlags.contains(.option) {
            return .word
        }
        return .character
    }

    private func deleteBackward(
        from sender: Any,
        unit: InputBufferDeletionUnit = .character
    ) -> Bool {
        guard !inputBuffer.isEmpty else {
            return deleteBackwardFromTranslationDraft(
                client: sender,
                unit: unit
            )
        }

        var editor = InputBufferEditor(
            value: inputBuffer,
            cursor: inputCursor
        )
        editor.deleteBackward(unit: unit)
        inputBuffer = editor.value
        inputCursor = editor.cursor
        selectedCandidateIndex = nil
        previewWindow.hide()
        setMarkedText(
            compositionPrefix + inputBuffer,
            in: sender,
            selectionOffset: compositionPrefix.utf16.count + inputCursor
        )
        refreshCandidates(client: sender)
        return true
    }

    private func deleteBackwardFromTranslationDraft(
        client sender: Any,
        unit: InputBufferDeletionUnit
    ) -> Bool {
        guard let draft = translationDraft else {
            return false
        }

        translationTask?.cancel()
        translationTask = nil
        let updatedDraft = InputBufferDeletion.deletingBackward(
            from: draft,
            unit: unit
        )
        translationDraft = updatedDraft.nilIfEmpty
        selectedCandidateIndex = nil
        currentCandidates = []
        fuzzySuggestionWindow.hide()
        previewWindow.hide()
        updateMarkedText(in: sender)

        if translationDraft == nil {
            candidateWindow.hide()
        } else {
            showTranslationDraft(client: sender)
        }
        return true
    }

    private func cancelInput(in sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            guard !nextInputCandidates.isEmpty else {
                return false
            }
            dismissNextInputSuggestions(clearMarkedTextIn: sender)
            return true
        }

        if reconversionOriginal != nil {
            restoreReconversionOriginal(client: sender)
            return true
        }

        let wasSelectingCandidate = selectedCandidateIndex != nil
        selectedCandidateIndex = nil
        candidateWindow.clearSelection()
        updateMarkedText(in: sender)
        if wasSelectingCandidate {
            refreshCandidates(client: sender)
            return true
        }
        showInputPreview(client: sender)
        return true
    }

    private func commit(
        _ value: String,
        to sender: Any,
        replacingMarkedText: Bool = false,
        historyValue: String? = nil
    ) {
        guard let textClient = sender as? IMKTextInput else {
            return
        }

        let markedRange = textClient.markedRange()
        let replacementRange = replacingMarkedText
            && markedRange.location != NSNotFound
            && markedRange.length > 0
            ? markedRange
            : NSRange(location: NSNotFound, length: NSNotFound)
        textClient.insertText(
            value,
            replacementRange: replacementRange
        )
        suggestionSearchSession.cancelAll()
        inputBuffer = ""
        inputCursor = 0
        reconversionOriginal = nil
        tabDictionaryRegistration = nil
        currentCandidates = []
        selectedCandidateIndex = nil
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
        candidateWindow.hide()
        fuzzySuggestionWindow.hide()
        previewWindow.hide()
        recordCommittedInput(historyValue ?? value, client: sender)
    }

    private func resetTransientInteractionState() {
        candidateWindow.hide()
        fuzzySuggestionWindow.hide()
        previewWindow.hide()
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
        nextInputCandidates = []
        selectedNextInputIndex = nil
        nextInputDismissTimer?.invalidate()
        nextInputDismissTimer = nil
        suggestionSearchSession.cancelAll()
    }

    private func cancelFuzzySuggestionSearch() {
        suggestionSearchSession.cancel(.fuzzy)
    }

    private func cancelAuxiliarySuggestionSearches() {
        suggestionSearchSession.cancel(.fuzzy)
    }

    private func flushPendingHistoryWrites() {
        candidateSelectionHistoryWriter.flush()
        nextInputPredictionWriter.flush()
    }

    private func moveNextInputCandidate(
        _ direction: CandidateNavigationDirection,
        client sender: Any
    ) -> Bool {
        guard !nextInputCandidates.isEmpty else {
            return false
        }

        guard let selectedNextInputIndex else {
            return false
        }

        if let adjacentIndex = candidateWindow.adjacentIndex(
            from: selectedNextInputIndex,
            direction: direction
        ) {
            return selectNextInputCandidate(
                index: adjacentIndex,
                client: sender
            )
        }

        let offset: Int
        switch direction {
        case .left, .up:
            offset = -1
        case .right, .down:
            offset = 1
        }
        return selectNextInputCandidate(offset: offset, client: sender)
    }

    private func selectNextInputCandidate(
        offset: Int,
        client sender: Any
    ) -> Bool {
        let currentIndex = selectedNextInputIndex
            ?? (offset > 0 ? -1 : 0)
        let nextIndex = (
            currentIndex + offset + nextInputCandidates.count
        ) % nextInputCandidates.count
        return selectNextInputCandidate(index: nextIndex, client: sender)
    }

    private func selectNextInputCandidate(
        index: Int,
        client sender: Any
    ) -> Bool {
        guard nextInputCandidates.indices.contains(index) else {
            return true
        }
        selectedNextInputIndex = index
        candidateWindow.select(index: index)
        setMarkedText(nextInputCandidates[index], in: sender)
        showPreview(for: nextInputCandidates[index])
        scheduleNextInputDismissal()
        return true
    }

    private func recordCommittedInput(_ value: String, client sender: Any) {
        guard isNextInputPredictionEnabled else {
            return
        }
        nextInputPredictionModel.record(value)
        nextInputPredictionWriter.schedule(nextInputPredictionModel)

        nextInputCandidates = nextInputPredictionModel.candidates(
            after: value,
            limit: Self.maximumCandidateCount
        )
        selectedNextInputIndex = nil
        guard !nextInputCandidates.isEmpty else {
            nextInputDismissTimer?.invalidate()
            nextInputDismissTimer = nil
            return
        }
        candidateWindow.show(
            candidates: nextInputCandidates,
            selectedIndex: nil,
            near: inputLocation(for: sender),
            guide: "Tab 選択　Esc 閉じる\n選択後はTab / ⇧Tab / 矢印 移動　↩ 確定"
        )
        scheduleNextInputDismissal()
    }

    private func scheduleNextInputDismissal() {
        nextInputDismissTimer?.invalidate()
        nextInputDismissTimer = Timer.scheduledTimer(
            withTimeInterval: Self.nextInputDismissInterval,
            repeats: false
        ) { [weak self] _ in
            guard let self else {
                return
            }
            dismissNextInputSuggestions(clearMarkedTextIn: client())
        }
    }

    private func dismissNextInputSuggestions(
        clearMarkedTextIn sender: Any?
    ) {
        nextInputDismissTimer?.invalidate()
        nextInputDismissTimer = nil
        if selectedNextInputIndex != nil, let sender {
            setMarkedText("", in: sender)
        }
        nextInputCandidates = []
        selectedNextInputIndex = nil
        candidateWindow.hide()
        previewWindow.hide()
    }

    private func updateMarkedText(in sender: Any) {
        setMarkedText(
            compositionPrefix + inputBuffer,
            in: sender,
            selectionOffset: compositionPrefix.utf16.count + inputCursor
        )
    }

    private var compositionPrefix: String {
        tabDictionaryRegistration?.confirmedCandidate
            ?? translationDraft
            ?? ""
    }

    private func setMarkedText(
        _ value: String,
        in sender: Any,
        selectionOffset: Int? = nil
    ) {
        guard let textClient = sender as? IMKTextInput else {
            return
        }

        let markedRange = textClient.markedRange()
        let replacementRange = markedRange.location != NSNotFound
            && markedRange.length > 0
            ? markedRange
            : NSRange(location: NSNotFound, length: NSNotFound)
        textClient.setMarkedText(
            value,
            selectionRange: NSRange(
                location: selectionOffset ?? value.utf16.count,
                length: 0
            ),
            replacementRange: replacementRange
        )
    }

    private func insertIntoInputBuffer(_ text: String) {
        var editor = InputBufferEditor(
            value: inputBuffer,
            cursor: inputCursor
        )
        editor.insert(text)
        inputBuffer = editor.value
        inputCursor = editor.cursor
    }

    private func moveInputCursor(by offset: Int, client sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else { return false }
        var editor = InputBufferEditor(
            value: inputBuffer,
            cursor: inputCursor
        )
        guard editor.move(by: offset) else { return true }
        inputCursor = editor.cursor
        if !compositionPrefix.isEmpty {
            setMarkedText(
                compositionPrefix + inputBuffer,
                in: sender,
                selectionOffset: compositionPrefix.utf16.count + inputCursor
            )
        } else {
            updateMarkedText(in: sender)
        }
        return true
    }

    private func showInputPreview(client sender: Any) {
        guard let pageTitle = PreviewPageTitleResolver.pageTitle(
            input: conversionReading,
            selectedCandidate: nil
        ) else {
            previewWindow.hide()
            return
        }
        let inputFrame = inputLocation(for: sender)
        let anchorFrame = currentCandidates.isEmpty
            ? inputFrame
            : inputFrame.union(candidateWindow.frame)
        showPreview(
            for: pageTitle,
            beside: anchorFrame,
            includeDefinitions: true
        )
    }

    private func showPreview(for candidate: String) {
        var anchorFrame = candidateWindow.frame
        if let inputClient = client() {
            anchorFrame = anchorFrame.union(
                inputLocation(for: inputClient)
            )
        }
        showPreview(
            for: candidate,
            beside: anchorFrame,
            includeDefinitions: true
        )
    }

    private func showPreview(
        for candidate: String,
        beside anchorFrame: NSRect,
        includeDefinitions: Bool
    ) {
        guard isExternalInformationPanelEnabled
            || isSystemDictionaryPreviewEnabled
        else {
            previewWindow.hide()
            return
        }
        let url = isExternalInformationPanelEnabled
            ? try? SearchURLTemplate(externalInformationURLTemplate)
                .url(for: candidate)
            : nil

        previewWindow.show(
            url: url,
            panelTitle: url?.host ?? "外部情報",
            definitions: includeDefinitions && isSystemDictionaryPreviewEnabled
                ? definitionProvider.definitions(for: candidate)
                : [],
            showExternalInformation: isExternalInformationPanelEnabled,
            displayDelay: externalInformationDisplayDelay,
            beside: anchorFrame
        )
    }

    private func rebuildConversionEngine(
        basicDictionaryChanged: Bool = false
    ) {
        userConversionEngine = ConversionEngine(entries: userEntries)
        extensionConversionEngine = ConversionEngine(
            entries: extensionEntries
        )
        if basicDictionaryChanged {
            basicConversionEngine = ConversionEngine(entries: basicEntries)
            verbInflectionGenerator = VerbInflectionCandidateGenerator(
                entries: basicEntries
            )
        }
        rebuildFuzzyConversionEngine()
    }

    private func rebuildFuzzyConversionEngine() {
        cancelFuzzySuggestionSearch()
        fuzzyEngineBuildTask?.cancel()
        let userEntries = userEntries
        let extensionEntries = isExtensionDictionaryEnabled
            ? extensionEntries
            : []
        let basicEntries = basicEntries
        fuzzyEngineBuildTask = Task { @MainActor [weak self] in
            await Task.detached(priority: .utility) {
                let entries = userEntries
                    + extensionEntries
                    + basicEntries
                    + VerbInflectionCandidateGenerator.typoSearchEntries(
                        from: basicEntries
                    )
                    + SupplementalDictionary.entries
                Self.fuzzyEngineRepository.prepare(for: entries)
            }.value
            guard !Task.isCancelled, let self else {
                return
            }
            fuzzyEngineBuildTask = nil
            guard !inputBuffer.isEmpty, let inputClient = client() else {
                return
            }
            refreshCandidates(client: inputClient)
        }
    }

    private var conversionReading: String {
        String(
            inputBuffer.prefix {
                $0.isASCII
                    && ($0.isLetter || $0 == "-" || $0 == "'")
            }
        )
    }

    private var interactionState: InputInteractionState {
        InputInteractionState.resolve(
            hasInput: !inputBuffer.isEmpty,
            isRegisteringDictionary: tabDictionaryRegistration != nil,
            hasSelectedCandidate: selectedCandidateIndex != nil,
            hasSelectedFuzzySuggestion: selectedFuzzySuggestionIndex != nil,
            hasSelectedNextInput: selectedNextInputIndex != nil
        )
    }

    private var conversionSuffix: String {
        if !CalculatorCandidateGenerator.candidates(for: inputBuffer).isEmpty
            || !JapaneseNumberConverter.candidates(for: inputBuffer).isEmpty
            || !JapaneseSymbolConverter.candidates(for: inputBuffer).isEmpty {
            return ""
        }
        return String(inputBuffer.dropFirst(conversionReading.count))
    }

    private var selectedCandidateValue: String? {
        selectedCandidateIndex
            .flatMap {
                currentCandidates.indices.contains($0)
                    ? currentCandidates[$0]
                    : nil
            }
            .map {
                candidateValueForCommit($0) + conversionSuffix
            }
    }

    private var cosenseAuthenticationStatus: String {
        switch cosenseCredential?.kind {
        case .personalAccessToken:
            return "Personal Access Token"
        case .serviceAccount:
            return "Service Account"
        case nil:
            return "なし"
        }
    }

    private var isNextInputPredictionEnabled: Bool {
        if UserDefaults.standard.object(
            forKey: Self.nextInputEnabledDefaultsKey
        ) == nil {
            return true
        }
        return UserDefaults.standard.bool(
            forKey: Self.nextInputEnabledDefaultsKey
        )
    }

    private var isExternalInformationPanelEnabled: Bool {
        let defaults = UserDefaults.standard
        if defaults.object(
            forKey: Self.externalInformationPanelEnabledDefaultsKey
        ) != nil {
            return defaults.bool(
                forKey: Self.externalInformationPanelEnabledDefaultsKey
            )
        }
        if defaults.object(
            forKey: Self.legacyCosensePreviewEnabledDefaultsKey
        ) != nil {
            return defaults.bool(
                forKey: Self.legacyCosensePreviewEnabledDefaultsKey
            )
        }
        return true
    }

    private var externalInformationURLTemplate: String {
        UserDefaults.standard.string(
            forKey: Self.externalInformationURLTemplateDefaultsKey
        ) ?? defaultExternalInformationURLTemplate
    }

    private var externalInformationDisplayDelay: TimeInterval {
        let defaults = UserDefaults.standard
        guard defaults.object(
            forKey: Self.externalInformationDisplayDelayDefaultsKey
        ) != nil else {
            return 1
        }
        return max(
            0,
            defaults.double(
                forKey: Self.externalInformationDisplayDelayDefaultsKey
            )
        )
    }

    private var defaultExternalInformationURLTemplate: String {
        var allowed = CharacterSet.urlPathAllowed
        allowed.remove(charactersIn: "/")
        let project = dictionarySource.project.addingPercentEncoding(
            withAllowedCharacters: allowed
        ) ?? dictionarySource.project
        return "https://scrapbox.io/\(project)/%s"
    }

    private var isExtensionDictionaryEnabled: Bool {
        experimentalFeatureIsEnabled(
            defaultsKey: Self.extensionDictionaryEnabledDefaultsKey
        )
    }

    private var isEnglishCompletionEnabled: Bool {
        experimentalFeatureIsEnabled(
            defaultsKey: Self.englishCompletionEnabledDefaultsKey
        )
    }

    private var isWikipediaSuggestionsEnabled: Bool {
        if UserDefaults.standard.object(
            forKey: Self.wikipediaSuggestionsEnabledDefaultsKey
        ) == nil {
            return false
        }
        return UserDefaults.standard.bool(
            forKey: Self.wikipediaSuggestionsEnabledDefaultsKey
        )
    }

    private var isAppleTranslationEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.appleTranslationEnabledDefaultsKey) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: Self.appleTranslationEnabledDefaultsKey)
    }

    private var isTranslationModeEnabled: Bool {
#if canImport(Translation)
        if #available(macOS 15.0, *) {
            return UserDefaults.standard.bool(
                forKey: Self.translationModeEnabledDefaultsKey
            )
        }
#endif
        return false
    }

    private var isWebSearchEnabled: Bool {
        if UserDefaults.standard.object(forKey: Self.webSearchEnabledDefaultsKey) == nil {
            return false
        }
        return UserDefaults.standard.bool(forKey: Self.webSearchEnabledDefaultsKey)
    }

    private var webSearchTemplate: String {
        UserDefaults.standard.string(forKey: Self.webSearchTemplateDefaultsKey)
            ?? SearchURLTemplate.defaultValue
    }

    private var isSystemDictionaryPreviewEnabled: Bool {
        experimentalFeatureIsEnabled(
            defaultsKey: Self.systemDictionaryPreviewEnabledDefaultsKey
        )
    }

    private var isFuzzySuggestionsEnabled: Bool {
        UserDefaults.standard.bool(
            forKey: Self.fuzzySuggestionsEnabledDefaultsKey
        )
    }

    private var isDateTimeCandidatesEnabled: Bool {
        UserDefaults.standard.bool(
            forKey: Self.dateTimeCandidatesEnabledDefaultsKey
        )
    }

    private var dateCandidateFormats: [String] {
        candidateFormats(
            defaultsKey: Self.dateCandidateFormatsDefaultsKey,
            fallback: DateTimeCandidateGenerator.Formats.default.date
        )
    }

    private var timeCandidateFormats: [String] {
        candidateFormats(
            defaultsKey: Self.timeCandidateFormatsDefaultsKey,
            fallback: DateTimeCandidateGenerator.Formats.default.time
        )
    }

    private var dateTimeCandidateFormats: [String] {
        candidateFormats(
            defaultsKey: Self.dateTimeCandidateFormatsDefaultsKey,
            fallback: DateTimeCandidateGenerator.Formats.default.dateTime
        )
    }

    private func candidateFormats(
        defaultsKey: String,
        fallback: [String]
    ) -> [String] {
        guard UserDefaults.standard.object(forKey: defaultsKey) != nil else {
            return fallback
        }
        return UserDefaults.standard.stringArray(forKey: defaultsKey) ?? []
    }

    private func experimentalFeatureIsEnabled(defaultsKey: String) -> Bool {
        if UserDefaults.standard.object(forKey: defaultsKey) == nil {
            return true
        }
        return UserDefaults.standard.bool(forKey: defaultsKey)
    }

    private func candidateValueForCommit(_ candidate: String) -> String {
        CandidateCommitNormalizer.value(from: candidate)
    }

    private static func loadDictionarySource() -> CosenseDictionarySource {
        guard
            let project = UserDefaults.standard.string(
                forKey: projectDefaultsKey
            ),
            !project.isEmpty
        else {
            return defaultDictionarySource
        }

        return CosenseDictionarySource(
            project: project,
            pageTitle: "dictionary"
        )
    }

    private static func loadBasicEntries() -> [DictionaryEntry] {
        if let cache = try? basicDictionaryCache(),
           let entries = loadEntries(from: cache) {
            return entries
        }

        guard
            let dictionaryURL = inputMethodResourceURL(
                forResource: "basic-dictionary",
                withExtension: "txt"
            ),
            let dictionaryText = try? String(
                contentsOf: dictionaryURL,
                encoding: .utf8
            ),
            let entries = try? DictionaryParser().parse(dictionaryText)
        else {
            return []
        }

        return entries
    }

    private static func loadIMEDictionaryEngine() -> IndexedDictionaryEngine {
        guard
            let dictionaryURL = inputMethodResourceURL(
                forResource: "ime-dictionary",
                withExtension: "txt"
            ),
            let engine = try? IndexedDictionaryEngine(contentsOf: dictionaryURL)
        else {
            return IndexedDictionaryEngine()
        }
        return engine
    }

    private static func loadUserEntries() -> [DictionaryEntry] {
        guard let cache = try? userDictionaryCache() else {
            return []
        }
        return loadEntries(from: cache) ?? []
    }

    private static func bundledBasicDictionaryRevision() -> String? {
        guard
            let metadataURL = inputMethodResourceURL(
                forResource: "basic-dictionary-source",
                withExtension: "json"
            ),
            let data = try? Data(contentsOf: metadataURL),
            let metadata = try? JSONDecoder().decode(
                BundledBasicDictionaryMetadata.self,
                from: data
            )
        else {
            return nil
        }

        return metadata.generated
    }

    private static func inputMethodResourceURL(
        forResource name: String,
        withExtension fileExtension: String
    ) -> URL? {
        let bundleIdentifier = "io.github.sendarionn.inputmethod.myime"
        var bundles: [Bundle] = []
        if let identifierBundle = Bundle(identifier: bundleIdentifier) {
            bundles.append(identifierBundle)
        }
        bundles.append(Bundle(for: InputController.self))

        let executableURL = URL(
            fileURLWithPath: CommandLine.arguments.first ?? ""
        )
        let executableBundleURL = executableURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        if let executableBundle = Bundle(url: executableBundleURL) {
            bundles.append(executableBundle)
        }

        let installedBundleURLs = [
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Library/Input Methods/myim.app",
                    isDirectory: true
                ),
            URL(
                fileURLWithPath: "/Library/Input Methods/myim.app",
                isDirectory: true
            )
        ]
        bundles.append(
            contentsOf: installedBundleURLs.compactMap(Bundle.init(url:))
        )

        for bundle in bundles {
            if let url = bundle.url(
                forResource: name,
                withExtension: fileExtension
            ) {
                return url
            }
        }

        NSLog("myimのリソースが見つかりません: %@.%@", name, fileExtension)
        return nil
    }

    private static func loadExtensionEntries(
        for source: CosenseDictionarySource
    ) -> [DictionaryEntry] {
        if let cache = try? extensionCache(for: source),
           let entries = loadEntries(from: cache) {
            return entries
        }

        if let legacyCache = try? legacyExtensionCache(for: source),
           let entries = loadEntries(from: legacyCache) {
            return entries
        }

        if source == defaultDictionarySource,
           let legacyCache = try? DictionaryCache.applicationSupport(
                applicationName: "my-ime"
           ),
           let entries = loadEntries(from: legacyCache) {
            return entries
        }

        return []
    }

    private static func loadEntries(
        from cache: DictionaryCache
    ) -> [DictionaryEntry]? {
        guard
            cache.containsDictionary(),
            let dictionaryText = try? String(
                contentsOf: cache.dictionaryURL,
                encoding: .utf8
            )
        else {
            return nil
        }

        return try? DictionaryParser().parse(dictionaryText)
    }

    private static func extensionCache(
        for source: CosenseDictionarySource
    ) throws -> DictionaryCache {
        let applicationCache = try DictionaryCache.applicationSupport()
        return DictionaryCache(
            directoryURL: applicationCache.directoryURL
                .appendingPathComponent("extensions", isDirectory: true)
                .appendingPathComponent(source.project, isDirectory: true)
        )
    }

    private static func basicDictionaryCache() throws -> DictionaryCache {
        let applicationCache = try DictionaryCache.applicationSupport()
        return DictionaryCache(
            directoryURL: applicationCache.directoryURL
                .appendingPathComponent("basic", isDirectory: true)
        )
    }

    private static func userDictionaryCache() throws -> DictionaryCache {
        let applicationCache = try DictionaryCache.applicationSupport()
        return DictionaryCache(
            directoryURL: applicationCache.directoryURL
                .appendingPathComponent("user", isDirectory: true)
        )
    }

    private static func loadCandidateSelectionHistory()
        -> CandidateSelectionHistory {
        guard
            let data = try? Data(contentsOf: candidateSelectionHistoryURL()),
            let ranks = try? JSONDecoder().decode(
                [String: Int].self,
                from: data
            )
        else {
            return CandidateSelectionHistory()
        }
        return CandidateSelectionHistory(ranks: ranks)
    }

    private static func candidateSelectionHistoryURL() -> URL {
        userDataURL(fileName: "candidate-selection-history.json")
    }

    private static func loadNextInputPredictionModel()
        -> NextInputPredictionModel {
        guard
            let data = try? Data(contentsOf: nextInputPredictionModelURL()),
            var model = try? JSONDecoder().decode(
                NextInputPredictionModel.self,
                from: data
            )
        else {
            return NextInputPredictionModel()
        }
        model.breakSequence()
        return model
    }

    private static func nextInputPredictionModelURL() -> URL {
        userDataURL(fileName: "next-input-model.json")
    }

    private static func userDataURL(fileName: String) -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/myim/user",
                isDirectory: true
            )
            .appendingPathComponent(fileName)
    }

    private static func legacyExtensionCache(
        for source: CosenseDictionarySource
    ) throws -> DictionaryCache {
        let applicationCache = try DictionaryCache.applicationSupport(
            applicationName: "my-ime"
        )
        return DictionaryCache(
            directoryURL: applicationCache.directoryURL
                .appendingPathComponent("extensions", isDirectory: true)
                .appendingPathComponent(source.project, isDirectory: true)
        )
    }
}

private struct BundledBasicDictionaryMetadata: Decodable {
    let generated: String
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private extension CosenseDictionarySource {
    var projectURLDescription: String {
        "https://scrapbox.io/\(project)"
    }
}
