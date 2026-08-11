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
    private static let basicDictionaryEnabledDefaultsKey =
        "BasicDictionaryEnabled"
    private static let userDictionaryEnabledDefaultsKey =
        "UserDictionaryEnabled"
    private static let extensionDictionaryEnabledDefaultsKey =
        "ExtensionDictionaryEnabled"
    private static let englishCompletionEnabledDefaultsKey =
        "EnglishCompletionEnabled"
    private static let wikipediaSuggestionsEnabledDefaultsKey =
        "WikipediaSuggestionsEnabled"
    private static let appleTranslationEnabledDefaultsKey =
        "AppleTranslationEnabled"
    private static let azureDictionaryEnabledDefaultsKey =
        "AzureDictionaryEnabled"
    private static let azureDictionaryRegionDefaultsKey = "AzureDictionaryRegion"
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
    private static let semanticSuggestionsEnabledDefaultsKey =
        "SemanticSuggestionsEnabled"
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

    private var inputBuffer = ""
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
    private var fuzzyConversionEngine: FuzzyConversionEngine
    private let credentialStore: CosenseCredentialStore
    private let externalCredentialStore = ExternalServiceCredentialStore()
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
    private let candidatePanel: IMKCandidates
    private let candidateWindow = CandidateWindowController()
    private let fuzzySuggestionWindow = FuzzySuggestionWindowController()
    private let previewWindow = ExternalInformationWindowController()
    private let definitionProvider = SystemDictionaryDefinitionProvider()
    private let romajiConverter = RomajiConverter()
    private let semanticVectorSearchEngine: SemanticVectorSearchEngine
#if canImport(Translation)
    private var semanticTranslationProvider: AnyObject?
