@preconcurrency import AppKit
@preconcurrency import InputMethodKit
import MyIMECore

@objc(MyIMEInputController)
final class InputController: IMKInputController {
    private struct NeuralContextQuery: Equatable {
        let input: String
        let reading: String
        let context: String
    }

    private struct TabDictionaryRegistration {
        let originalInput: String
        let reading: String
        var pastedCandidate: String?
        var confirmedCandidate: String?
        var outputCandidate: String?

        var isEnteringDisplayName: Bool {
            outputCandidate != nil
        }
    }

    private struct CandidateFilterDraft {
        var input = ""
        var stage: CandidateFilterDraftStage = .conversion
        var choices: [CandidateFilterDraftChoice] = []
        var selectedIndex: Int?
    }

    private enum CandidateFilterDraftStage {
        case conversion
        case filter
    }

    private enum CandidateFilterDraftChoice {
        case input(String)
        case filter(CandidateFilterChoice)

        var label: String {
            switch self {
            case let .input(value): value
            case let .filter(choice): choice.label
            }
        }
    }

    private static let nextInputEnabledDefaultsKey = "NextInputPredictionEnabled"
    private static let englishCompletionEnabledDefaultsKey =
        "EnglishCompletionEnabled"
    private static let wikipediaSuggestionsEnabledDefaultsKey =
        "WikipediaSuggestionsEnabled"
    private static let googleJapaneseInputEnabledDefaultsKey =
        "GoogleJapaneseInputEnabled"
    private static let appleTranslationEnabledDefaultsKey =
        "AppleTranslationEnabled"
    private static let translationModeEnabledDefaultsKey =
        "TranslationModeEnabled"
    private static let webSearchEnabledDefaultsKey = "WebSearchEnabled"
    private static let webSearchTemplateDefaultsKey = "WebSearchTemplate"
    private static let externalInformationPanelEnabledDefaultsKey =
        "ExternalInformationPanelEnabled"
    private static let systemDictionaryPreviewEnabledDefaultsKey =
        "SystemDictionaryPreviewEnabled"
    private static let systemDictionaryNamesDefaultsKey =
        "SystemDictionaryNames"
    private static let fuzzySuggestionsEnabledDefaultsKey =
        "FuzzySuggestionsEnabled"
    private static let dateTimeCandidatesEnabledDefaultsKey =
        "DateTimeCandidatesEnabled"
    private static let neuralContextEnabledDefaultsKey =
        "NeuralContextEnabled"
    private static let dateCandidateFormatsDefaultsKey =
        "DateCandidateFormats"
    private static let timeCandidateFormatsDefaultsKey =
        "TimeCandidateFormats"
    private static let dateTimeCandidateFormatsDefaultsKey =
        "DateTimeCandidateFormats"
    private static let maximumCandidateCount = 7
    private static let initialFuzzySuggestionCount = 3
    private static let maximumMozcDictionaryPrefixCandidates = 2048
    private static let nextInputDismissInterval: TimeInterval = 5
    private static let sharedBasicEntries = loadBasicEntries()
    private static let sharedBasicConversionEngine = ConversionEngine(
        entries: sharedBasicEntries
    )
    private static let sharedMozcConversionEngine = loadMozcDictionaryEngine()
    private static let sharedVerbInflectionGenerator =
        VerbInflectionCandidateGenerator(entries: sharedBasicEntries)
    private static let fuzzyEngineRepository = FuzzyEngineRepository()
    private static let basicDictionaryUpdateCoordinator =
        BasicDictionaryUpdateCoordinator()
    private static let javaScriptExtensionClient = JavaScriptExtensionClient()
    private static let candidateFilterDatabase = loadCandidateFilterDatabase()
    private static let candidateFilterChoiceGenerator =
        CandidateFilterChoiceGenerator(
            aliasDictionaryText: loadBundledText(
                resource: "candidate-filter-aliases"
            ) ?? ""
        )

    private var inputBuffer = ""
    private var inputCursor = 0
    private var reconversionOriginal: String?
    private var translationDraft: String?
    private var translationDraftCursor = 0
    private var translationTask: Task<Void, Never>?
    private var neuralContextTask: Task<Void, Never>?
    private let neuralContextProvider = NeuralContextCandidateProvider()
    private var neuralContextQuery: NeuralContextQuery?
    private var cachedNeuralContextQuery: NeuralContextQuery?
    private var cachedNeuralCandidates: [String] = []
    private var recentCommittedContext = ""
    private var activatedAt: TimeInterval?
    private var secureInputPassthroughActive = false
    private var currentCandidates: [String] = []
    private var selectedCandidateIndex: Int?
    private var unfilteredCandidates: [String]?
    private var candidateFilterConditions: [CandidateFilterCondition] = []
    private var candidateFilterDraft: CandidateFilterDraft?
    private var calendarFormatCandidates: [String]?
    private var selectedCalendarFormatIndex: Int?
    private var calendarFormatTask: Task<Void, Never>?
    private var calendarSessionActive = false
    private var calendarAnchorFrame: NSRect?
    private var calendarReturnApplication: NSRunningApplication?
    private var fuzzySuggestions: [FuzzySuggestion] = []
    private var selectedFuzzySuggestionIndex: Int?
    private var userEntries: [DictionaryEntry]
    private var basicEntries: [DictionaryEntry]
    private var userConversionEngine: ConversionEngine
    private var basicConversionEngine: ConversionEngine
    private let mozcConversionEngine: IndexedDictionaryEngine
    private var verbInflectionGenerator: VerbInflectionCandidateGenerator
    private var compoundDictionaryCandidateGenerator:
        CompoundDictionaryCandidateGenerator
    private var fuzzyEngineBuildTask: Task<Void, Never>?
    private let settingsDialogController = SettingsDialogController()
    private let shortcutSettingsController = ShortcutSettingsController()
    private let translationLanguageSettingsController =
        TranslationLanguageSettingsController()
    private lazy var javaScriptExtensionSettingsController =
        JavaScriptExtensionSettingsController(
            client: Self.javaScriptExtensionClient
        )
    private var candidateSelectionHistory: CandidateSelectionHistory
    private let candidateSelectionHistoryWriter:
        DeferredJSONFileWriter<CandidateSelectionHistory>
    private var nextInputPredictionModel: NextInputPredictionModel
    private let nextInputPredictionWriter:
        DeferredJSONFileWriter<NextInputPredictionModel>
    private var nextInputCandidates: [String] = []
    private var selectedNextInputIndex: Int?
    private var nextInputDismissTimer: Timer?
    private let suggestionSearchSession = SuggestionSearchSession()
    private var officialCandidates: [String] = []
    private var javaScriptExtensionCandidates: [String] = []
    private var postalAddressCandidates: [String] = []
    private var postalAddressCache: [String: [String]] = [:]
    private var tabDictionaryRegistration: TabDictionaryRegistration?
    private var basicDictionaryStatus = "未確認"
    private let candidateWindow = CandidateWindowController()
    private let calendarWindow = CalendarWindowController()
    private let modeStatusWindow = ModeStatusWindowController()
    private let fuzzySuggestionWindow = FuzzySuggestionWindowController()
    private let previewWindow = ExternalInformationWindowController()
    private let definitionProvider = SystemDictionaryDefinitionProvider()
    private var dictionaryDefinitionTask: Task<Void, Never>?
    private let romajiConverter = RomajiConverter()
    private var settingsWindow: NSWindow?

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let cachedUserEntries = Self.loadUserEntries()
        let bundledEntries = Self.sharedBasicEntries
        let indexedMozcEngine = Self.sharedMozcConversionEngine
        let selectionHistory = Self.loadCandidateSelectionHistory()
        let nextInputModel = Self.loadNextInputPredictionModel()

        userEntries = cachedUserEntries
        basicEntries = bundledEntries
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
        basicConversionEngine = Self.sharedBasicConversionEngine
        mozcConversionEngine = indexedMozcEngine
        verbInflectionGenerator = Self.sharedVerbInflectionGenerator
        compoundDictionaryCandidateGenerator =
            CompoundDictionaryCandidateGenerator(
                layers: [cachedUserEntries, bundledEntries]
            )
        JavaScriptExtensionClient.prepareUserExtensionDirectory()
        super.init(server: server, delegate: delegate, client: inputClient)

        basicDictionaryStatus = bundledEntries.isEmpty
            ? "読込失敗"
            : "読込済み（TKGJE \(bundledEntries.count)＋Mozc \(indexedMozcEngine.readingCount)input）"
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

        if SecureInputDetector.isEnabled {
            beginSecureInputPassthroughIfNeeded(client: sender)
            return false
        }
        secureInputPassthroughActive = false

        if FunctionKeyEventPolicy.shouldIgnore(keyCode: event.keyCode) {
            return true
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

        if calendarWindow.isVisible {
            if event.keyCode == 53 {
                calendarWindow.hide()
            }
            return true
        }

        if calendarFormatCandidates != nil {
            return handleCalendarFormatSelection(event, client: sender)
        }

        if isCalendarShortcut(event) {
            let anchorFrame = inputLocation(for: sender)
            let returnApplication = NSWorkspace.shared.frontmostApplication
            DispatchQueue.main.async { [weak self] in
                _ = self?.beginCalendarSelection(
                    client: sender,
                    anchorFrame: anchorFrame,
                    returnApplication: returnApplication
                )
            }
            return true
        }


        if candidateFilterDraft != nil {
            return handleCandidateFilterInput(event, client: sender)
        }

        if isCandidateFilterShortcut(event) {
            return beginCandidateFilterInput(client: sender)
        }

        if shouldBeginAdditionalCandidateFilter(with: event) {
            guard beginCandidateFilterInput(client: sender) else {
                return false
            }
            return handleCandidateFilterInput(event, client: sender)
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
            return true
        }

        if isUserDictionaryDeletionShortcut(event),
           !inputBuffer.isEmpty {
            if interactionState == .selectingFuzzySuggestion {
                removeSelectedFuzzySuggestionFromUserDictionary(
                    client: sender
                )
            } else {
                removeSelectedUserDictionaryCandidate(client: sender)
            }
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
           !inputBuffer.isEmpty {
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
            if isTranslationModeEnabled,
               translationDraft != nil || !inputBuffer.isEmpty {
                return handleTranslationReturn(client: sender)
            }
            if inputBuffer.isEmpty, !nextInputCandidates.isEmpty {
                if let selectedNextInputIndex,
                   nextInputCandidates.indices.contains(selectedNextInputIndex) {
                    commit(nextInputCandidates[selectedNextInputIndex], to: sender)
                    return true
                }
                dismissNextInputSuggestions(clearMarkedTextIn: sender)
                return true
            }
            if inputBuffer.isEmpty {
                nextInputPredictionModel.breakSequence()
                recentCommittedContext = String(
                    (recentCommittedContext + "\n").suffix(256)
                )
                return false
            }
            if unfilteredCandidates != nil, currentCandidates.isEmpty {
                return true
            }
            return commitFirstCandidateOrInput(to: sender)
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
            if unfilteredCandidates != nil {
                removeLastCandidateFilter(client: sender)
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
        if let aSelector,
           inputBuffer.isEmpty,
           nextInputCandidates.isEmpty,
           ["insertNewline:", "insertNewlineIgnoringFieldEditor:"]
            .contains(NSStringFromSelector(aSelector)) {
            nextInputPredictionModel.breakSequence()
        }
        if let aSelector,
           candidateFilterDraft != nil || unfilteredCandidates != nil,
           let inputClient = client() {
            switch NSStringFromSelector(aSelector) {
            case "cancelOperation:":
                if candidateFilterDraft != nil {
                    handleCandidateFilterEscape(client: inputClient)
                } else {
                    removeLastCandidateFilter(client: inputClient)
                }
                return
            case "deleteBackward:":
                if candidateFilterDraft?.stage == .filter {
                    return
                }
            case "insertNewline:", "insertNewlineIgnoringFieldEditor:":
                if unfilteredCandidates != nil, currentCandidates.isEmpty {
                    return
                }
            default:
                break
            }
        }
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
                openJavaScriptExtensionDirectory: #selector(
                    openJavaScriptExtensionDirectory(_:)
                ),
                manageJavaScriptExtensions: #selector(
                    manageJavaScriptExtensions(_:)
                ),
                toggleTranslationMode: #selector(toggleTranslationMode(_:)),
                translationModeEnabled: isTranslationModeEnabled,
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
            englishCompletion: isEnglishCompletionEnabled,
            wikipediaSuggestions: isWikipediaSuggestionsEnabled,
            googleJapaneseInput: isGoogleJapaneseInputEnabled,
            appleTranslation: isAppleTranslationEnabled,
            nextInputPrediction: isNextInputPredictionEnabled,
            neuralContext: isNeuralContextEnabled,
            fuzzySuggestions: isFuzzySuggestionsEnabled,
            dateTimeCandidates: isDateTimeCandidatesEnabled,
            externalInformationPanel: isExternalInformationPanelEnabled,
            systemDictionaryPreview: isSystemDictionaryPreviewEnabled,
            webSearch: isWebSearchEnabled
        )
    }

    private var settingsActions: SettingsWindowBuilder.Actions {
        SettingsWindowBuilder.Actions(
            toggleEnglishCompletion: #selector(toggleEnglishCompletion(_:)),
            toggleWikipediaSuggestions: #selector(toggleWikipediaSuggestions(_:)),
            toggleGoogleJapaneseInput: #selector(toggleGoogleJapaneseInput(_:)),
            toggleAppleTranslation: #selector(toggleAppleTranslation(_:)),
            toggleNextInputPrediction: #selector(toggleNextInputPrediction(_:)),
            toggleNeuralContext: #selector(toggleNeuralContext(_:)),
            toggleFuzzySuggestions: #selector(toggleFuzzySuggestions(_:)),
            toggleDateTimeCandidates: #selector(toggleDateTimeCandidates(_:)),
            clearNextInputHistory: #selector(clearNextInputPredictionHistory(_:)),
            toggleExternalInformationPanel: #selector(toggleExternalInformationPanel(_:)),
            toggleSystemDictionaryPreview: #selector(toggleSystemDictionaryPreview(_:)),
            configureSystemDictionaries: #selector(configureSystemDictionaries(_:)),
            toggleWebSearch: #selector(toggleWebSearch(_:)),
            configureShortcuts: #selector(configureShortcuts(_:)),
            configureTranslationLanguage: #selector(configureTranslationLanguage(_:)),
            updateBasicDictionary: #selector(updateBasicDictionaryIfNeeded(_:))
        )
    }

    @objc
    private func configureShortcuts(_ sender: Any?) {
        shortcutSettingsController.show()
    }

    @objc
    private func configureTranslationLanguage(_ sender: Any?) {
        translationLanguageSettingsController.show()
    }

    @objc
    private func openJavaScriptExtensionDirectory(_ sender: Any?) {
        guard let directory = JavaScriptExtensionClient
            .prepareUserExtensionDirectory()
        else {
            showJavaScriptExtensionDirectoryError(
                title: "拡張フォルダを開けません",
                message: "Application Supportフォルダが見つかりません"
            )
            return
        }
        do {
            try FileManager.default.createDirectory(
                at: directory,
                withIntermediateDirectories: true
            )
            JavaScriptExtensionDirectoryPresenter.open(directory)
        } catch {
            showJavaScriptExtensionDirectoryError(
                title: "拡張フォルダを開けません",
                message: error.localizedDescription
            )
        }
    }

    @objc
    private func manageJavaScriptExtensions(_ sender: Any?) {
        javaScriptExtensionSettingsController.show()
    }