#endif
    private weak var authenticationTokenInput: NSSecureTextField?
    private var settingsWindow: NSWindow?

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let source = Self.loadDictionarySource()
        let credentialStore = CosenseCredentialStore()
        let cachedUserEntries = Self.loadUserEntries()
        let bundledEntries = Self.loadBasicEntries()
        let indexedIMEEngine = Self.loadIMEDictionaryEngine()
        let cachedExtensionEntries = Self.loadExtensionEntries(for: source)
        let selectionHistory = Self.loadCandidateSelectionHistory()
        let nextInputModel = Self.loadNextInputPredictionModel()
        let semanticDictionaryURL = Self.inputMethodResourceURL(
            forResource: "semantic-dictionary",
            withExtension: "jsonl"
        )
        let semanticVectorIndexURL = Self.inputMethodResourceURL(
            forResource: "semantic-vectors",
            withExtension: "bin"
        )

        dictionarySource = source
        self.credentialStore = credentialStore
        cosenseCredential = credentialStore.load(for: source.project)
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
        semanticVectorSearchEngine = SemanticVectorSearchEngine(
            dictionaryURL: semanticDictionaryURL,
            vectorIndexURL: semanticVectorIndexURL
        )
        userConversionEngine = ConversionEngine(entries: cachedUserEntries)
        extensionConversionEngine = ConversionEngine(
            entries: cachedExtensionEntries
        )
        basicConversionEngine = ConversionEngine(entries: bundledEntries)
        imeConversionEngine = indexedIMEEngine
        supplementalConversionEngine = ConversionEngine(
            entries: SupplementalDictionary.entries
        )
        verbInflectionGenerator = VerbInflectionCandidateGenerator(
            entries: bundledEntries
        )
        fuzzyConversionEngine = FuzzyConversionEngine(
            entries: cachedUserEntries
                + cachedExtensionEntries
                + bundledEntries
                + SupplementalDictionary.entries
        )
        candidatePanel = IMKCandidates(
            server: server,
            panelType: kIMKSingleColumnScrollingCandidatePanel
        )

        super.init(server: server, delegate: delegate, client: inputClient)

        candidatePanel.setDismissesAutomatically(true)
        candidatePanel.setAttributes([
            IMKCandidatesSendServerKeyEventFirst: false
        ])

        basicDictionaryStatus = bundledEntries.isEmpty
            ? "読込失敗"
            : "読込済み（TKGJE \(bundledEntries.count)＋Mozc \(indexedIMEEngine.readingCount)読み）"
        updateBasicDictionaryIfNeeded(nil)
        Task { [semanticVectorSearchEngine] in
            await semanticVectorSearchEngine.prepare()
        }
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

        if isUserDictionaryRegistrationShortcut(event),
           !inputBuffer.isEmpty {
            return !registerClipboardInUserDictionary(client: sender)
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
            if inputBuffer.isEmpty, shouldSuppressActivationSpace(event) {
                activatedAt = nil
                return true
            }
            return handleSpace(client: sender)
        case 123:
            return moveCandidate(.left, client: sender)
        case 124:
            return moveCandidate(.right, client: sender)
        case 125:
            return moveCandidate(.down, client: sender)
        case 126:
            return moveCandidate(.up, client: sender)
        case 36, 76:
            return commitFirstCandidateOrInput(to: sender)
        case 51:
            return deleteBackward(
                from: sender,
                unit: deletionUnit(for: event)
            )
        case 53:
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
            recordSelectedCandidate()
            commit(selectedValue, to: sender)
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

        inputBuffer += characters
        selectedCandidateIndex = nil
        candidatePanel.hide()
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
        let menu = NSMenu()
        menu.autoenablesItems = false
        addActionItem(
            title: "myim設定…",
            action: #selector(openSettingsWindow(_:)),
            to: menu
        )
        menu.addItem(.separator())
        addActionItem(
            title: "Cosense辞書を更新",
            action: #selector(syncCosenseDictionary(_:)),
            keyEquivalent: "r",
            modifierMask: [.command, .option, .control],
            to: menu
        )
        addActionItem(
            title: "状態を確認…",
            action: #selector(showStatus(_:)),
            to: menu
        )
        return menu
    }

    private func addActionItem(
        title: String,
        action: Selector,
        keyEquivalent: String = "",
        modifierMask: NSEvent.ModifierFlags = [],
        to menu: NSMenu
    ) {
        let item = NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: keyEquivalent
        )
        item.target = nil
        item.isEnabled = true
        item.keyEquivalentModifierMask = modifierMask
        menu.addItem(item)
    }

    private func settingsCheckbox(
        title: String,
        action: Selector,
        enabled: Bool
    ) -> NSButton {
        let button = NSButton(
            checkboxWithTitle: title,
            target: self,
            action: action
        )
        button.state = enabled ? .on : .off
        return button
    }

    @objc
    private func openSettingsWindow(_ sender: Any?) {
        if let settingsWindow {
            NSApp.activate(ignoringOtherApps: true)
            settingsWindow.makeKeyAndOrderFront(nil)
            return
        }

        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 540, height: 620),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.title = "myim設定"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.minSize = NSSize(width: 480, height: 420)

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.edgeInsets = NSEdgeInsets(
            top: 18,
            left: 20,
            bottom: 18,
            right: 20
        )

        addSettingsSection("変換候補", to: stack)
        stack.addArrangedSubview(settingsCheckbox(
            title: "ローカル基本辞書で変換候補を取得",
            action: #selector(toggleBasicDictionary(_:)),
            enabled: isBasicDictionaryEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "ローカルユーザー辞書を使用",
            action: #selector(toggleUserDictionary(_:)),
            enabled: isUserDictionaryEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "Cosense拡張辞書を使用",
            action: #selector(toggleExtensionDictionary(_:)),
            enabled: isExtensionDictionaryEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "英語補完を使用",
            action: #selector(toggleEnglishCompletion(_:)),
            enabled: isEnglishCompletionEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "Wikipedia候補を取得",
            action: #selector(toggleWikipediaSuggestions(_:)),
            enabled: isWikipediaSuggestionsEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "日本語入力から英語の変換候補を取得",
            action: #selector(toggleAppleTranslation(_:)),
            enabled: isAppleTranslationEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "Azure英訳候補を取得",
            action: #selector(toggleAzureDictionary(_:)),
            enabled: isAzureDictionaryEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "次入力候補を使用",
            action: #selector(toggleNextInputPrediction(_:)),
            enabled: isNextInputPredictionEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "曖昧検索の「もしかして？」候補を表示",
            action: #selector(toggleFuzzySuggestions(_:)),
            enabled: isFuzzySuggestionsEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "意味検索の「もしかして？」候補を表示",
            action: #selector(toggleSemanticSuggestions(_:)),
            enabled: isSemanticSuggestionsEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "日時の動的候補を表示",
            action: #selector(toggleDateTimeCandidates(_:)),
            enabled: isDateTimeCandidatesEnabled
        ))
        stack.addArrangedSubview(settingsButton(
            "日時候補の書式を設定…",
            action: #selector(configureDateTimeCandidateFormats(_:))
        ))
        stack.addArrangedSubview(settingsButton(
            "外部候補とWeb検索を設定…",
            action: #selector(configureExternalCandidates(_:))
        ))
        stack.addArrangedSubview(settingsButton(
            "次入力履歴を削除",
            action: #selector(clearNextInputPredictionHistory(_:))
        ))

        addSettingsSection("外部表示", to: stack)
        stack.addArrangedSubview(settingsCheckbox(
            title: "外部情報パネルを使用",
            action: #selector(toggleExternalInformationPanel(_:)),
            enabled: isExternalInformationPanelEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "macOS辞書パネルを使用",
            action: #selector(toggleSystemDictionaryPreview(_:)),
            enabled: isSystemDictionaryPreviewEnabled
        ))
        stack.addArrangedSubview(settingsCheckbox(
            title: "Command＋ReturnでWeb検索",
            action: #selector(toggleWebSearch(_:)),
            enabled: isWebSearchEnabled
        ))
        stack.addArrangedSubview(settingsButton(
            "外部情報パネルの検索先を設定…",
            action: #selector(configureExternalInformationPanel(_:))
        ))

        addSettingsSection("辞書管理", to: stack)
        stack.addArrangedSubview(settingsButton(
            "TKGJE基本辞書を更新",
            action: #selector(updateBasicDictionaryIfNeeded(_:))
        ))
        stack.addArrangedSubview(settingsButton(
            "Cosenseプロジェクトを設定…",
            action: #selector(configureCosenseProject(_:))
        ))
        stack.addArrangedSubview(settingsButton(
            "Cosense認証を設定…",
            action: #selector(configureCosenseAuthentication(_:))
        ))
        stack.addArrangedSubview(settingsButton(
            "Cosense辞書を更新",
            action: #selector(syncCosenseDictionary(_:))
        ))

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = stack
        stack.frame = NSRect(x: 0, y: 0, width: 520, height: 850)
        panel.contentView = scrollView
        settingsWindow = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func addSettingsSection(_ title: String, to stack: NSStackView) {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 15, weight: .semibold)
        stack.addArrangedSubview(label)
    }

    private func settingsButton(_ title: String, action: Selector) -> NSButton {
        NSButton(title: title, target: self, action: action)
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
        commit(
            candidateValueForCommit(candidate) + conversionSuffix,
            to: client() as Any
        )
    }

    override func commitComposition(_ sender: Any!) {
        guard let sender else {
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
            commit(inputBuffer, to: sender as Any)
        }
        resetTransientInteractionState()
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
        flushPendingHistoryWrites()
        super.inputControllerWillClose()
    }

    @objc
    private func configureCosenseProject(_ sender: Any?) {
        let input = NSTextField(
            string: dictionarySource.projectURLDescription
        )
        input.placeholderString = "https://scrapbox.io/project-name"
        input.frame = NSRect(x: 0, y: 0, width: 420, height: 24)

        let alert = NSAlert()
        alert.messageText = "Cosense拡張辞書"
        alert.informativeText = "dictionaryページを持つプロジェクトURLを入力"
        alert.accessoryView = input
        alert.addButton(withTitle: "設定")
        alert.addButton(withTitle: "キャンセル")
        alert.window.level = .floating

        guard runModalAlert(
            alert,
            firstResponder: input
        ) == .alertFirstButtonReturn else {
            return
        }

        guard
            let url = URL(string: input.stringValue),
            let configuration = CosenseProjectConfiguration(projectURL: url)
        else {
            showInvalidProjectURLAlert()
            return
        }

        dictionarySource = configuration.dictionarySource
        cosenseCredential = credentialStore.load(
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
        let kindPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        kindPopup.addItems(
            withTitles: [
                "Personal Access Token",
                "Service Account"
            ]
        )
        if cosenseCredential?.kind == .serviceAccount {
            kindPopup.selectItem(at: 1)
        }

        let tokenInput = NSSecureTextField(frame: .zero)
        tokenInput.placeholderString = "トークンまたはアクセスキー"
        tokenInput.frame.size.width = 420
        authenticationTokenInput = tokenInput

        let pasteButton = NSButton(
            title: "クリップボードから貼り付け",
            target: self,
            action: #selector(pasteCosenseCredential(_:))
        )
        let stack = NSStackView(views: [kindPopup, tokenInput, pasteButton])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 8
        stack.frame = NSRect(x: 0, y: 0, width: 420, height: 92)

        let alert = NSAlert()
        alert.messageText = "Cosense認証"
        alert.informativeText =
            "Service Accountは現在のプロジェクトだけに使用"
        alert.accessoryView = stack
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "削除")
        alert.addButton(withTitle: "キャンセル")
        alert.window.level = .floating

        let response = runModalAlert(
            alert,
            firstResponder: tokenInput
        )
        let kind: CosenseCredential.Kind =
            kindPopup.indexOfSelectedItem == 1
                ? .serviceAccount
                : .personalAccessToken

        do {
            if response == .alertFirstButtonReturn {
                guard let credential = CosenseCredential(
                    kind: kind,
                    value: tokenInput.stringValue
                ) else {
                    NSSound.beep()
                    return
                }
                try credentialStore.save(
                    credential,
                    project: dictionarySource.project
                )
            } else if response == .alertSecondButtonReturn {
                try credentialStore.delete(
                    kind: kind,
                    project: dictionarySource.project
                )
            } else {
                return
            }

            cosenseCredential = credentialStore.load(
                for: dictionarySource.project
            )
            cosenseSyncStatus = "未実行"
            syncCosenseDictionary(nil)
        } catch {
            NSLog(
                "Cosense認証情報の保存に失敗: %@",
                error.localizedDescription
            )
            NSSound.beep()
        }
    }

    @objc
    private func pasteCosenseCredential(_ sender: Any?) {
        guard
            let value = NSPasteboard.general.string(forType: .string),
            !value.isEmpty
        else {
            NSSound.beep()
            return
        }
        authenticationTokenInput?.stringValue = value
        authenticationTokenInput?.window?.makeFirstResponder(
            authenticationTokenInput
        )
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
    private func toggleSemanticSuggestions(_ sender: Any?) {
        UserDefaults.standard.set(
            !isSemanticSuggestionsEnabled,
            forKey: Self.semanticSuggestionsEnabledDefaultsKey
        )
        suggestionSearchSession.cancel(.semantic)
        guard !inputBuffer.isEmpty, let inputClient = client() else {
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
        let dateField = NSTextField(string: dateCandidateFormats.joined(separator: ", "))
        let timeField = NSTextField(string: timeCandidateFormats.joined(separator: ", "))
        let dateTimeField = NSTextField(string: dateTimeCandidateFormats.joined(separator: ", "))
        for field in [dateField, timeField, dateTimeField] {
            field.frame.size.width = 480
        }
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "日付書式  カンマ区切り"),
            dateField,
            NSTextField(labelWithString: "時刻書式  カンマ区切り"),
            timeField,
            NSTextField(labelWithString: "日時書式  カンマ区切り"),
            dateTimeField,
            NSTextField(labelWithString: "使用可能: YYYY YY MM M DD D HH H mm m ss s")
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.frame = NSRect(x: 0, y: 0, width: 480, height: 178)

        let alert = NSAlert()
        alert.messageText = "日時候補の書式"
        alert.accessoryView = stack
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "キャンセル")
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
            return
        }

        UserDefaults.standard.set(
            Self.parseCandidateFormats(dateField.stringValue),
            forKey: Self.dateCandidateFormatsDefaultsKey
        )
        UserDefaults.standard.set(
            Self.parseCandidateFormats(timeField.stringValue),
            forKey: Self.timeCandidateFormatsDefaultsKey
        )
        UserDefaults.standard.set(
            Self.parseCandidateFormats(dateTimeField.stringValue),
            forKey: Self.dateTimeCandidateFormatsDefaultsKey
        )
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            return
        }
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleBasicDictionary(_ sender: Any?) {
        toggleCandidateSource(
            defaultsKey: Self.basicDictionaryEnabledDefaultsKey,
            currentlyEnabled: isBasicDictionaryEnabled
        )
    }

    @objc
    private func toggleUserDictionary(_ sender: Any?) {
        toggleCandidateSource(
            defaultsKey: Self.userDictionaryEnabledDefaultsKey,
            currentlyEnabled: isUserDictionaryEnabled
        )
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
    private func toggleAzureDictionary(_ sender: Any?) {
        UserDefaults.standard.set(
            !isAzureDictionaryEnabled,
            forKey: Self.azureDictionaryEnabledDefaultsKey
        )
        resetOfficialCandidates()
        guard !inputBuffer.isEmpty, let inputClient = client() else { return }
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleWebSearch(_ sender: Any?) {
        UserDefaults.standard.set(!isWebSearchEnabled, forKey: Self.webSearchEnabledDefaultsKey)
    }

    @objc
    private func configureExternalCandidates(_ sender: Any?) {
        let searchTemplate = NSTextField(string: webSearchTemplate)
        searchTemplate.placeholderString = SearchURLTemplate.defaultValue
        let azureKey = NSSecureTextField(string: azureDictionaryKey)
        azureKey.placeholderString = "Azure Translator APIキー"
        let azureRegion = NSTextField(string: azureDictionaryRegion)
        azureRegion.placeholderString = "japaneast など  グローバルキーでは空欄"
        for field in [searchTemplate, azureKey, azureRegion] {
            field.frame.size.width = 480
        }
        let stack = NSStackView(views: [
            NSTextField(labelWithString: "Web検索URL  %sを検索語へ置換"),
            searchTemplate,
            NSTextField(labelWithString: "Azure Translator APIキー"),
            azureKey,
            NSTextField(labelWithString: "Azureリージョン"),
            azureRegion
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.frame = NSRect(x: 0, y: 0, width: 480, height: 142)
        let alert = NSAlert()
        alert.messageText = "外部候補とWeb検索"
        alert.accessoryView = stack
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "キャンセル")
        alert.window.level = .floating
        guard runModalAlert(alert, firstResponder: searchTemplate) == .alertFirstButtonReturn else {
            return
        }
        guard (try? SearchURLTemplate(searchTemplate.stringValue)) != nil else {
            NSSound.beep()
            return
        }
        UserDefaults.standard.set(searchTemplate.stringValue, forKey: Self.webSearchTemplateDefaultsKey)
        do {
            try externalCredentialStore.saveAzureTranslatorKey(azureKey.stringValue)
        } catch {
            NSSound.beep()
            return
        }
        UserDefaults.standard.set(azureRegion.stringValue, forKey: Self.azureDictionaryRegionDefaultsKey)
        resetOfficialCandidates()
        if !inputBuffer.isEmpty, let inputClient = client() {
            refreshCandidates(client: inputClient)
        }
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
        let templateField = NSTextField(
            string: externalInformationURLTemplate
        )
        templateField.placeholderString =
            "https://ja.wikipedia.org/w/index.php?search=%s"
        templateField.frame.size.width = 520

        let delayPopup = NSPopUpButton(frame: .zero, pullsDown: false)
        let delayOptions: [(String, TimeInterval)] = [
            ("すぐ表示", 0),
            ("0.5秒後", 0.5),
            ("1秒後", 1),
            ("2秒後", 2),
            ("3秒後", 3),
            ("5秒後", 5)
        ]
        delayPopup.addItems(withTitles: delayOptions.map(\.0))
        let selectedDelayIndex = delayOptions.firstIndex {
            $0.1 == externalInformationDisplayDelay
        } ?? 2
        delayPopup.selectItem(at: selectedDelayIndex)

        let stack = NSStackView(views: [
            NSTextField(labelWithString: "検索語を挿入する位置を%sで指定"),
            templateField,
            NSTextField(labelWithString: "表示タイミング"),
            delayPopup
        ])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        stack.frame = NSRect(x: 0, y: 0, width: 520, height: 96)

        let alert = NSAlert()
        alert.messageText = "外部情報パネルの検索先"
        alert.accessoryView = stack
        alert.addButton(withTitle: "保存")
        alert.addButton(withTitle: "キャンセル")
        alert.window.level = .floating

        guard runModalAlert(
            alert,
            firstResponder: templateField
        ) == .alertFirstButtonReturn else {
            return
        }
        guard
            let template = try? SearchURLTemplate(templateField.stringValue),
            (try? template.url(for: "test")) != nil
        else {
            NSSound.beep()
            return
        }
        UserDefaults.standard.set(
            templateField.stringValue,
            forKey: Self.externalInformationURLTemplateDefaultsKey
        )
        UserDefaults.standard.set(
            delayOptions[delayPopup.indexOfSelectedItem].1,
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
        Task { @MainActor [weak self] in
            do {
                let snapshot = try await TKGDictionaryClient().fetch()
                let cache = try Self.basicDictionaryCache()
                let currentRevision = try cache.loadMetadata()?.sourceRevision
                    ?? Self.bundledBasicDictionaryRevision()

                guard currentRevision.map({
                    snapshot.generatedAt > $0
                }) ?? true else {
                    if let self, basicEntries.isEmpty {
                        basicEntries = snapshot.entries
                        rebuildConversionEngine()
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
                rebuildConversionEngine()
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

    private func handleSpace(client sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }
        if let selectedValue = selectedCandidateValue {
            recordSelectedCandidate()
            commit(selectedValue + conversionSuffix + " ", to: sender)
        } else {
            commit(inputBuffer + " ", to: sender)
        }
        return true
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
        candidatePanel.hide()
        candidateWindow.hide()
        fuzzySuggestionWindow.hide()
        previewWindow.hide()
        setMarkedText(
            (tabDictionaryRegistration?.confirmedCandidate ?? "") + candidate,
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
        if inputBuffer.isEmpty {
            guard !nextInputCandidates.isEmpty else {
                return false
            }
            let offset = event.modifierFlags.contains(.shift) ? -1 : 1
            return selectNextInputCandidate(offset: offset, client: sender)
        }

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

    private func beginTabDictionaryRegistration(client sender: Any) -> Bool {
        tabDictionaryRegistration = TabDictionaryRegistration(
            originalInput: inputBuffer,
            reading: conversionReading.lowercased()
        )
        inputBuffer = ""
        currentCandidates = []
        candidatePanel.hide()
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
            currentCandidates = []
            selectedCandidateIndex = nil
            setMarkedText(registration.confirmedCandidate ?? "", in: sender)
            showTabDictionaryRegistration(client: sender)
            return true
        case 48:
            return handleTab(event, client: sender)
        case 123:
            return moveCandidate(.left, client: sender)
        case 124:
            return moveCandidate(.right, client: sender)
        case 125:
            return moveCandidate(.down, client: sender)
        case 126:
            return moveCandidate(.up, client: sender)
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
            currentCandidates = []
            selectedCandidateIndex = nil
            updateMarkedText(in: sender)
            refreshCandidates(client: sender)
            return true
        default:
            break
        }

        if isUserDictionaryRegistrationShortcut(event) {
            let pasted = NSPasteboard.general.string(forType: .string)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            guard !pasted.isEmpty else {
                NSSound.beep()
                return true
            }
            registration.pastedCandidate = pasted
            tabDictionaryRegistration = registration
            inputBuffer = ""
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
            currentCandidates = []
            selectedCandidateIndex = nil
        }
        registration.pastedCandidate = nil
        tabDictionaryRegistration = registration
        inputBuffer += characters
        selectedCandidateIndex = nil
        setMarkedText(
            (registration.confirmedCandidate ?? "") + inputBuffer,
            in: sender
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
                    "登録: \(confirmedCandidate)",
                    "登録する語句を入力中…",
                    "候補を続けて入力 / Returnで辞書登録を確定"
                ],
                selectedIndex: nil,
                near: inputLocation(for: sender),
                guide: "↩ 登録を確定　Esc 中止"
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
                candidateDisplay,
                "登録する語句を入力中…",
                "Returnで現在の入力を追加 / Escで中止"
            ],
            selectedIndex: nil,
            near: inputLocation(for: sender),
            guide: "↩ 入力を追加　⌘V 貼付　Esc 中止"
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
            .confirmedCandidate ?? ""
        setMarkedText(
            registrationPrefix + currentCandidates[index] + conversionSuffix,
            in: sender
        )
        showPreview(for: currentCandidates[index])
        return true
    }

    private func refreshCandidates(client sender: Any) {
        cancelFuzzySuggestionSearch()
        if suggestionSearchSession.query(for: .semantic)
            != conversionReading {
            suggestionSearchSession.cancel(.semantic)
        }
        fuzzySuggestionWindow.hide()
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
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
        let userCandidates = isUserDictionaryEnabled
            ? mergedCandidateGroups(
                lookup: { userConversionEngine.candidateGroups(matching: $0) },
                readings: lookupReadings
            )
            : DictionaryCandidateGroups()
        let extensionCandidates = isExtensionDictionaryEnabled
            ? mergedCandidateGroups(
                lookup: {
                    extensionConversionEngine.candidateGroups(matching: $0)
                },
                readings: lookupReadings
            )
            : DictionaryCandidateGroups()
        let basicCandidates = isBasicDictionaryEnabled
            ? mergedCandidateGroups(
                lookup: { basicConversionEngine.candidateGroups(matching: $0) },
                readings: lookupReadings
            )
            : DictionaryCandidateGroups()
        let kanaLookupReadings = lookupReadings.compactMap {
            romajiConverter.hiragana(from: $0)
        }
        let imeCandidates = isBasicDictionaryEnabled
            ? mergedCandidateGroups(
                lookup: {
                    imeConversionEngine.candidateGroups(
                    matching: $0,
                    limit: Self.maximumIMEDictionaryPrefixCandidates
                    )
                },
                readings: kanaLookupReadings
            )
            : DictionaryCandidateGroups()
        let supplementalCandidates = isBasicDictionaryEnabled
            ? mergedCandidateGroups(
                lookup: {
                    supplementalConversionEngine.candidateGroups(matching: $0)
                },
                readings: lookupReadings
            )
            : DictionaryCandidateGroups()
        let englishCandidates = isEnglishCompletionEnabled
            ? englishCompletions(for: conversionReading)
            : []
        let remoteCandidates = suggestionSearchSession.query(for: .official)
            == conversionReading
            ? officialCandidates
            : []
        let inflectionCandidates = isBasicDictionaryEnabled
            ? mergedCandidates(
            lookup: {
                verbInflectionGenerator.candidates(for: $0)
                    + VerbInflectionCandidateGenerator.candidates(for: $0) {
                        imeConversionEngine.candidates(for: $0)
                    }
            },
            readings: lookupReadings
        ) : []
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
        currentCandidates = CandidatePipeline().candidates(
            from: CandidatePipeline.Input(
                kana: kanaCandidates,
                direct: directCandidates,
                other: otherCandidates,
                recencyRanks: candidateSelectionHistory.ranks,
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
        let hasDirectExactCandidates = !userCandidates.exact.isEmpty
                || !extensionCandidates.exact.isEmpty
                || !dateTimeCandidates.isEmpty
                || !imeCandidates.exact.isEmpty
                || !basicCandidates.exact.isEmpty
        let auxiliaryAnchorFrame = candidateAndInputFrame(for: sender)
        updateFuzzySuggestionsIfNeeded(
            hasDirectExactCandidates: hasDirectExactCandidates,
            near: auxiliaryAnchorFrame
        )
        updateSemanticSuggestionsIfNeeded(
            hasDirectExactCandidates: hasDirectExactCandidates,
            near: auxiliaryAnchorFrame
        )
        showInputPreview(client: sender)
    }

    private func updateFuzzySuggestionsIfNeeded(
        hasDirectExactCandidates: Bool,
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
        let engine = fuzzyConversionEngine
        let visibleCandidates = Set(currentCandidates)
        let normalizedInput = RomanizedReadingNormalizer.dictionaryReading(
            from: query
        )
        let token = suggestionSearchSession.begin(.fuzzy, query: query)
        let task = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(80))
                let matches = await Task.detached(priority: .userInitiated) {
                    FuzzyConversionMatchFilter.filtered(
                        engine.matches(for: query, limit: 3),
                        excluding: visibleCandidates,
                        hasDirectExactCandidates: hasDirectExactCandidates,
                        normalizedInput: normalizedInput
                    )
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
                NSLog("曖昧検索に失敗: %@", error.localizedDescription)
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
        let semanticSuggestions = fuzzySuggestions.filter {
            $0.kind == .semantic
        }
        fuzzySuggestions = spellingSuggestions + semanticSuggestions
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

    private func updateSemanticSuggestionsIfNeeded(
        hasDirectExactCandidates: Bool,
        near anchorFrame: NSRect
    ) {
        guard isSemanticSuggestionsEnabled,
              !hasDirectExactCandidates,
              conversionReading.count >= 2,
              suggestionSearchSession.query(for: .semantic)
                != conversionReading else {
            return
        }
        let query = conversionReading
        let japaneseQuery = romajiConverter.hiragana(from: query) ?? query
        let excludedCandidates = Set(currentCandidates)
        let token = suggestionSearchSession.begin(.semantic, query: query)
        let task = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(350))
                guard let self else { return }
                guard let semanticQuery = await semanticSearchQuery(
                    japaneseInput: japaneseQuery
                ) else {
                    return
                }
                let matches = await semanticVectorSearchEngine.matches(
                    for: semanticQuery,
                    sourceReading: query,
                    excluding: excludedCandidates,
                    limit: 3
                )
                try Task.checkCancellation()
                guard suggestionSearchSession.isCurrent(token),
                      conversionReading == query,
                      isSemanticSuggestionsEnabled,
                      !matches.isEmpty else {
                    return
                }
                let semanticSuggestions = matches.map {
                    FuzzySuggestion(
                        candidate: $0.candidate,
                        reading: $0.reading,
                        distance: 0,
                        kind: .semantic
                    )
                }
                let semanticCandidates = Set(
                    semanticSuggestions.map(\.candidate)
                )
                let spellingSuggestions = fuzzySuggestions.filter {
                    $0.kind == .spelling
                        && !semanticCandidates.contains($0.candidate)
                }
                fuzzySuggestions = spellingSuggestions + semanticSuggestions
                selectedFuzzySuggestionIndex = nil
                fuzzySuggestionWindow.show(
                    suggestions: fuzzySuggestions,
                    selectedIndex: nil,
                    near: anchorFrame
                )
            } catch is CancellationError {
                return
            } catch {
                NSLog("意味検索に失敗: %@", error.localizedDescription)
            }
        }
        suggestionSearchSession.attach(task, to: token)
    }

    @MainActor
    private func semanticSearchQuery(japaneseInput: String) async -> String? {
#if canImport(Translation)
        if #available(macOS 15.0, *) {
            let provider: AppleTranslationCandidateProvider
            if let existing = semanticTranslationProvider
                as? AppleTranslationCandidateProvider {
                provider = existing
            } else {
                provider = AppleTranslationCandidateProvider()
                semanticTranslationProvider = provider
            }
            return await provider.translateJapaneseToEnglish(japaneseInput)
        }
#endif
        return nil
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
        guard isWikipediaSuggestionsEnabled || isAppleTranslationEnabled || azureDictionaryIsReady,
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
                async let azure: [String] = azureDictionaryIsReady
                    ? (try? await AzureDictionaryClient(
                        key: azureDictionaryKey,
                        region: azureDictionaryRegion.isEmpty ? nil : azureDictionaryRegion
                      ).translations(for: japaneseInput)) ?? []
                    : []
                let apple = await appleTranslationCandidate(for: japaneseInput)
                let suggestions = await wikipedia + apple + azure
                try Task.checkCancellation()
                guard suggestionSearchSession.isCurrent(token),
                      isWikipediaSuggestionsEnabled || isAppleTranslationEnabled || azureDictionaryIsReady,
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

    private func appleTranslationCandidate(for text: String) async -> [String] {
        guard isAppleTranslationEnabled else { return [] }
#if canImport(Translation)
        if #available(macOS 15.0, *) {
            let provider = await MainActor.run {
                AppleTranslationCandidateProvider()
            }
            if let value = await provider.translateJapaneseToEnglish(text),
               !value.isEmpty {
                return [value]
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

    private func registerClipboardInUserDictionary(client sender: Any) -> Bool {
        let reading = conversionReading.lowercased()
        let candidate = NSPasteboard.general.string(
            forType: .string
        )?
        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !reading.isEmpty, !candidate.isEmpty else {
            NSSound.beep()
            return false
        }

        do {
            try saveUserDictionaryEntry(
                reading: reading,
                candidate: candidate
            )
            clearCompositionForSystemPaste(in: sender)
            return true
        } catch {
            NSLog(
                "ユーザー辞書の保存に失敗: %@",
                error.localizedDescription
            )
            NSSound.beep()
            return false
        }
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
        let normalizedReading =
            RomanizedReadingNormalizer.dictionaryReading(
                from: conversionReading
            )
        let lookupReadings =
            RomanizedReadingNormalizer.dictionaryLookupReadings(
                from: normalizedReading
            )
        let updatedEntries = UserDictionaryEditor.removing(
            candidate: candidate,
            matchingReadings: lookupReadings,
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
        tabDictionaryRegistration = nil
        currentCandidates = []
        selectedCandidateIndex = nil
        suggestionSearchSession.cancelAll()
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
        candidatePanel.hide()
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

    private func isUserDictionaryRegistrationShortcut(
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

        candidateWindow.show(
            candidates: currentCandidates[pageStart..<pageEnd].map {
                candidateValueForCommit($0)
            },
            selectedIndex: selectedCandidateIndex.map { $0 - pageStart },
            near: inputLocation(for: sender),
            guide: selectedCandidateIndex == nil
                ? "Tab 選択　⇧Tab もしかして？　⌥↩ 辞書登録\nF6–F10 文字種変換　⌘O 外部ページ"
                : "Tab / ⇧Tab / 矢印 移動　↩ 確定　Esc 解除\n⌘X 削除　⌘↩ Web検索　⌘O 外部ページ"
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
            return false
        }

        inputBuffer = InputBufferDeletion.deletingBackward(
            from: inputBuffer,
            unit: unit
        )
        selectedCandidateIndex = nil
        candidatePanel.hide()
        previewWindow.hide()
        setMarkedText(
            (tabDictionaryRegistration?.confirmedCandidate ?? "")
                + inputBuffer,
            in: sender
        )
        refreshCandidates(client: sender)
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

        selectedCandidateIndex = nil
        candidateWindow.clearSelection()
        updateMarkedText(in: sender)
        showInputPreview(client: sender)
        return true
    }

    private func commit(
        _ value: String,
        to sender: Any,
        replacingMarkedText: Bool = false
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
        tabDictionaryRegistration = nil
        currentCandidates = []
        selectedCandidateIndex = nil
        fuzzySuggestions = []
        selectedFuzzySuggestionIndex = nil
        candidatePanel.hide()
        candidateWindow.hide()
        fuzzySuggestionWindow.hide()
        previewWindow.hide()
        recordCommittedInput(value, client: sender)
    }

    private func resetTransientInteractionState() {
        candidatePanel.hide()
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
        suggestionSearchSession.cancel(.semantic)
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
            guide: "Tab / ⇧Tab / 矢印 選択　↩ 確定\nSpace 維持　文字入力で確定"
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
        candidatePanel.hide()
        candidateWindow.hide()
        previewWindow.hide()
    }

    private func updateMarkedText(in sender: Any) {
        setMarkedText(inputBuffer, in: sender)
    }

    private func setMarkedText(_ value: String, in sender: Any) {
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
            selectionRange: NSRange(location: value.utf16.count, length: 0),
            replacementRange: replacementRange
        )
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

    private func rebuildConversionEngine() {
        userConversionEngine = ConversionEngine(entries: userEntries)
        extensionConversionEngine = ConversionEngine(
            entries: extensionEntries
        )
        basicConversionEngine = ConversionEngine(entries: basicEntries)
        verbInflectionGenerator = VerbInflectionCandidateGenerator(
            entries: basicEntries
        )
        rebuildFuzzyConversionEngine()
    }

    private func rebuildFuzzyConversionEngine() {
        cancelFuzzySuggestionSearch()
        fuzzyConversionEngine = FuzzyConversionEngine(
            entries: (isUserDictionaryEnabled ? userEntries : [])
                + (isExtensionDictionaryEnabled ? extensionEntries : [])
                + (isBasicDictionaryEnabled ? basicEntries : [])
                + SupplementalDictionary.entries
        )
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
        if !JapaneseNumberConverter.candidates(for: inputBuffer).isEmpty
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

    private var isBasicDictionaryEnabled: Bool {
        experimentalFeatureIsEnabled(
            defaultsKey: Self.basicDictionaryEnabledDefaultsKey
        )
    }

    private var isUserDictionaryEnabled: Bool {
        experimentalFeatureIsEnabled(
            defaultsKey: Self.userDictionaryEnabledDefaultsKey
        )
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

    private var isAzureDictionaryEnabled: Bool {
        if UserDefaults.standard.object(
            forKey: Self.azureDictionaryEnabledDefaultsKey
        ) == nil {
            return false
        }
        return UserDefaults.standard.bool(
            forKey: Self.azureDictionaryEnabledDefaultsKey
        )
    }

    private var azureDictionaryKey: String {
        externalCredentialStore.loadAzureTranslatorKey()
    }

    private var azureDictionaryRegion: String {
        UserDefaults.standard.string(forKey: Self.azureDictionaryRegionDefaultsKey) ?? ""
    }

    private var azureDictionaryIsReady: Bool {
        isAzureDictionaryEnabled && !azureDictionaryKey.isEmpty
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

    private var isSemanticSuggestionsEnabled: Bool {
        UserDefaults.standard.bool(
            forKey: Self.semanticSuggestionsEnabledDefaultsKey
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

    private static func parseCandidateFormats(_ value: String) -> [String] {
        var seen = Set<String>()
        return value.split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0).inserted }
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

    private func showInvalidProjectURLAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "URLを設定できません"
        alert.informativeText = "https://scrapbox.io/project-name の形式で入力"
        alert.addButton(withTitle: "OK")
        alert.window.level = .floating
        alert.runModal()
    }

    private func runModalAlert(
        _ alert: NSAlert,
        firstResponder: NSView
    ) -> NSApplication.ModalResponse {
        let previousPolicy = NSApp.activationPolicy()
        let changedPolicy = previousPolicy == .prohibited
            && NSApp.setActivationPolicy(.accessory)

        alert.window.initialFirstResponder = firstResponder
        NSRunningApplication.current.activate(
            options: [.activateIgnoringOtherApps, .activateAllWindows]
        )
        NSApp.activate(ignoringOtherApps: true)
        alert.window.makeKeyAndOrderFront(nil)
        alert.window.makeFirstResponder(firstResponder)
        let pasteMonitor = NSEvent.addLocalMonitorForEvents(
            matching: .keyDown
        ) { event in
            guard
                event.keyCode == 9,
                event.modifierFlags.contains(.command),
                let textField = firstResponder as? NSTextField,
                let value = NSPasteboard.general.string(forType: .string)
            else {
                return event
            }

            if let editor = textField.currentEditor() as? NSTextView {
                editor.insertText(
                    value,
                    replacementRange: editor.selectedRange()
                )
            } else {
                textField.stringValue = value
            }
            return nil
        }
        DispatchQueue.main.async {
            alert.window.makeKey()
            alert.window.makeFirstResponder(firstResponder)
        }

        let response = alert.runModal()
        if let pasteMonitor {
            NSEvent.removeMonitor(pasteMonitor)
        }
        if changedPolicy {
            NSApp.setActivationPolicy(previousPolicy)
        }
        return response
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