    private func showJavaScriptExtensionDirectoryError(
        title: String,
        message: String
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "閉じる")
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        _ = alert.runModal()
    }

    @objc
    private func showStatus(_ sender: Any?) {
        let alert = NSAlert()
        alert.messageText = "myimの状態"
        alert.informativeText = [
            "ユーザー辞書: \(userEntries.count)読み",
            "TKGJE更新: \(basicDictionaryStatus)",
            "保護入力: \(secureInputStatusDescription)"
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

        selectedCandidateIndex = currentCandidates.firstIndex {
            candidateDisplayValue($0) == candidate
        }
        if let selectedCandidateIndex {
            showPreview(for: currentCandidates[selectedCandidateIndex])
        }
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let candidate = candidateString?.string else {
            return
        }

        let storedCandidate = currentCandidates.first {
            candidateDisplayValue($0) == candidate
        } ?? candidate
        recordCandidateSelection(storedCandidate)
        if isTranslationModeEnabled {
            selectedCandidateIndex = currentCandidates.firstIndex(
                of: storedCandidate
            )
            appendCurrentInputToTranslationDraft(
                suffix: "",
                client: client() as Any
            )
            return
        }
        commit(
            candidateValueForCommit(storedCandidate) + conversionSuffix,
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
        updateTranslationModeStatus(client: sender as Any)
    }

    override func deactivateServer(_ sender: Any!) {
        if previewWindow.shouldPreserveForExternalInteraction() {
            super.deactivateServer(sender)
            return
        }
        if calendarSessionActive {
            super.deactivateServer(sender)
            return
        }
        finishControllerSession(
            client: sender,
            commitsComposition: true,
            closesController: false
        )
        super.deactivateServer(sender)
    }

    override func inputControllerWillClose() {
        if previewWindow.shouldPreserveForExternalInteraction() {
            super.inputControllerWillClose()
            return
        }
        finishControllerSession(
            client: client(),
            commitsComposition: false,
            closesController: true
        )
        super.inputControllerWillClose()
    }

    private func finishControllerSession(
        client sender: Any!,
        commitsComposition: Bool,
        closesController: Bool
    ) {
        if commitsComposition, !inputBuffer.isEmpty {
            if reconversionOriginal != nil {
                restoreReconversionOriginal(client: sender as Any)
            } else if translationDraft != nil {
                finishTranslationDraftAsJapanese(client: sender as Any)
            } else {
                commit(inputBuffer, to: sender as Any)
            }
        } else if commitsComposition, translationDraft != nil {
            finishTranslationDraftAsJapanese(client: sender as Any)
        }
        resetTransientInteractionState()
        modeStatusWindow.hide()
        translationDraft = nil
        translationDraftCursor = 0
        nextInputPredictionModel.breakSequence()
        if closesController {
            fuzzyEngineBuildTask?.cancel()
            fuzzyEngineBuildTask = nil
        }
        flushPendingHistoryWrites()
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
    private func toggleNeuralContext(_ sender: Any?) {
        let enabled = !isNeuralContextEnabled
        if enabled, !neuralContextModelIsInstalled {
            offerNeuralContextModelDownload()
            return
        }
        UserDefaults.standard.set(
            enabled,
            forKey: Self.neuralContextEnabledDefaultsKey
        )
        if !enabled {
            resetNeuralContextRanking()
        }
        if !inputBuffer.isEmpty, let inputClient = client() {
            refreshCandidates(client: inputClient)
        }
    }

    private func offerNeuralContextModelDownload() {
        let alert = NSAlert()
        alert.messageText = "Zenzaiモデルをダウンロード"
        alert.informativeText = "ニューラル文脈変換に約74MBのモデルが必要です"
        alert.addButton(withTitle: "ダウンロード")
        alert.addButton(withTitle: "キャンセル")
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }
        Task { @MainActor [weak self] in
            do {
                try await self?.downloadNeuralContextModel()
                UserDefaults.standard.set(
                    true,
                    forKey: Self.neuralContextEnabledDefaultsKey
                )
                self?.settingsWindow?.close()
                self?.settingsWindow = nil
            } catch {
                let failure = NSAlert()
                failure.messageText = "Zenzaiモデルをダウンロードできません"
                failure.informativeText = error.localizedDescription
                failure.addButton(withTitle: "閉じる")
                failure.runModal()
            }
        }
    }

    private func downloadNeuralContextModel() async throws {
        guard let destination = NeuralContextCandidateProvider.modelURL() else {
            throw CocoaError(.fileNoSuchFile)
        }
        let directory = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )
        let (temporaryURL, response) = try await URLSession.shared.download(
            from: NeuralContextCandidateProvider.modelDownloadURL
        )
        guard let httpResponse = response as? HTTPURLResponse,
              (200..<300).contains(httpResponse.statusCode) else {
            throw URLError(.badServerResponse)
        }
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporaryURL, to: destination)
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
    private func toggleGoogleJapaneseInput(_ sender: Any?) {
        UserDefaults.standard.set(
            !isGoogleJapaneseInputEnabled,
            forKey: Self.googleJapaneseInputEnabledDefaultsKey
        )
        resetOfficialCandidates()
        guard !inputBuffer.isEmpty, let inputClient = client() else { return }
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
        if enabled, let inputClient = client() {
            updateTranslationModeStatus(client: inputClient)
        } else if let inputClient = client() {
            modeStatusWindow.show(
                enabled: false,
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
    private func toggleSystemDictionaryPreview(_ sender: Any?) {
        UserDefaults.standard.set(
            !isSystemDictionaryPreviewEnabled,
            forKey: Self.systemDictionaryPreviewEnabledDefaultsKey
        )
        refreshExperimentalPreview()
    }

    @objc
    private func configureSystemDictionaries(_ sender: Any?) {
        let availableNames = definitionProvider.availableDictionaryNames()
        guard !availableNames.isEmpty else {
            let alert = NSAlert()
            alert.messageText = "表示するmacOS辞書"
            alert.informativeText = "利用可能な辞書がありません"
            alert.addButton(withTitle: "閉じる")
            NSApp.activate(ignoringOtherApps: true)
            alert.runModal()
            return
        }
        let selectionController = SystemDictionarySelectionController()
        guard let names = selectionController.run(
            availableNames: availableNames,
            selectedNames: systemDictionaryNames,
            descriptions: definitionProvider.contentDescriptions()
        ) else { return }
        UserDefaults.standard.set(
            names,
            forKey: Self.systemDictionaryNamesDefaultsKey
        )
        dictionaryDefinitionTask?.cancel()
        definitionProvider.clearCache()
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
                        basicEntries = Self.addingBundledKeyboardSymbols(
                            to: snapshot.entries
                        )
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
                basicEntries = Self.addingBundledKeyboardSymbols(
                    to: snapshot.entries
                )
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
            insertIntoTranslationDraft(space)
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
        if inputBuffer.isEmpty,
           let selectedNextInputIndex,
           nextInputCandidates.indices.contains(selectedNextInputIndex) {
            let value = nextInputCandidates[selectedNextInputIndex]
            dismissNextInputSuggestions(clearMarkedTextIn: nil)
            insertIntoTranslationDraft(value)
            updateMarkedText(in: sender)
            showTranslationDraft(client: sender)
            recordTranslationSourceInput(value, client: sender)
            return true
        }
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
        insertIntoTranslationDraft(value + suffix)
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
        recordTranslationSourceInput(value, client: sender)
    }

    private func insertIntoTranslationDraft(_ value: String) {
        var editor = InputBufferEditor(
            value: translationDraft ?? "",
            cursor: translationDraftCursor
        )
        editor.insert(value)
        translationDraft = editor.value.nilIfEmpty
        translationDraftCursor = editor.cursor
    }

    private func showTranslationDraft(client sender: Any) {
        guard translationDraft != nil else { return }
        updateTranslationModeStatus(client: sender)
        updateMarkedText(in: sender)
        if nextInputCandidates.isEmpty && inputBuffer.isEmpty {
            candidateWindow.hide()
        }
    }

    private func translateDraft(client sender: Any) -> Bool {
        guard translationTask == nil,
              let source = translationDraft,
              !source.isEmpty else {
            return true
        }
        candidateWindow.show(
            candidates: ["翻訳中…"],
            selectedIndex: nil,
            near: inputLocation(for: sender),
            modeTitle: "\(TranslationTargetLanguage.current.name)へ翻訳",
            isAccented: true
        )
        translationTask = Task { @MainActor [weak self] in
            guard let self else { return }
#if canImport(Translation)
            if #available(macOS 15.0, *) {
                let provider = AppleTranslationCandidateProvider()
                let target = TranslationTargetLanguage.current
                let translated = await provider.translateJapanese(
                    source,
                    targetIdentifier: target.identifier
                )
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
                        self.translationDraftCursor = 0
                        self.translationTask = nil
                        self.commit(
                            value,
                            to: sender,
                            replacingMarkedText: true,
                            recordsInputHistory: false
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
        let value = compositionPrefix + currentInput + compositionSuffix
        guard !value.isEmpty else { return }
        translationDraft = nil
        translationDraftCursor = 0
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
        if flags == [.shift] {
            return true
        }
        if inputBuffer.isEmpty {
            if selectedNextInputIndex != nil,
               flags.isEmpty {
                return selectNextInputCandidate(offset: 1, client: sender)
            }
            if flags.isEmpty,
               beginReconversionIfPossible(client: sender) {
                return true
            }
            if flags.isEmpty, !nextInputCandidates.isEmpty {
                return selectNextInputCandidate(offset: 1, client: sender)
            }
            return false
        }

        guard flags.isEmpty else { return false }
        guard !currentCandidates.isEmpty else {
            return true
        }
        let nextIndex = (
            (selectedCandidateIndex ?? -1)
                + 1
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
        append(basicConversionEngine.readings(for: candidate))
        append(mozcConversionEngine.readings(for: candidate))
        return result
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
        let registration = TabDictionaryRegistration(
            originalInput: inputBuffer,
            reading: conversionReading.lowercased()
        )
        tabDictionaryRegistration = registration
        inputBuffer = ""
        inputCursor = 0
        currentCandidates = []
        selectedCandidateIndex = nil
        previewWindow.hide()
        setMarkedText("", in: sender)
        showTabDictionaryRegistration(client: sender)
        return true
    }

    private func isTabDictionaryRegistrationShortcut(_ event: NSEvent) -> Bool {
        MyIMFeatureShortcut.dictionaryRegistration.shortcut.matches(event)
    }

    private func handleTabDictionaryRegistration(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool {
        guard var registration = tabDictionaryRegistration else {
            return false
        }

        if isTabDictionaryRegistrationShortcut(event) {
            return beginDisplayNameRegistration(
                registration: &registration,
                client: sender
            )
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
                    let output = registration.outputCandidate
                        ?? confirmedCandidate
                    let display = registration.outputCandidate == nil
                        ? nil
                        : confirmedCandidate
                    try saveUserDictionaryEntry(
                        reading: registration.reading,
                        candidate: output,
                        display: display
                    )
                    tabDictionaryRegistration = nil
                    commit(
                        output,
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
            if registration.pastedCandidate == nil,
               selectedCandidateValue != nil {
                recordSelectedCandidate()
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
            if registration.pastedCandidate == nil,
               selectedCandidateValue != nil {
                recordSelectedCandidate()
            }
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
            recordSelectedCandidate()
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

    private func beginDisplayNameRegistration(
        registration: inout TabDictionaryRegistration,
        client sender: Any
    ) -> Bool {
        guard !registration.isEnteringDisplayName else {
            NSSound.beep()
            return true
        }
        let currentCandidate = registration.pastedCandidate
            ?? selectedCandidateValue
            ?? inputBuffer.nilIfEmpty
        let output = (registration.confirmedCandidate ?? "")
            + (currentCandidate ?? "")
        guard !output.isEmpty else {
            NSSound.beep()
            return true
        }
        registration.outputCandidate = output
        registration.confirmedCandidate = nil
        registration.pastedCandidate = nil
        tabDictionaryRegistration = registration
        inputBuffer = ""
        inputCursor = 0
        currentCandidates = []
        selectedCandidateIndex = nil
        setMarkedText("", in: sender)
        showTabDictionaryRegistration(client: sender)
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
                    registration.isEnteringDisplayName
                        ? "表示: \(confirmedCandidate)"
                        : "登録: \(confirmedCandidate)",
                    registration.outputCandidate.map { "出力: \($0)" }
                ].compactMap { $0 },
                selectedIndex: nil,
                near: inputLocation(for: sender),
                guide: registration.isEnteringDisplayName
                    ? "↩ 登録を確定　Esc 中止"
                    : "↩ 登録を確定　\(MyIMFeatureShortcut.dictionaryRegistration.shortcut.displayName) 表示名も登録\nEsc 中止",
                modeTitle: registration.isEnteringDisplayName
                    ? "候補パネルの表示名を入力"
                    : "登録したい文字列を入力"
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
                registration.outputCandidate.map { "出力: \($0)" },
                candidateDisplay
            ].compactMap { $0 },
            selectedIndex: nil,
            near: inputLocation(for: sender),
            guide: registration.isEnteringDisplayName
                ? "↩ 表示名を確定　⌘V 貼付　Esc 中止"
                : (candidate == nil
                    ? "↩ 入力を追加　⌘V 貼付　Esc 中止"
                    : "↩ 入力を追加　\(MyIMFeatureShortcut.dictionaryRegistration.shortcut.displayName) 表示名も登録\n⌘V 貼付　Esc 中止"),
            modeTitle: registration.isEnteringDisplayName
                ? "候補パネルの表示名を入力"
                : "登録したい文字列を入力"
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
            .confirmedCandidate ?? compositionPrefix
        setMarkedText(
            registrationPrefix
                + candidateDisplayValue(currentCandidates[index])
                + conversionSuffix
                + compositionSuffix,
            in: sender
        )
        showPreview(for: currentCandidates[index])
        return true
    }

    private func isCandidateFilterShortcut(_ event: NSEvent) -> Bool {
        MyIMFeatureShortcut.candidateFilter.shortcut.matches(event)
    }

    private func isCalendarShortcut(_ event: NSEvent) -> Bool {
        MyIMFeatureShortcut.calendar.shortcut.matches(event)
    }

    private func beginCalendarSelection(
        client sender: Any,
        anchorFrame: NSRect,
        returnApplication: NSRunningApplication?
    ) -> Bool {
        guard inputBuffer.isEmpty,
              translationDraft == nil,
              tabDictionaryRegistration == nil else {
            return true
        }
        dismissNextInputSuggestions(clearMarkedTextIn: sender)
        candidateWindow.hide()
        previewWindow.hide()
        calendarFormatTask?.cancel()
        calendarFormatCandidates = nil
        selectedCalendarFormatIndex = nil
        calendarSessionActive = true
        calendarAnchorFrame = anchorFrame == .zero ? nil : anchorFrame
        calendarReturnApplication = returnApplication
        guard let date = calendarWindow.runSelection(
            near: calendarAnchorFrame ?? anchorFrame,
            returnTo: calendarReturnApplication
        ) else {
            clearCalendarSelection()
            candidateWindow.hide()
            return true
        }
        loadCalendarFormats(for: date, client: sender)
        return true
    }

    private func loadCalendarFormats(for date: Date, client sender: Any) {
        calendarFormatTask?.cancel()
        calendarFormatCandidates = []
        selectedCalendarFormatIndex = nil
        candidateWindow.show(
            candidates: ["書式を読み込み中"],
            selectedIndex: nil,
            near: calendarInputLocation(for: sender),
            guide: "Esc 中止",
            modeTitle: "日付の書式を選択"
        )
        calendarFormatTask = Task { @MainActor [weak self] in
            let candidates = await Self.javaScriptExtensionClient
                .calendarCandidates(for: date)
            guard !Task.isCancelled else { return }
            guard let self else { return }
            self.calendarFormatCandidates = self.candidatesOrderedByRecency(
                candidates
            )
            self.selectedCalendarFormatIndex = nil
            self.showCalendarFormatCandidates(client: sender)
            guard let orderedCandidates = self.calendarFormatCandidates,
                  !orderedCandidates.isEmpty else {
                return
            }
            guard let selectedIndex = self.calendarWindow.runFormatSelection(
                candidateCount: orderedCandidates.count,
                near: self.calendarInputLocation(for: sender),
                returnTo: self.calendarReturnApplication,
                directionalSelection: { [weak self] index, direction in
                    self?.calendarFormatSelectionIndex(
                        from: index,
                        direction: direction,
                        candidateCount: orderedCandidates.count
                    )
                },
                selectionChanged: { [weak self] index in
                    guard let self else { return }
                    self.selectedCalendarFormatIndex = index
                    self.showCalendarFormatCandidates(client: sender)
                }
            ), orderedCandidates.indices.contains(selectedIndex) else {
                self.clearCalendarSelection()
                self.candidateWindow.hide()
                return
            }
            let value = orderedCandidates[selectedIndex]
            self.recordCandidateSelection(value)
            self.clearCalendarSelection()
            self.commit(value, to: sender)
        }
    }

    private func handleCalendarFormatSelection(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool {
        guard let candidates = calendarFormatCandidates else { return false }
        switch event.keyCode {
        case 48:
            guard !candidates.isEmpty else { return true }
            let offset = event.modifierFlags.contains(.shift) ? -1 : 1
            selectedCalendarFormatIndex = (
                (selectedCalendarFormatIndex ?? (offset > 0 ? -1 : 0))
                    + offset
                    + candidates.count
            ) % candidates.count
            showCalendarFormatCandidates(client: sender)
        case 123, 124, 125, 126:
            guard !candidates.isEmpty else { return true }
            let direction: CandidateNavigationDirection = switch event.keyCode {
            case 123: .left
            case 124: .right
            case 125: .down
            default: .up
            }
            selectedCalendarFormatIndex = calendarFormatSelectionIndex(
                from: selectedCalendarFormatIndex,
                direction: direction,
                candidateCount: candidates.count
            )
            showCalendarFormatCandidates(client: sender)
        case 36, 76:
            guard let index = selectedCalendarFormatIndex,
                  candidates.indices.contains(index) else {
                return true
            }
            let value = candidates[index]
            recordCandidateSelection(value)
            clearCalendarSelection()
            commit(value, to: sender)
        case 53:
            clearCalendarSelection()
            candidateWindow.hide()
        default:
            break
        }
        return true
    }

    private func calendarFormatSelectionIndex(
        from selectedIndex: Int?,
        direction: CandidateNavigationDirection,
        candidateCount: Int
    ) -> Int? {
        guard candidateCount > 0 else { return nil }
        guard let selectedIndex else { return 0 }
        let pageStart = selectedIndex
            / Self.maximumCandidateCount
            * Self.maximumCandidateCount
        let localIndex = selectedIndex - pageStart
        if let localNextIndex = candidateWindow.adjacentIndex(
            from: localIndex,
            direction: direction
        ) {
            return pageStart + localNextIndex
        }
        let offset: Int = switch direction {
        case .left: -1
        case .right: 1
        case .up: -Self.maximumCandidateCount
        case .down: Self.maximumCandidateCount
        }
        return (
            (selectedIndex + offset) % candidateCount + candidateCount
        ) % candidateCount
    }

    private func showCalendarFormatCandidates(client sender: Any) {
        guard let candidates = calendarFormatCandidates else { return }
        guard !candidates.isEmpty else {
            candidateWindow.show(
                candidates: ["書式候補なし"],
                selectedIndex: nil,
                near: calendarInputLocation(for: sender),
                guide: "calendar.jsを確認　Esc 中止",
                modeTitle: "日付の書式を選択"
            )
            return
        }
        let selectedIndex = selectedCalendarFormatIndex ?? 0
        let pageStart = selectedIndex / Self.maximumCandidateCount
            * Self.maximumCandidateCount
        let pageEnd = min(pageStart + Self.maximumCandidateCount, candidates.count)
        candidateWindow.show(
            candidates: Array(candidates[pageStart..<pageEnd]),
            selectedIndex: selectedCalendarFormatIndex.map { $0 - pageStart },
            near: calendarInputLocation(for: sender),
            guide: "Tab / 矢印 選択　↩ 入力　Esc 中止",
            modeTitle: "日付の書式を選択"
        )
    }

    private func clearCalendarSelection() {
        calendarFormatTask?.cancel()
        calendarFormatTask = nil
        calendarFormatCandidates = nil
        selectedCalendarFormatIndex = nil
        calendarSessionActive = false
        calendarAnchorFrame = nil
        calendarReturnApplication = nil
        calendarWindow.hide()
    }

    private func calendarInputLocation(for sender: Any) -> NSRect {
        calendarAnchorFrame ?? inputLocation(for: sender)
    }

    private func beginCandidateFilterInput(client sender: Any) -> Bool {
        guard !inputBuffer.isEmpty,
              unfilteredCandidates != nil || !currentCandidates.isEmpty else {
            return false
        }
        if unfilteredCandidates == nil {
            unfilteredCandidates = currentCandidates
        }
        suggestionSearchSession.cancelAll()
        fuzzySuggestionWindow.hide()
        previewWindow.hide()
        selectedCandidateIndex = nil
        candidateFilterDraft = CandidateFilterDraft()
        updateCandidateFilterChoices(client: sender)
        return true
    }

    private func shouldBeginAdditionalCandidateFilter(with event: NSEvent) -> Bool {
        guard unfilteredCandidates != nil,
              !candidateFilterConditions.isEmpty else {
            return false
        }
        let flags = event.modifierFlags.intersection([.command, .control, .option])
        guard flags.isEmpty,
              let characters = event.characters,
              !characters.isEmpty else {
            return false
        }
        return characters.unicodeScalars.allSatisfy {
            !CharacterSet.controlCharacters.contains($0)
        }
    }

    private func handleCandidateFilterInput(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool {
        guard var draft = candidateFilterDraft else { return false }
        switch event.keyCode {
        case 36, 76:
            candidateFilterDraft = draft
            return applySelectedCandidateFilter(client: sender)
        case 48, 124, 125:
            guard !draft.choices.isEmpty else { return true }
            draft.selectedIndex = ((draft.selectedIndex ?? -1) + 1)
                % draft.choices.count
            candidateFilterDraft = draft
            showCandidateFilterChoices(client: sender)
            return true
        case 123, 126:
            guard !draft.choices.isEmpty else { return true }
            draft.selectedIndex = (
                (draft.selectedIndex ?? 0) - 1 + draft.choices.count
            ) % draft.choices.count
            candidateFilterDraft = draft
            showCandidateFilterChoices(client: sender)
            return true
        case 51:
            if draft.stage == .conversion, !draft.input.isEmpty {
                draft.input.removeLast()
                draft.selectedIndex = nil
                candidateFilterDraft = draft
                updateCandidateFilterChoices(client: sender)
            }
            return true
        case 53:
            handleCandidateFilterEscape(client: sender)
            return true
        default:
            break
        }

        let flags = event.modifierFlags.intersection([.command, .control, .option])
        guard flags.isEmpty,
              let characters = event.characters,
              !characters.isEmpty else {
            return true
        }
        draft.stage = .conversion
        draft.input.append(contentsOf: characters)
        draft.selectedIndex = nil
        candidateFilterDraft = draft
        updateCandidateFilterChoices(client: sender)
        return true
    }

    private func handleCandidateFilterEscape(client sender: Any) {
        guard var draft = candidateFilterDraft else { return }
        if draft.stage == .filter {
            draft.stage = .conversion
            draft.selectedIndex = nil
            candidateFilterDraft = draft
            updateCandidateFilterChoices(client: sender)
        } else {
            removeLastCandidateFilter(client: sender)
        }
    }

    private func removeLastCandidateFilter(client sender: Any) {
        guard let originalCandidates = unfilteredCandidates else {
            candidateFilterDraft = nil
            return
        }
        candidateFilterDraft = nil
        if !candidateFilterConditions.isEmpty {
            candidateFilterConditions.removeLast()
        }
        guard candidateFilterConditions.isEmpty else {
            showFilteredCandidates(client: sender)
            return
        }
        currentCandidates = originalCandidates
        selectedCandidateIndex = nil
        resetCandidateFilters()
        updateMarkedText(in: sender)
        showCandidateWindow(client: sender)
    }

    private func updateCandidateFilterChoices(client sender: Any) {
        guard var draft = candidateFilterDraft else { return }
        var choices: [CandidateFilterDraftChoice] = []
        var seen = Set<String>()
        if draft.input.isEmpty {
            choices = []
        } else if draft.stage == .filter {
            for choice in Self.candidateFilterChoiceGenerator.choices(
                for: draft.input,
                activeConditions: candidateFilterConditions
            ) where seen.insert(choice.label).inserted {
                choices.append(.filter(choice))
            }
        } else {
            let queries = candidateFilterQueryVariants(for: draft.input)
            let conversionCandidates = queries.count > 1
                ? queries.dropFirst()
                : queries[...]
            for convertedInput in conversionCandidates
            where seen.insert(convertedInput).inserted {
                choices.append(.input(convertedInput))
            }
        }
        draft.choices = choices
        if let selectedIndex = draft.selectedIndex,
           !choices.indices.contains(selectedIndex) {
            draft.selectedIndex = nil
        }
        candidateFilterDraft = draft
        showCandidateFilterChoices(client: sender)
    }

    private func candidateFilterQueryVariants(for input: String) -> [String] {
        guard !input.isEmpty else { return [""] }
        var kanaCandidates: [String] = []
        if let hiragana = romajiConverter.hiragana(from: input) {
            kanaCandidates.append(hiragana)
        }
        if let katakana = romajiConverter.katakana(from: input) {
            kanaCandidates.append(katakana)
        }
        var directCandidates: [String] = []
        for reading in RomajiCanonicalizer.dictionaryLookupInputs(from: input) {
            directCandidates.append(contentsOf: userConversionEngine.candidates(for: reading))
            directCandidates.append(contentsOf: basicConversionEngine.candidates(for: reading))
            directCandidates.append(contentsOf: mozcConversionEngine.candidates(for: reading))
        }
        let orderedCandidates = CandidatePriorityOrderer.ordered(
            kana: kanaCandidates,
            direct: directCandidates,
            others: [],
            recencyRanks: candidateSelectionHistory.ranks(for: input),
            prioritizeKana: kanaCandidates.first?.count == 1
        )
        let values = [input] + orderedCandidates
        var seen = Set<String>()
        return values.filter { !$0.isEmpty && seen.insert($0).inserted }
    }

    private func showCandidateFilterChoices(client sender: Any) {
        guard let draft = candidateFilterDraft else { return }
        let chips = candidateFilterConditions.map {
            "[\($0.label)]"
        }.joined(separator: " ")
        let input = draft.input.isEmpty ? "条件を入力" : draft.input
        let stageTitle = draft.stage == .conversion ? "条件語を変換" : "条件を選択"
        let title = (["候補フィルター（\(stageTitle)）: \(input)", chips]
            .filter { !$0.isEmpty })
            .joined(separator: "　")
        let selectedIndex = draft.selectedIndex ?? 0
        let pageStart = selectedIndex / Self.maximumCandidateCount
            * Self.maximumCandidateCount
        let pageEnd = min(
            pageStart + Self.maximumCandidateCount,
            draft.choices.count
        )
        let visibleChoices = pageStart < pageEnd
            ? Array(draft.choices[pageStart..<pageEnd])
            : []
        candidateWindow.show(
            candidates: visibleChoices.map(\.label),
            selectedIndex: draft.selectedIndex.map { $0 - pageStart },
            near: inputLocation(for: sender),
            guide: draft.stage == .conversion
                ? "Tab / 矢印 選択　↩ 変換確定　Esc 戻る"
                : "Tab / 矢印 選択　↩ 適用　Esc 変換へ戻る",
            modeTitle: title
        )
    }

    private func applySelectedCandidateFilter(client sender: Any) -> Bool {
        guard let draft = candidateFilterDraft,
              let selectedIndex = draft.selectedIndex,
              draft.choices.indices.contains(selectedIndex) else {
            return true
        }
        let choice = draft.choices[selectedIndex]
        switch choice {
        case let .input(value):
            recordCandidateSelection(value)
            var updatedDraft = draft
            updatedDraft.input = value
            updatedDraft.stage = .filter
            updatedDraft.selectedIndex = nil
            candidateFilterDraft = updatedDraft
            updateCandidateFilterChoices(client: sender)
            return true
        case let .filter(.apply(condition)):
            if !candidateFilterConditions.contains(condition) {
                candidateFilterConditions.append(condition)
            }
        case let .filter(.remove(index, _)):
            if candidateFilterConditions.indices.contains(index) {
                candidateFilterConditions.remove(at: index)
            }
        }
        candidateFilterDraft = nil
        showFilteredCandidates(client: sender)
        return true
    }

    private func showFilteredCandidates(client sender: Any) {
        guard let unfilteredCandidates else { return }
        currentCandidates = CandidateFilter(
            kanjiDatabase: Self.candidateFilterDatabase
        ).filtered(
            unfilteredCandidates,
            conditions: candidateFilterConditions,
            semanticScorer: { query, candidate in
                CandidateSemanticScorer.score(
                    query: query,
                    candidate: candidate,
                    definitions: self.definitionProvider.definitions(
                        for: candidate,
                        dictionaryNames: self.systemDictionaryNames
                    ).map(\.text)
                )
            }
        )
        selectedCandidateIndex = nil
        updateMarkedText(in: sender)
        if currentCandidates.isEmpty {
            candidateWindow.show(
                candidates: ["一致する候補なし"],
                selectedIndex: nil,
                near: inputLocation(for: sender),
                guide: "一致なし: ↩ 無効　Esc 最後の条件を解除",
                modeTitle: candidateFilterConditions.map {
                    "[\($0.label)]"
                }.joined(separator: " ")
            )
            return
        }
        showCandidateWindow(client: sender)
    }

    private func resetCandidateFilters() {
        unfilteredCandidates = nil
        candidateFilterConditions = []
        candidateFilterDraft = nil
    }

    private func refreshCandidates(client sender: Any) {
        updateTranslationModeStatus(client: sender)
        cancelFuzzySuggestionSearch()
        fuzzySuggestionWindow.hide()
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
        updatePostalAddressCandidatesIfNeeded(for: inputBuffer)
        let calculatorCandidates = CalculatorCandidateGenerator.candidates(
            for: inputBuffer
        )
        if !calculatorCandidates.isEmpty {
            replaceCurrentCandidates(with: calculatorCandidates)
            showCandidateWindow(client: sender)
            return
        }
        let unitConversionCandidates = UnitConversionCandidateGenerator
            .candidates(for: inputBuffer)
        if !unitConversionCandidates.isEmpty {
            replaceCurrentCandidates(with: unitConversionCandidates)
            showCandidateWindow(client: sender)
            return
        }
        let groupedNumberCandidates = NumberGroupingCandidateGenerator
            .candidates(for: inputBuffer)
        let numericUnitCandidates = JapaneseNumericUnitCandidateGenerator
            .candidates(for: inputBuffer)
        let numericFormatCandidates = groupedNumberCandidates.isEmpty
                && numericUnitCandidates.isEmpty
            ? []
            : groupedNumberCandidates
                + JapaneseNumberConverter.kanjiCandidates(for: inputBuffer)
                + numericUnitCandidates
            + (suggestionSearchSession.query(for: .postalAddress) == inputBuffer
                ? postalAddressCandidates
                : [])
        if !numericFormatCandidates.isEmpty {
            replaceCurrentCandidates(with: numericFormatCandidates)
            showCandidateWindow(client: sender)
            return
        }
        let numberCandidates = JapaneseNumberConverter.candidates(
            for: inputBuffer
        )
        if !numberCandidates.isEmpty {
            replaceCurrentCandidates(with: numberCandidates)
            showCandidateWindow(client: sender)
            return
        }
        let symbolCandidates = JapaneseSymbolConverter.candidates(
            for: inputBuffer
        )
        if !symbolCandidates.isEmpty {
            replaceCurrentCandidates(with: symbolCandidates)
            showCandidateWindow(client: sender)
            return
        }

        let suggestionInput = conversionReading
        defer {
            updateOfficialCandidatesIfNeeded(for: suggestionInput)
            updateJavaScriptExtensionCandidatesIfNeeded(for: suggestionInput)
        }

        let lookupReadings =
            RomajiCanonicalizer.dictionaryLookupInputs(
                from: conversionReading
            )
        let dateTimeCandidates: [String] = []
        let userCandidates = mergedCandidateGroups(
            lookup: { userConversionEngine.candidateGroups(matching: $0) },
            readings: lookupReadings
        )
        let basicCandidates = mergedCandidateGroups(
            lookup: { basicConversionEngine.candidateGroups(matching: $0) },
            readings: lookupReadings
        )
        let imeCandidates = mergedCandidateGroups(
            lookup: {
                mozcConversionEngine.candidateGroups(
                    matching: $0,
                    limit: Self.maximumMozcDictionaryPrefixCandidates
                )
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
        let scriptCandidates = suggestionSearchSession.query(
            for: .javaScriptExtensions
        ) == conversionReading
            ? javaScriptExtensionCandidates
            : []
        let numericPrefixCandidates = numericPrefixCandidates(
            for: conversionReading
        )
        let uppercaseCandidates = inputBuffer == conversionReading
            ? EnglishCandidateCaseRestorer.uppercaseCandidate(
                for: conversionReading
            ).map { [$0] } ?? []
            : []
        let inflectionCandidates = mergedCandidates(
            lookup: {
                verbInflectionGenerator.candidates(for: $0)
                    + VerbInflectionCandidateGenerator.candidates(for: $0) {
                        mozcConversionEngine.candidates(for: $0)
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
            + dateTimeCandidates
            + numericPrefixCandidates
            + scriptCandidates
            + basicCandidates.exact
            + imeCandidates.exact
            + inflectionCandidates
        let otherCandidates = userCandidates.prefix
            + candidateSelectionHistory.completions(
                for: conversionReading,
                limit: Self.maximumCandidateCount * 2
            )
            + remoteCandidates
            + imeCandidates.prefix
            + basicCandidates.prefix
        let contextualCandidates = isNextInputPredictionEnabled
            ? nextInputPredictionModel.candidatesAfterLastInput(
                limit: NextInputPredictionModel.maximumFollowersPerContext
            )
            : []
        replaceCurrentCandidates(with: CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: kanaCandidates,
                direct: directCandidates,
                other: otherCandidates,
                english: englishCandidates,
                trailing: uppercaseCandidates,
                recencyRanks: candidateSelectionHistory.ranks(
                    for: conversionReading
                ),
                contextualCandidates: contextualCandidates,
                prioritizeKana: kanaCandidates.first?.count == 1
            )
        ))

        updateNeuralContextCandidates(
            reading: kanaCandidates.first ?? conversionReading,
            client: sender
        )

        guard !currentCandidates.isEmpty else {
            selectedCandidateIndex = nil
            candidateWindow.hide()
            showInputPreview(client: sender)
            return
        }

        showCandidateWindow(client: sender)
        let auxiliaryAnchorFrame = candidateAndInputFrame(for: sender)
        updateFuzzySuggestionsIfNeeded(
            near: auxiliaryAnchorFrame
        )
        showInputPreview(client: sender)
    }

    private func updateNeuralContextCandidates(
        reading: String,
        client sender: Any
    ) {
        guard isNeuralContextEnabled,
              !secureInputPassthroughActive,
              let modelURL = NeuralContextCandidateProvider.modelURL(),
              FileManager.default.fileExists(atPath: modelURL.path),
              !reading.isEmpty,
              !currentCandidates.isEmpty else {
            resetNeuralContextRanking()
            return
        }
        let context = leftSideContext(from: sender)
        guard !context.isEmpty else {
            resetNeuralContextRanking()
            return
        }
        let query = NeuralContextQuery(
            input: conversionReading,
            reading: reading,
            context: context
        )
        if cachedNeuralContextQuery == query {
            replaceCurrentCandidates(with: NeuralCandidateRanker.ordered(
                currentCandidates,
                neuralCandidates: cachedNeuralCandidates
            ))
            return
        }
        if neuralContextQuery == query, neuralContextTask != nil {
            return
        }
        neuralContextTask?.cancel()
        neuralContextQuery = query
        cachedNeuralContextQuery = nil
        cachedNeuralCandidates = []
        let provider = neuralContextProvider
        neuralContextTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(80))
            guard !Task.isCancelled else { return }
            let neuralCandidates = await provider.candidates(
                for: reading,
                context: context,
                modelURL: modelURL,
                limit: Self.maximumCandidateCount * 3
            )
            guard let self, !Task.isCancelled,
                  self.neuralContextQuery == query,
                  self.conversionReading == query.input,
                  !self.inputBuffer.isEmpty else { return }
            self.neuralContextTask = nil
            self.cachedNeuralContextQuery = query
            self.cachedNeuralCandidates = neuralCandidates
            self.replaceCurrentCandidates(with: NeuralCandidateRanker.ordered(
                self.currentCandidates,
                neuralCandidates: neuralCandidates
            ))
            self.showCandidateWindow(client: sender)
        }
    }

    private func replaceCurrentCandidates(with candidates: [String]) {
        let selectedCandidate = selectedCandidateIndex.flatMap { index in
            currentCandidates.indices.contains(index)
                ? currentCandidates[index]
                : nil
        }
        currentCandidates = candidates
        if let selectedCandidate {
            selectedCandidateIndex = currentCandidates.firstIndex(
                of: selectedCandidate
            )
        } else if selectedCandidateIndex != nil {
            selectedCandidateIndex = nil
        }
    }

    private func resetNeuralContextRanking() {
        neuralContextTask?.cancel()
        neuralContextTask = nil
        neuralContextQuery = nil
        cachedNeuralContextQuery = nil
        cachedNeuralCandidates = []
    }

    private func leftSideContext(from sender: Any) -> String {
        guard let textClient = sender as? IMKTextInput else {
            return recentCommittedContext
        }
        let markedRange = textClient.markedRange()
        let selectedRange = textClient.selectedRange()
        let end = markedRange.location != NSNotFound
            ? markedRange.location
            : selectedRange.location
        if end != NSNotFound, end > 0 {
            let length = min(end, 256)
            let range = NSRange(location: end - length, length: length)
            if let context = textClient.attributedSubstring(from: range)?.string,
               !context.isEmpty {
                return context
            }
        }
        return recentCommittedContext
    }

    private func updateFuzzySuggestionsIfNeeded(
        near anchorFrame: NSRect
    ) {
        suggestionSearchSession.cancel(.fuzzy)
        guard isFuzzySuggestionsEnabled,
              conversionReading.count >= 2 else {
            fuzzySuggestionWindow.hide()
            fuzzySuggestions = []
            selectedFuzzySuggestionIndex = nil
            return
        }

        let query = conversionReading
        let mozcDictionary = mozcConversionEngine
        let compoundGenerator = compoundDictionaryCandidateGenerator
        let visibleCandidates = Set(currentCandidates)
        let token = suggestionSearchSession.begin(.fuzzy, query: query)
        let task = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(80))
                let matchTiers = await Task.detached(priority: .userInitiated) {
                    let keyboardMatches =
                        RomajiKeyboardTypoGenerator.dictionaryMatches(
                            for: query,
                            dictionary: mozcDictionary
                        )
                    var seenReadings = Set<String>()
                    let fuzzyMatches = Self.fuzzyEngineRepository.matches(
                        for: query,
                        limit: .max
                    )
                    let combined = (keyboardMatches
                        + fuzzyMatches).filter {
                            seenReadings.insert($0.reading).inserted
                        }
                    let filtered = Array(FuzzyConversionMatchFilter.filtered(
                        combined,
                        excluding: visibleCandidates
                    ))
                    let compoundMatches = compoundGenerator
                        .matches(for: query) {
                            mozcDictionary.candidates(for: $0)
                        } typoMatches: { segment in
                            var seenReadings = Set<String>()
                            let keyboardMatches =
                                RomajiKeyboardTypoGenerator.dictionaryMatches(
                                    for: segment,
                                    dictionary: mozcDictionary
                                )
                            let fuzzyMatches = Self.fuzzyEngineRepository
                                .matches(
                                    for: segment,
                                    maximumDistance: 1,
                                    limit: 4
                                )
                            return (keyboardMatches + fuzzyMatches).filter {
                                seenReadings.insert($0.reading).inserted
                            }
                        }
                        .filter { !visibleCandidates.contains($0.text) }
                        .map {
                            FuzzyConversionMatch(
                                reading: $0.reading,
                                candidates: [$0.text],
                                distance: $0.typoDistance
                            )
                        }
                    return [filtered, compoundMatches]
                }.value
                try Task.checkCancellation()
                guard let self,
                      suggestionSearchSession.isCurrent(token),
                      conversionReading == query,
                      isFuzzySuggestionsEnabled else {
                    return
                }
                applySpellingSuggestions(matchTiers, near: anchorFrame)
            } catch is CancellationError {
                return
            } catch {
                NSLog("誤入力補完に失敗: %@", error.localizedDescription)
            }
        }
        suggestionSearchSession.attach(task, to: token)
    }

    private func applySpellingSuggestions(
        _ matchTiers: [[FuzzyConversionMatch]],
        near anchorFrame: NSRect
    ) {
        let suggestionTiers = matchTiers.map { matches in
            matches.compactMap { match in
                match.candidates.first.map {
                    FuzzySuggestion(
                        candidate: $0,
                        reading: match.reading,
                        distance: match.distance
                    )
                }
            }
        }
        let orderedTierIndices = TieredCandidateOrderer.orderedIndices(
            for: suggestionTiers.map { $0.map(\.candidate) },
            ranks: candidateSelectionHistory.ranks(for: conversionReading)
        )
        var seenCandidates = Set<String>()
        fuzzySuggestions = zip(suggestionTiers, orderedTierIndices).flatMap {
            suggestions, indices in
            indices.compactMap { index in
                let suggestion = suggestions[index]
                return seenCandidates.insert(suggestion.candidate).inserted
                    ? suggestion
                    : nil
            }
        }
        selectedFuzzySuggestionIndex = nil
        guard !fuzzySuggestions.isEmpty else {
            fuzzySuggestionWindow.hide()
            return
        }
        fuzzySuggestionWindow.show(
            suggestions: Array(fuzzySuggestions.prefix(
                Self.initialFuzzySuggestionCount
            )),
            selectedIndex: nil,
            near: anchorFrame,
            isAccented: isTranslationModeEnabled
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
            let suggestion = fuzzySuggestions[selectedFuzzySuggestionIndex]
            return acceptFuzzySuggestion(suggestion, suffix: "", client: sender)
        case 48, 125, 124:
            let next = (selectedFuzzySuggestionIndex + 1)
                % fuzzySuggestions.count
            return selectFuzzySuggestion(index: next, client: sender)
        case 49:
            let suggestion = fuzzySuggestions[selectedFuzzySuggestionIndex]
            return acceptFuzzySuggestion(suggestion, suffix: " ", client: sender)
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
                suggestions: Array(fuzzySuggestions.prefix(
                    Self.initialFuzzySuggestionCount
                )),
                selectedIndex: nil,
                near: candidateAndInputFrame(for: sender),
                isAccented: isTranslationModeEnabled
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
            let suggestion = fuzzySuggestions[selectedFuzzySuggestionIndex]
            _ = acceptFuzzySuggestion(suggestion, suffix: "", client: sender)
            return nil
        }
    }

    private func acceptFuzzySuggestion(
        _ suggestion: FuzzySuggestion,
        suffix: String,
        client sender: Any
    ) -> Bool {
        do {
            try saveUserDictionaryEntry(
                reading: suggestion.reading,
                candidate: suggestion.candidate
            )
        } catch {
            NSLog(
                "もしかして候補のユーザー辞書登録に失敗: %@",
                error.localizedDescription
            )
        }
        recordCandidateSelection(
            suggestion.candidate,
            reading: suggestion.reading
        )
        let value = suggestion.candidate + conversionSuffix
        guard isTranslationModeEnabled else {
            commit(value + suffix, to: sender)
            return true
        }
        insertIntoTranslationDraft(value + suffix)
        inputBuffer = ""
        inputCursor = 0
        currentCandidates = []
        selectedCandidateIndex = nil
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
        fuzzySuggestionWindow.hide()
        updateMarkedText(in: sender)
        showTranslationDraft(client: sender)
        recordTranslationSourceInput(value, client: sender)
        return true
    }

    private func removeSelectedFuzzySuggestionFromUserDictionary(
        client sender: Any
    ) {
        guard let selectedFuzzySuggestionIndex,
              fuzzySuggestions.indices.contains(selectedFuzzySuggestionIndex) else {
            NSSound.beep()
            return
        }
        let suggestion = fuzzySuggestions[selectedFuzzySuggestionIndex]
        let updatedEntries = UserDictionaryEditor.removing(
            candidate: suggestion.candidate,
            matchingReadings: [suggestion.reading],
            from: userEntries
        )
        guard updatedEntries != userEntries else {
            NSSound.beep()
            return
        }
        do {
            userEntries = updatedEntries
            try persistUserDictionary()
            candidateSelectionHistory.remove([suggestion.candidate])
            candidateSelectionHistoryWriter.schedule(candidateSelectionHistory)
            self.selectedFuzzySuggestionIndex = nil
            updateMarkedText(in: sender)
            refreshCandidates(client: sender)
        } catch {
            NSLog(
                "もしかして候補のユーザー辞書削除に失敗: %@",
                error.localizedDescription
            )
            userEntries = Self.loadUserEntries()
            rebuildConversionEngine()
            NSSound.beep()
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
        let displayValue = suggestion.candidate + conversionSuffix
        setMarkedText(
            translationDraft == nil
                ? displayValue
                : compositionPrefix + displayValue + compositionSuffix,
            in: sender
        )
        showFuzzySuggestionPage(selectedIndex: index, client: sender)
        showPreview(for: suggestion.candidate)
        return true
    }

    private func showFuzzySuggestionPage(
        selectedIndex: Int,
        client sender: Any
    ) {
        let pageStart = selectedIndex
            / Self.maximumCandidateCount
            * Self.maximumCandidateCount
        let pageEnd = min(
            pageStart + Self.maximumCandidateCount,
            fuzzySuggestions.count
        )
        fuzzySuggestionWindow.show(
            suggestions: Array(fuzzySuggestions[pageStart..<pageEnd]),
            selectedIndex: selectedIndex - pageStart,
            near: candidateAndInputFrame(for: sender),
            isAccented: isTranslationModeEnabled
        )
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
        guard isWikipediaSuggestionsEnabled
                || isGoogleJapaneseInputEnabled
                || isAppleTranslationEnabled,
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
                async let google: [String] = isGoogleJapaneseInputEnabled
                    ? (try? await GoogleJapaneseInputClient().candidates(for: japaneseInput)) ?? []
                    : []
                let apple = await appleTranslationCandidate(
                    for: japaneseInput,
                    sentenceMode: false
                )
                let suggestions = await wikipedia + google + apple
                try Task.checkCancellation()
                guard suggestionSearchSession.isCurrent(token),
                      isWikipediaSuggestionsEnabled
                        || isGoogleJapaneseInputEnabled
                        || isAppleTranslationEnabled,
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

    private func updateJavaScriptExtensionCandidatesIfNeeded(for input: String) {
        guard !input.isEmpty,
              suggestionSearchSession.query(for: .javaScriptExtensions)
                != input else {
            return
        }
        javaScriptExtensionCandidates = []
        let token = suggestionSearchSession.begin(
            .javaScriptExtensions,
            query: input
        )
        let task = Task { @MainActor [weak self] in
            guard let self else { return }
            let candidates = await Self.javaScriptExtensionClient.candidates(
                for: input,
                dateTimeCandidatesEnabled: isDateTimeCandidatesEnabled
            )
            guard !Task.isCancelled,
                  suggestionSearchSession.isCurrent(token),
                  conversionReading == input else {
                return
            }
            javaScriptExtensionCandidates = candidates
            if let inputClient = client() {
                refreshCandidates(client: inputClient)
            }
        }
        suggestionSearchSession.attach(task, to: token)
    }

    private func updatePostalAddressCandidatesIfNeeded(for input: String) {
        guard let postalCode = PostalCodeNormalizer.normalize(input) else {
            suggestionSearchSession.cancel(.postalAddress)
            postalAddressCandidates = []
            return
        }
        guard suggestionSearchSession.query(for: .postalAddress) != input else {
            return
        }
        let token = suggestionSearchSession.begin(.postalAddress, query: input)
        if let cached = postalAddressCache[postalCode] {
            postalAddressCandidates = cached
            return
        }
        postalAddressCandidates = []
        let task = Task { @MainActor [weak self] in
            let candidates = (try? await PostalAddressCandidateClient()
                .candidates(for: postalCode)) ?? []
            guard !Task.isCancelled,
                  let self,
                  suggestionSearchSession.isCurrent(token),
                  inputBuffer == input else {
                return
            }
            postalAddressCache[postalCode] = candidates
            postalAddressCandidates = candidates
            if let inputClient = client() {
                refreshCandidates(client: inputClient)
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
        MyIMFeatureShortcut.webSearch.shortcut.matches(event)
    }

    private func isOpenExternalInformationShortcut(
        _ event: NSEvent
    ) -> Bool {
        MyIMFeatureShortcut.externalInformation.shortcut.matches(event)
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
        candidate: String,
        display: String? = nil
    ) throws {
        userEntries = UserDictionaryEditor.adding(
            reading: reading,
            candidate: candidate,
            display: display,
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
        let historyCandidates: Set<String> = [
            candidate,
            candidateDisplayValue(candidate),
            candidateValueForCommit(candidate)
        ]
        let updatedEntries = UserDictionaryEditor.removing(
            candidate: candidate,
            from: userEntries
        )
        let removesDictionaryEntry = updatedEntries != userEntries
        let removesHistory = historyCandidates.contains {
            candidateSelectionHistory.ranks[$0] != nil
        }
        guard removesDictionaryEntry || removesHistory else {
            NSSound.beep()
            return
        }

        do {
            if removesDictionaryEntry {
                userEntries = updatedEntries
                try persistUserDictionary()
            }
            candidateSelectionHistory.remove(historyCandidates)
            candidateSelectionHistoryWriter.schedule(
                candidateSelectionHistory
            )
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            pasteboard.setString(
                candidateValueForCommit(candidate),
                forType: .string
            )
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

    private func beginSecureInputPassthroughIfNeeded(client sender: Any) {
        guard !secureInputPassthroughActive else { return }
        secureInputPassthroughActive = true
        activatedAt = nil
        NSLog("myim: Secure Event Inputを検知し、キー処理を停止")
        clearCompositionForSystemPaste(in: sender)
        translationTask?.cancel()
        translationTask = nil
        translationDraft = nil
        resetTransientInteractionState()
        modeStatusWindow.hide()
        nextInputPredictionModel.breakSequence()
    }

    private var secureInputStatusDescription: String {
        if SecureInputDetector.isEnabled {
            return "検知中（myim処理停止）"
        }
        return secureInputPassthroughActive ? "直前に検知" : "通常"
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
        MyIMFeatureShortcut.translationMode.shortcut.matches(event)
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
        var guide: String
        if isDictionaryRegistration {
            guide = selectedCandidateIndex == nil
                ? "Tab 候補選択　↩ 入力を追加\nEsc 登録中止"
                : "Tab / 矢印 移動\n↩ 入力を追加　Esc 登録中止"
        } else if isTranslationInput {
            guide = selectedCandidateIndex == nil
                ? "Tab 候補選択　Return 原文に追加\n原文確定後にもう一度Returnで翻訳　Esc 日本語で確定"
                : "Tab / 矢印 移動　Return 原文に追加\n原文確定後にもう一度Returnで翻訳　Esc 日本語で確定"
        } else {
            guide = selectedCandidateIndex == nil
                ? "Tab 選択　\(MyIMFeatureShortcut.dictionaryRegistration.shortcut.displayName) 辞書登録\nF6–F10 文字種変換　\(MyIMFeatureShortcut.externalInformation.shortcut.displayName) 外部ページ"
                : "Tab / 矢印 移動　↩ 確定　Esc 解除\n\(MyIMFeatureShortcut.dictionaryRegistration.shortcut.displayName) 辞書登録　⌘X 削除　\(MyIMFeatureShortcut.webSearch.shortcut.displayName) Web検索　\(MyIMFeatureShortcut.externalInformation.shortcut.displayName) 外部ページ"
        }

        if !candidateFilterConditions.isEmpty {
            guide += "\n文字入力 次の条件を追加"
        }

        let filterTitle = candidateFilterConditions.isEmpty
            ? nil
            : candidateFilterConditions.map { "[\($0.label)]" }.joined(separator: " ")
        candidateWindow.show(
            candidates: currentCandidates[pageStart..<pageEnd].map {
                candidateDisplayValue($0)
            },
            selectedIndex: selectedCandidateIndex.map { $0 - pageStart },
            near: inputLocation(for: sender),
            guide: guide,
            modeTitle: filterTitle ?? (isDictionaryRegistration
                ? "登録したい文字列を入力"
                : (isTranslationInput ? "翻訳する日本語" : nil)),
            isAccented: isTranslationInput
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
        let frame = candidateWindow.frame
        guard inputFrame != .zero else { return frame }
        return frame.union(inputFrame)
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
        let calculatorNextInputCandidates = selectedCandidateIndex == nil
            ? CalculatorCandidateGenerator.candidates(for: inputBuffer)
            : []
        recordSelectedCandidate()
        commit(
            value,
            to: sender,
            preferredNextInputCandidates: calculatorNextInputCandidates
        )
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

    private func recordTranslationSourceInput(
        _ value: String,
        client sender: Any
    ) {
        guard isNextInputPredictionEnabled, !value.isEmpty else { return }
        nextInputPredictionModel.record(value)
        nextInputPredictionWriter.schedule(nextInputPredictionModel)
        nextInputCandidates = nextInputPredictionModel.candidates(
            after: value,
            limit: Self.maximumCandidateCount
        )
        selectedNextInputIndex = nil
        guard !nextInputCandidates.isEmpty else { return }
        candidateWindow.show(
            candidates: nextInputCandidates,
            selectedIndex: nil,
            near: inputLocation(for: sender),
            guide: "Tab 選択　Return 原文に追加\n候補未選択でReturn 翻訳　Esc 閉じる",
            isAccented: true
        )
        scheduleNextInputDismissal()
    }

    private func recordCandidateSelection(
        _ candidate: String,
        reading: String? = nil
    ) {
        let learnedReading = reading ?? conversionReading
        candidateSelectionHistory.record(
            candidate,
            reading: learnedReading
        )
        candidateSelectionHistoryWriter.schedule(
            candidateSelectionHistory
        )
    }

    private func candidatesOrderedByRecency(
        _ candidates: [String]
    ) -> [String] {
        CandidateRecencyOrderer.ordered(
            candidates,
            ranks: candidateSelectionHistory.ranks(for: conversionReading)
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

    private func numericPrefixCandidates(for input: String) -> [String] {
        guard let parts = NumericPrefixCandidateComposer.parts(of: input) else {
            return []
        }
        let readings = RomajiCanonicalizer.dictionaryLookupInputs(
            from: parts.reading
        )
        let user = mergedCandidateGroups(
            lookup: { userConversionEngine.candidateGroups(matching: $0) },
            readings: readings
        ).exact
        let ime = mergedCandidateGroups(
            lookup: {
                mozcConversionEngine.candidateGroups(
                    matching: $0,
                    limit: Self.maximumMozcDictionaryPrefixCandidates
                )
            },
            readings: readings
        ).exact
        let basic = mergedCandidateGroups(
            lookup: { basicConversionEngine.candidateGroups(matching: $0) },
            readings: readings
        ).exact
        let kana = [
            romajiConverter.hiragana(from: parts.reading),
            romajiConverter.katakana(from: parts.reading)
        ].compactMap { $0 }
        let converted = CandidateRecencyOrderer.ordered(
            user + ime + basic + kana,
            ranks: candidateSelectionHistory.ranks(for: parts.reading)
        )
        return NumericPrefixCandidateComposer.candidates(
            for: input,
            convertedReadings: converted
        )
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

        resetCandidateFilters()

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
        var editor = InputBufferEditor(
            value: draft,
            cursor: translationDraftCursor
        )
        editor.deleteBackward(unit: unit)
        translationDraft = editor.value.nilIfEmpty
        translationDraftCursor = translationDraft == nil ? 0 : editor.cursor
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
        updateTranslationModeStatus(client: sender)
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
        historyValue: String? = nil,
        preferredNextInputCandidates: [String] = [],
        recordsInputHistory: Bool = true
    ) {
        guard let textClient = sender as? IMKTextInput else {
            return
        }

        let markedRange = textClient.markedRange()
        let beginsAfterLineBreak = inputBeginsAfterLineBreak(
            textClient,
            markedRange: markedRange
        )
        let replacementRange = replacingMarkedText
            && markedRange.location != NSNotFound
            && markedRange.length > 0
            ? markedRange
            : NSRange(location: NSNotFound, length: NSNotFound)
        textClient.insertText(
            value,
            replacementRange: replacementRange
        )
        recentCommittedContext = String(
            (recentCommittedContext + value).suffix(256)
        )
        resetNeuralContextRanking()
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
        clearCalendarSelection()
        resetCandidateFilters()
        if recordsInputHistory {
            recordCommittedInput(
                historyValue ?? value,
                preferredCandidates: preferredNextInputCandidates,
                breakPreviousSequence: beginsAfterLineBreak,
                client: sender
            )
        }
        updateTranslationModeStatus(client: sender)
    }

    private func inputBeginsAfterLineBreak(
        _ textClient: IMKTextInput,
        markedRange: NSRange
    ) -> Bool {
        let selectedRange = textClient.selectedRange()
        let inputStart = markedRange.location != NSNotFound
            ? markedRange.location
            : selectedRange.location
        if inputStart != NSNotFound, inputStart > 0 {
            let length = min(inputStart, 2)
            let range = NSRange(
                location: inputStart - length,
                length: length
            )
            if let precedingText = textClient.attributedSubstring(
                from: range
            )?.string,
               InputSequenceBoundary.endsWithLineBreak(precedingText) {
                return true
            }
        }
        return InputSequenceBoundary.endsWithLineBreak(
            recentCommittedContext
        )
    }

    private func resetTransientInteractionState() {
        translationTask?.cancel()
        translationTask = nil
        resetNeuralContextRanking()
        calendarFormatTask?.cancel()
        calendarFormatTask = nil
        dictionaryDefinitionTask?.cancel()
        dictionaryDefinitionTask = nil
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
        clearCalendarSelection()
        resetCandidateFilters()
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
        if translationDraft != nil {
            updateMarkedText(in: sender)
        } else {
            setMarkedText(nextInputCandidates[index], in: sender)
        }
        showPreview(for: nextInputCandidates[index])
        nextInputDismissTimer?.invalidate()
        nextInputDismissTimer = nil
        return true
    }

    private func recordCommittedInput(
        _ value: String,
        preferredCandidates: [String] = [],
        breakPreviousSequence: Bool = false,
        client sender: Any
    ) {
        var learnedCandidates: [String] = []
        if isNextInputPredictionEnabled {
            if breakPreviousSequence {
                nextInputPredictionModel.breakSequence()
            }
            nextInputPredictionModel.record(value)
            nextInputPredictionWriter.schedule(nextInputPredictionModel)

            learnedCandidates = nextInputPredictionModel.candidates(
                after: value,
                limit: Self.maximumCandidateCount
            )
        }

        nextInputCandidates = NextInputCandidateMerger.merged(
            preferred: preferredCandidates,
            learned: learnedCandidates,
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
            guide: isTranslationModeEnabled
                ? "Tab 選択　Return 原文に追加\n候補未選択でReturn 翻訳　Esc 閉じる"
                : "Tab 選択　Return / Esc 閉じる\n選択後はTab / 矢印 移動　Return 確定",
            isAccented: isTranslationModeEnabled
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
            if translationDraft != nil {
                updateMarkedText(in: sender)
            } else {
                setMarkedText("", in: sender)
            }
        }
        nextInputCandidates = []
        selectedNextInputIndex = nil
        candidateWindow.hide()
        previewWindow.hide()
    }

    private func updateMarkedText(in sender: Any) {
        setMarkedText(
            compositionPrefix + inputBuffer + compositionSuffix,
            in: sender,
            selectionOffset: compositionPrefix.utf16.count + inputCursor
        )
    }

    private var compositionPrefix: String {
        if let confirmedCandidate = tabDictionaryRegistration?.confirmedCandidate {
            return confirmedCandidate
        }
        guard let translationDraft else { return "" }
        let cursor = min(translationDraftCursor, translationDraft.count)
        let index = translationDraft.index(
            translationDraft.startIndex,
            offsetBy: cursor
        )
        return String(translationDraft[..<index])
    }

    private var compositionSuffix: String {
        guard tabDictionaryRegistration == nil,
              let translationDraft else { return "" }
        let cursor = min(translationDraftCursor, translationDraft.count)
        let index = translationDraft.index(
            translationDraft.startIndex,
            offsetBy: cursor
        )
        return String(translationDraft[index...])
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
        modeStatusWindow.hide()
        resetCandidateFilters()
        var editor = InputBufferEditor(
            value: inputBuffer,
            cursor: inputCursor
        )
        editor.insert(text)
        inputBuffer = editor.value
        inputCursor = editor.cursor
    }

    private func updateTranslationModeStatus(client sender: Any) {
        guard isTranslationModeEnabled,
              inputBuffer.isEmpty,
              translationDraft == nil else {
            modeStatusWindow.hide()
            return
        }
        modeStatusWindow.show(
            enabled: true,
            near: inputLocation(for: sender),
            dismissesAutomatically: false
        )
    }

    private func moveInputCursor(by offset: Int, client sender: Any) -> Bool {
        if inputBuffer.isEmpty, let translationDraft {
            var editor = InputBufferEditor(
                value: translationDraft,
                cursor: translationDraftCursor
            )
            guard editor.move(by: offset) else { return true }
            translationDraftCursor = editor.cursor
            updateMarkedText(in: sender)
            return true
        }
        guard !inputBuffer.isEmpty else { return false }
        var editor = InputBufferEditor(
            value: inputBuffer,
            cursor: inputCursor
        )
        guard editor.move(by: offset) else { return true }
        inputCursor = editor.cursor
        if !compositionPrefix.isEmpty {
            setMarkedText(
                compositionPrefix + inputBuffer + compositionSuffix,
                in: sender,
                selectionOffset: compositionPrefix.utf16.count + inputCursor
            )
        } else {
            updateMarkedText(in: sender)
        }
        return true
    }

    private func showInputPreview(client sender: Any) {
        let selectedCandidate = selectedCandidateIndex.flatMap { index in
            currentCandidates.indices.contains(index)
                ? candidateDisplayValue(currentCandidates[index])
                : nil
        }
        guard let pageTitle = PreviewPageTitleResolver.pageTitle(
            input: conversionReading,
            selectedCandidate: selectedCandidate
        ) else {
            dictionaryDefinitionTask?.cancel()
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
            for: candidateDisplayValue(candidate),
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
            dictionaryDefinitionTask?.cancel()
            previewWindow.hide()
            return
        }
        let url = isExternalInformationPanelEnabled
            ? try? SearchURLTemplate(externalInformationURLTemplate)
                .url(for: candidate)
            : nil

        dictionaryDefinitionTask?.cancel()
        let previewRequestID = previewWindow.show(
            url: url,
            panelTitle: url?.host ?? "外部情報",
            definitions: [],
            showExternalInformation: isExternalInformationPanelEnabled,
            beside: anchorFrame
        )
        guard includeDefinitions, isSystemDictionaryPreviewEnabled else {
            return
        }
        let provider = definitionProvider
        let dictionaryNames = systemDictionaryNames
        dictionaryDefinitionTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else { return }
            let definitions = await Task.detached(priority: .utility) {
                provider.definitions(
                    for: candidate,
                    dictionaryNames: dictionaryNames
                )
            }.value
            guard !Task.isCancelled, let self else { return }
            previewWindow.showDefinitions(
                definitions,
                beside: anchorFrame,
                requestID: previewRequestID
            )
        }
    }

    private func rebuildConversionEngine(
        basicDictionaryChanged: Bool = false
    ) {
        userConversionEngine = ConversionEngine(entries: userEntries)
        if basicDictionaryChanged {
            basicConversionEngine = ConversionEngine(entries: basicEntries)
            verbInflectionGenerator = VerbInflectionCandidateGenerator(
                entries: basicEntries
            )
        }
        compoundDictionaryCandidateGenerator =
            CompoundDictionaryCandidateGenerator(
                layers: [userEntries, basicEntries]
            )
        rebuildFuzzyConversionEngine()
    }

    private func rebuildFuzzyConversionEngine() {
        cancelFuzzySuggestionSearch()
        fuzzyEngineBuildTask?.cancel()
        let userEntries = userEntries
        let basicEntries = basicEntries
        fuzzyEngineBuildTask = Task { @MainActor [weak self] in
            await Task.detached(priority: .utility) {
                let entries = userEntries
                    + basicEntries
                    + VerbInflectionCandidateGenerator.typoSearchEntries(
                        from: basicEntries
                    )
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
        if NumericPrefixCandidateComposer.parts(of: inputBuffer) != nil {
            return inputBuffer
        }
        return String(
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
            || !UnitConversionCandidateGenerator.candidates(
                for: inputBuffer
            ).isEmpty
            || !NumberGroupingCandidateGenerator.candidates(
                for: inputBuffer
            ).isEmpty
            || !JapaneseNumericUnitCandidateGenerator.candidates(
                for: inputBuffer
            ).isEmpty
            || PostalCodeNormalizer.normalize(inputBuffer) != nil
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

    private var isNeuralContextEnabled: Bool {
        UserDefaults.standard.bool(
            forKey: Self.neuralContextEnabledDefaultsKey
        )
    }

    private var neuralContextModelIsInstalled: Bool {
        guard let url = NeuralContextCandidateProvider.modelURL() else {
            return false
        }
        return FileManager.default.fileExists(atPath: url.path)
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
        return true
    }

    private var externalInformationURLTemplate: String {
        JavaScriptExtensionConfiguration.externalInformationURL(
            project: ""
        ) ?? defaultExternalInformationURLTemplate
    }

    private var defaultExternalInformationURLTemplate: String {
        "https://ja.wikipedia.org/w/index.php?search=%s"
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

    private var isGoogleJapaneseInputEnabled: Bool {
        UserDefaults.standard.bool(
            forKey: Self.googleJapaneseInputEnabledDefaultsKey
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
        JavaScriptExtensionConfiguration.webSearchURL()
    }

    private var isSystemDictionaryPreviewEnabled: Bool {
        experimentalFeatureIsEnabled(
            defaultsKey: Self.systemDictionaryPreviewEnabledDefaultsKey
        )
    }

    private var systemDictionaryNames: [String] {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: Self.systemDictionaryNamesDefaultsKey) != nil {
            return defaults.stringArray(
                forKey: Self.systemDictionaryNamesDefaultsKey
            ) ?? []
        }
        let available = Set(definitionProvider.availableDictionaryNames())
        return SystemDictionaryDefinitionProvider.defaultDictionaryNames.filter {
            available.contains($0)
        }
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
        DictionaryCandidateRepresentation.value(from: candidate)
    }

    private func candidateDisplayValue(_ candidate: String) -> String {
        DictionaryCandidateRepresentation.display(from: candidate)
    }

    private static func loadBasicEntries() -> [DictionaryEntry] {
        guard
            let dictionaryURL = inputMethodResourceURL(
                forResource: "basic-dictionary",
                withExtension: "tsv"
            ),
            let dictionaryText = try? String(
                contentsOf: dictionaryURL,
                encoding: .utf8
            ),
            let entries = try? DictionaryParser().parse(dictionaryText)
        else {
            return []
        }
        if let cache = try? basicDictionaryCache(),
           let cachedEntries = loadEntries(from: cache) {
            return addingBundledKeyboardSymbols(
                to: cachedEntries,
                bundledEntries: entries
            )
        }
        return entries
    }

    private static func addingBundledKeyboardSymbols(
        to entries: [DictionaryEntry],
        bundledEntries: [DictionaryEntry]? = nil
    ) -> [DictionaryEntry] {
        let bundled = bundledEntries ?? {
            guard let text = loadBundledText(resource: "basic-dictionary"),
                  let parsed = try? DictionaryParser().parse(text) else {
                return []
            }
            return parsed
        }()
        let readings: Set<String> = [
            "opushon", "kontorooru", "shifuto", "supeesu", "ritaan",
            "komando", "kyappusurokku", "esukeepu", "entaa", "tabu",
            "deriito", "fowaadoderiito", "bakkusupeesu", "ijekuto",
            "command", "cmd", "option", "alt", "shift", "control",
            "ctrl", "capslock", "escape", "esc", "return", "enter",
            "tab", "delete", "forwarddelete", "backspace", "space",
            "eject"
        ]
        return entries + bundled.filter { readings.contains($0.input) }
    }

    private static func loadBundledText(resource: String) -> String? {
        guard let url = inputMethodResourceURL(
            forResource: resource,
            withExtension: "tsv"
        ) else {
            return nil
        }
        return try? String(contentsOf: url, encoding: .utf8)
    }

    private static func loadCandidateFilterDatabase() -> KanjiFilterDatabase {
        KanjiFilterDatabase(
            text: loadBundledText(resource: "kanji-filter-data") ?? ""
        )
    }

    private static func loadMozcDictionaryEngine() -> IndexedDictionaryEngine {
        guard
            let dictionaryURL = inputMethodResourceURL(
                forResource: "mozc-dictionary",
                withExtension: "tsv"
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

    private static func loadEntries(
        from cache: DictionaryCache
    ) -> [DictionaryEntry]? {
        guard
            cache.containsDictionary(),
            let readableURL = cache.readableDictionaryURL(),
            let dictionaryText = try? String(
                contentsOf: readableURL,
                encoding: .utf8
            )
        else {
            return nil
        }

        guard let entries = try? DictionaryParser().parse(dictionaryText) else {
            return nil
        }
        let tsv = DictionarySerializer.text(from: entries)
        if readableURL != cache.dictionaryURL || dictionaryText != tsv {
            let metadata = (try? cache.loadMetadata()) ?? nil
            try? cache.save(
                dictionaryText: tsv,
                metadata: metadata ?? DictionaryCacheMetadata(
                    syncedAt: Date(),
                    entryCount: entries.count
                )
            )
        }
        return entries
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
            !data.isEmpty
        else {
            return CandidateSelectionHistory()
        }
        if let history = try? JSONDecoder().decode(
            CandidateSelectionHistory.self,
            from: data
        ) {
            return history
        }
        if let legacyRanks = try? JSONDecoder().decode(
            [String: Int].self,
            from: data
        ) {
            return CandidateSelectionHistory(ranks: legacyRanks)
        }
        return CandidateSelectionHistory()
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

}

private struct BundledBasicDictionaryMetadata: Decodable {
    let generated: String
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
