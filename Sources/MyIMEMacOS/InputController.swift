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
    private static let googleSuggestionsEnabledDefaultsKey =
        "GoogleSuggestionsEnabled"
    private static let googleSearchEnabledDefaultsKey =
        "GoogleSearchEnabled"
    private static let cosensePreviewEnabledDefaultsKey =
        "CosensePreviewEnabled"
    private static let systemDictionaryPreviewEnabledDefaultsKey =
        "SystemDictionaryPreviewEnabled"
    private static let maximumCandidateCount = 7
    private static let nextInputDismissInterval: TimeInterval = 5

    private var inputBuffer = ""
    private var activatedAt: TimeInterval?
    private var currentCandidates: [String] = []
    private var selectedCandidateIndex: Int?
    private var dictionarySource: CosenseDictionarySource
    private var userEntries: [DictionaryEntry]
    private var basicEntries: [DictionaryEntry]
    private var extensionEntries: [DictionaryEntry]
    private var userConversionEngine: ConversionEngine
    private var extensionConversionEngine: ConversionEngine
    private var basicConversionEngine: ConversionEngine
    private var verbInflectionGenerator: VerbInflectionCandidateGenerator
    private let credentialStore: CosenseCredentialStore
    private var cosenseCredential: CosenseCredential?
    private var candidateSelectionRanks: [String: Int]
    private var nextCandidateSelectionRank: Int
    private var nextInputPredictionModel: NextInputPredictionModel
    private var nextInputCandidates: [String] = []
    private var selectedNextInputIndex: Int?
    private var nextInputDismissTimer: Timer?
    private var googleSuggestionTask: Task<Void, Never>?
    private var googleSuggestionQuery = ""
    private var googleSuggestionCandidates: [String] = []
    private var tabDictionaryRegistration: TabDictionaryRegistration?
    private var cosenseSyncStatus = "未実行"
    private var basicDictionaryStatus = "未確認"
    private let candidatePanel: IMKCandidates
    private let candidateWindow = CandidateWindowController()
    private let previewWindow = CosensePreviewWindowController()
    private let cosenseLoginWindow = CosenseLoginWindowController()
    private let definitionProvider = SystemDictionaryDefinitionProvider()
    private let romajiConverter = RomajiConverter()
    private weak var authenticationTokenInput: NSSecureTextField?

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let source = Self.loadDictionarySource()
        let credentialStore = CosenseCredentialStore()
        let cachedUserEntries = Self.loadUserEntries()
        let bundledEntries = Self.loadBasicEntries()
        let cachedExtensionEntries = Self.loadExtensionEntries(for: source)
        let selectionRanks = Self.loadCandidateSelectionRanks()
        let nextInputModel = Self.loadNextInputPredictionModel()

        dictionarySource = source
        self.credentialStore = credentialStore
        cosenseCredential = credentialStore.load(for: source.project)
        userEntries = cachedUserEntries
        basicEntries = bundledEntries
        extensionEntries = cachedExtensionEntries
        candidateSelectionRanks = selectionRanks
        nextCandidateSelectionRank = (selectionRanks.values.max() ?? 0) + 1
        nextInputPredictionModel = nextInputModel
        userConversionEngine = ConversionEngine(entries: cachedUserEntries)
        extensionConversionEngine = ConversionEngine(
            entries: cachedExtensionEntries
        )
        basicConversionEngine = ConversionEngine(entries: bundledEntries)
        verbInflectionGenerator = VerbInflectionCandidateGenerator(
            entries: bundledEntries
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
            : "読込済み（\(bundledEntries.count)読み）"
        updateBasicDictionaryIfNeeded(nil)
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let sender else {
            return false
        }

        guard event.type == .keyDown else {
            return false
        }

        if tabDictionaryRegistration != nil {
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

        if isGoogleSearchShortcut(event),
           openSelectedGoogleSearch(client: sender) {
            return true
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
            return deleteBackward(from: sender)
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

    override func menu() -> NSMenu! {
        let menu = NSMenu()
        let syncItem = NSMenuItem(
            title: "Cosense辞書を更新",
            action: #selector(syncCosenseDictionary(_:)),
            keyEquivalent: "r"
        )
        syncItem.keyEquivalentModifierMask = [.command, .option, .control]
        syncItem.target = self
        menu.addItem(syncItem)

        let configureItem = NSMenuItem(
            title: "Cosenseプロジェクトを設定…",
            action: #selector(configureCosenseProject(_:)),
            keyEquivalent: ""
        )
        configureItem.target = self
        menu.addItem(configureItem)

        let loginItem = NSMenuItem(
            title: "Cosenseへログイン…",
            action: #selector(openCosenseLogin(_:)),
            keyEquivalent: ""
        )
        loginItem.target = self
        menu.addItem(loginItem)

        let authenticationItem = NSMenuItem(
            title: "Cosense認証を設定…",
            action: #selector(configureCosenseAuthentication(_:)),
            keyEquivalent: ""
        )
        authenticationItem.target = self
        menu.addItem(authenticationItem)

        let updateBasicItem = NSMenuItem(
            title: "TKGJE基本辞書を更新",
            action: #selector(updateBasicDictionaryIfNeeded(_:)),
            keyEquivalent: ""
        )
        updateBasicItem.target = self
        menu.addItem(updateBasicItem)

        menu.addItem(.separator())

        let experimentalItem = NSMenuItem(
            title: "実験機能",
            action: nil,
            keyEquivalent: ""
        )
        experimentalItem.isEnabled = false
        menu.addItem(experimentalItem)

        addExperimentalToggle(
            title: "TKGJE基本辞書を使用",
            action: #selector(toggleBasicDictionary(_:)),
            enabled: isBasicDictionaryEnabled,
            to: menu
        )
        addExperimentalToggle(
            title: "ローカルユーザー辞書を使用",
            action: #selector(toggleUserDictionary(_:)),
            enabled: isUserDictionaryEnabled,
            to: menu
        )
        addExperimentalToggle(
            title: "Cosense拡張辞書を使用",
            action: #selector(toggleExtensionDictionary(_:)),
            enabled: isExtensionDictionaryEnabled,
            to: menu
        )
        addExperimentalToggle(
            title: "英語補完を使用",
            action: #selector(toggleEnglishCompletion(_:)),
            enabled: isEnglishCompletionEnabled,
            to: menu
        )
        addExperimentalToggle(
            title: "Google検索候補を取得",
            action: #selector(toggleGoogleSuggestions(_:)),
            enabled: isGoogleSuggestionsEnabled,
            to: menu
        )
        addExperimentalToggle(
            title: "Google検索を使用",
            action: #selector(toggleGoogleSearch(_:)),
            enabled: isGoogleSearchEnabled,
            to: menu
        )
        menu.addItem(.separator())

        let nextInputItem = NSMenuItem(
            title: "次入力候補を使用",
            action: #selector(toggleNextInputPrediction(_:)),
            keyEquivalent: ""
        )
        nextInputItem.target = self
        nextInputItem.state = isNextInputPredictionEnabled ? .on : .off
        menu.addItem(nextInputItem)

        let cosensePreviewItem = NSMenuItem(
            title: "Cosenseパネルを使用",
            action: #selector(toggleCosensePreview(_:)),
            keyEquivalent: ""
        )
        cosensePreviewItem.target = self
        cosensePreviewItem.state = isCosensePreviewEnabled ? .on : .off
        menu.addItem(cosensePreviewItem)

        let systemDictionaryPreviewItem = NSMenuItem(
            title: "macOS辞書パネルを使用",
            action: #selector(toggleSystemDictionaryPreview(_:)),
            keyEquivalent: ""
        )
        systemDictionaryPreviewItem.target = self
        systemDictionaryPreviewItem.state = isSystemDictionaryPreviewEnabled
            ? .on : .off
        menu.addItem(systemDictionaryPreviewItem)

        let clearNextInputItem = NSMenuItem(
            title: "次入力履歴を削除",
            action: #selector(clearNextInputPredictionHistory(_:)),
            keyEquivalent: ""
        )
        clearNextInputItem.target = self
        menu.addItem(clearNextInputItem)

        let registerSelectionItem = NSMenuItem(
            title: "選択文字列を辞書登録…",
            action: #selector(registerSelectedTextInUserDictionary(_:)),
            keyEquivalent: ""
        )
        registerSelectionItem.target = self
        menu.addItem(registerSelectionItem)

        let userDictionaryItem = NSMenuItem(
            title: "ユーザー辞書: \(userEntries.count)読み",
            action: nil,
            keyEquivalent: ""
        )
        userDictionaryItem.isEnabled = false
        menu.addItem(userDictionaryItem)

        let projectItem = NSMenuItem(
            title: "拡張辞書: \(dictionarySource.projectURLDescription)",
            action: nil,
            keyEquivalent: ""
        )
        projectItem.isEnabled = false
        menu.addItem(projectItem)

        let authenticationStatusItem = NSMenuItem(
            title: "Cosense認証: \(cosenseAuthenticationStatus)",
            action: nil,
            keyEquivalent: ""
        )
        authenticationStatusItem.isEnabled = false
        menu.addItem(authenticationStatusItem)

        let statusItem = NSMenuItem(
            title: "Cosense更新: \(cosenseSyncStatus)",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)

        let basicStatusItem = NSMenuItem(
            title: "TKGJE更新: \(basicDictionaryStatus)",
            action: nil,
            keyEquivalent: ""
        )
        basicStatusItem.isEnabled = false
        menu.addItem(basicStatusItem)
        return menu
    }

    private func addExperimentalToggle(
        title: String,
        action: Selector,
        enabled: Bool,
        to menu: NSMenu
    ) {
        let item = NSMenuItem(
            title: title,
            action: action,
            keyEquivalent: ""
        )
        item.target = self
        item.state = enabled ? .on : .off
        menu.addItem(item)
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
        if previewWindow.isCosenseInteractionActive {
            return
        }
        if !inputBuffer.isEmpty {
            commit(inputBuffer, to: sender as Any)
        }
        candidatePanel.hide()
        candidateWindow.hide()
        previewWindow.hide()
        nextInputDismissTimer?.invalidate()
        nextInputDismissTimer = nil
        googleSuggestionTask?.cancel()
        googleSuggestionTask = nil
        nextInputCandidates = []
        selectedNextInputIndex = nil
        nextInputPredictionModel.breakSequence()
        super.deactivateServer(sender)
    }

    override func inputControllerWillClose() {
        candidatePanel.hide()
        candidateWindow.hide()
        previewWindow.hide()
        nextInputDismissTimer?.invalidate()
        nextInputDismissTimer = nil
        googleSuggestionTask?.cancel()
        googleSuggestionTask = nil
        nextInputCandidates = []
        selectedNextInputIndex = nil
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
        cosenseLoginWindow.show(project: dictionarySource.project)
    }

    @objc
    private func openCosenseLogin(_ sender: Any?) {
        cosenseLoginWindow.show(project: dictionarySource.project)
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
    private func toggleGoogleSuggestions(_ sender: Any?) {
        let enabled = !isGoogleSuggestionsEnabled
        UserDefaults.standard.set(
            enabled,
            forKey: Self.googleSuggestionsEnabledDefaultsKey
        )
        if !enabled {
            googleSuggestionTask?.cancel()
            googleSuggestionTask = nil
            googleSuggestionQuery = ""
            googleSuggestionCandidates = []
        }
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            return
        }
        selectedCandidateIndex = nil
        updateMarkedText(in: inputClient)
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleGoogleSearch(_ sender: Any?) {
        UserDefaults.standard.set(
            !isGoogleSearchEnabled,
            forKey: Self.googleSearchEnabledDefaultsKey
        )
    }

    private func toggleCandidateSource(
        defaultsKey: String,
        currentlyEnabled: Bool
    ) {
        UserDefaults.standard.set(!currentlyEnabled, forKey: defaultsKey)
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            return
        }
        selectedCandidateIndex = nil
        previewWindow.hide()
        updateMarkedText(in: inputClient)
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleCosensePreview(_ sender: Any?) {
        UserDefaults.standard.set(
            !isCosensePreviewEnabled,
            forKey: Self.cosensePreviewEnabledDefaultsKey
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
            try Self.saveNextInputPredictionModel(nextInputPredictionModel)
        } catch {
            NSLog(
                "次入力履歴の削除に失敗: %@",
                error.localizedDescription
            )
            NSSound.beep()
        }
    }

    @objc
    private func registerSelectedTextInUserDictionary(_ sender: Any?) {
        let selectedText = selectedTextFromClient()
        let clipboardText = NSPasteboard.general.string(forType: .string)
            .flatMap(normalizedRegistrationCandidate)
        guard let candidate = selectedText ?? clipboardText,
              !candidate.isEmpty else {
            showMissingRegistrationCandidateAlert()
            return
        }

        let readingInput = NSTextField(frame: .zero)
        readingInput.placeholderString = "ローマ字の読み"
        readingInput.frame = NSRect(x: 0, y: 0, width: 420, height: 24)

        let alert = NSAlert()
        alert.messageText = "ユーザー辞書へ登録"
        alert.informativeText = selectedText == nil
            ? "選択文字列を取得できないためクリップボードを使用\n候補: \(candidate)"
            : "候補: \(candidate)"
        alert.accessoryView = readingInput
        alert.addButton(withTitle: "登録")
        alert.addButton(withTitle: "キャンセル")
        alert.window.level = .floating

        guard runModalAlert(
            alert,
            firstResponder: readingInput
        ) == .alertFirstButtonReturn else {
            return
        }

        let reading = readingInput.stringValue.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard isValidUserDictionaryReading(reading) else {
            NSSound.beep()
            return
        }

        do {
            try saveUserDictionaryEntry(
                reading: reading,
                candidate: candidate
            )
            if !inputBuffer.isEmpty, let inputClient = client() {
                selectedCandidateIndex = nil
                refreshCandidates(client: inputClient)
            }
        } catch {
            NSLog(
                "選択文字列の辞書登録に失敗: %@",
                error.localizedDescription
            )
            NSSound.beep()
        }
    }

    private func selectedTextFromClient() -> String? {
        guard let textClient = client() else {
            return nil
        }
        let range = textClient.selectedRange()
        guard range.location != NSNotFound, range.length > 0 else {
            return nil
        }
        guard let value = textClient.attributedSubstring(from: range)?.string
        else {
            return nil
        }
        return normalizedRegistrationCandidate(value)
    }

    private func normalizedRegistrationCandidate(
        _ value: String
    ) -> String? {
        let normalized = value.components(
            separatedBy: .whitespacesAndNewlines
        )
        .filter { !$0.isEmpty }
        .joined(separator: " ")
        return normalized.nilIfEmpty
    }

    private func isValidUserDictionaryReading(_ reading: String) -> Bool {
        !reading.isEmpty && reading.unicodeScalars.allSatisfy {
            $0.isASCII
                && (CharacterSet.letters.contains($0)
                    || $0 == "-"
                    || $0 == "'")
        }
    }

    private func showMissingRegistrationCandidateAlert() {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "登録する文字列がありません"
        alert.informativeText = "文字列を選択するかクリップボードへコピー"
        alert.addButton(withTitle: "OK")
        alert.window.level = .floating
        alert.runModal()
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
            if selectedNextInputIndex != nil {
                return selectNextInputCandidate(
                    offset: 1,
                    client: sender
                )
            }
            return false
        }
        guard !currentCandidates.isEmpty else {
            return true
        }

        let nextIndex = ((selectedCandidateIndex ?? -1) + 1)
            % currentCandidates.count
        return selectCandidate(index: nextIndex, client: sender)
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

        guard selectedCandidateIndex == nil else {
            return false
        }
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

    private func handleTabDictionaryRegistration(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool {
        guard var registration = tabDictionaryRegistration else {
            return false
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
                    commit(confirmedCandidate, to: sender)
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
            setMarkedText(registration.confirmedCandidate ?? "", in: sender)
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
            registration.pastedCandidate = nil
            tabDictionaryRegistration = registration
            return handleSpace(client: sender)
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
                confirmedCandidate.removeLast()
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
            return deleteBackward(from: sender)
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
                    "候補を続けて入力 / Returnで登録"
                ],
                selectedIndex: nil,
                near: inputLocation(for: sender)
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
                "Returnで登録 / Escで中止"
            ],
            selectedIndex: nil,
            near: inputLocation(for: sender)
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
        let symbolCandidates = JapaneseSymbolConverter.candidates(
            for: inputBuffer
        )
        if !symbolCandidates.isEmpty {
            currentCandidates = candidatesOrderedByRecency(symbolCandidates)
            showCandidateWindow(client: sender)
            return
        }

        let suggestionInput = conversionReading
        defer {
            updateGoogleSuggestionsIfNeeded(for: suggestionInput)
        }

        let normalizedReading = RomanizedReadingNormalizer.dictionaryReading(
            from: conversionReading
        )
        let lookupReadings =
            RomanizedReadingNormalizer.dictionaryLookupReadings(
                from: normalizedReading
            )
        let userCandidates = isUserDictionaryEnabled ? mergedCandidates(
            lookup: {
                userConversionEngine.candidates(
                    matching: $0,
                    limit: .max
                )
            },
            readings: lookupReadings
        ) : []
        let extensionCandidates = isExtensionDictionaryEnabled
            ? mergedCandidates(
            lookup: {
                extensionConversionEngine.candidates(
                    matching: $0,
                    limit: .max
                )
            },
            readings: lookupReadings
        ) : []
        let basicCandidates = isBasicDictionaryEnabled ? mergedCandidates(
            lookup: {
                basicConversionEngine.candidates(
                    matching: $0,
                    limit: .max
                )
            },
            readings: lookupReadings
        ) : []
        let basicExactCandidates = isBasicDictionaryEnabled
            ? mergedCandidates(
            lookup: {
                basicConversionEngine.candidates(for: $0)
            },
            readings: lookupReadings
        ) : []
        let basicPrefixCandidates = basicCandidates.filter {
            !basicExactCandidates.contains($0)
        }
        let englishCandidates = isEnglishCompletionEnabled
            ? englishCompletions(for: conversionReading)
            : []
        let googleCandidates = isGoogleSuggestionsEnabled
            && googleSuggestionQuery == conversionReading
            ? googleSuggestionCandidates
            : []
        let inflectionCandidates = isBasicDictionaryEnabled
            ? mergedCandidates(
            lookup: {
                verbInflectionGenerator.candidates(for: $0)
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
        var seen = Set<String>()
        let orderedCandidates: [String]
        let rankedUserCandidates = candidatesOrderedByRecency(userCandidates)
        if kanaCandidates.first?.count == 1 {
            orderedCandidates = kanaCandidates
                + rankedUserCandidates
                + candidatesOrderedByRecency(
                    extensionCandidates
                        + basicExactCandidates
                        + inflectionCandidates
                        + englishCandidates
                        + googleCandidates
                        + basicPrefixCandidates
                )
        } else {
            orderedCandidates = rankedUserCandidates
                + candidatesOrderedByRecency(
                    extensionCandidates
                        + basicExactCandidates
                        + inflectionCandidates
                        + kanaCandidates
                        + englishCandidates
                        + googleCandidates
                        + basicPrefixCandidates
                )
        }
        currentCandidates = orderedCandidates
        .filter { seen.insert($0).inserted }

        guard !currentCandidates.isEmpty else {
            selectedCandidateIndex = nil
            candidateWindow.hide()
            showInputPreview(client: sender)
            return
        }

        showCandidateWindow(client: sender)
        showInputPreview(client: sender)
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

    private func updateGoogleSuggestionsIfNeeded(for input: String) {
        guard isGoogleSuggestionsEnabled,
              input.count >= 2,
              googleSuggestionQuery != input else {
            return
        }
        googleSuggestionTask?.cancel()
        googleSuggestionQuery = input
        googleSuggestionCandidates = []
        googleSuggestionTask = Task { @MainActor [weak self] in
            do {
                try await Task.sleep(for: .milliseconds(250))
                let suggestions = try await GoogleSuggestionClient()
                    .suggestions(for: input)
                try Task.checkCancellation()
                guard let self,
                      isGoogleSuggestionsEnabled,
                      conversionReading == input else {
                    return
                }
                googleSuggestionCandidates = Array(
                    suggestions.prefix(Self.maximumCandidateCount)
                )
                if let inputClient = client() {
                    refreshCandidates(client: inputClient)
                }
            } catch is CancellationError {
                return
            } catch {
                NSLog(
                    "Google検索候補の取得に失敗: %@",
                    error.localizedDescription
                )
            }
        }
    }

    private func isGoogleSearchShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags
            .intersection(.deviceIndependentFlagsMask)
            .subtracting([.capsLock, .numericPad])
        return flags == [.command]
            && (event.keyCode == 36 || event.keyCode == 76)
    }

    private func openSelectedGoogleSearch(client sender: Any) -> Bool {
        guard isGoogleSearchEnabled,
              let selectedCandidateIndex,
              currentCandidates.indices.contains(selectedCandidateIndex) else {
            return false
        }
        let candidate = currentCandidates[selectedCandidateIndex]
        guard let url = try? GoogleSuggestionClient.searchURL(
            for: candidate
        ) else {
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
        currentCandidates = []
        selectedCandidateIndex = nil
        candidatePanel.hide()
        candidateWindow.hide()
        previewWindow.hide()
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
            candidates: Array(currentCandidates[pageStart..<pageEnd]),
            selectedIndex: selectedCandidateIndex.map { $0 - pageStart },
            near: inputLocation(for: sender)
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
        candidateSelectionRanks[candidate] = nextCandidateSelectionRank
        nextCandidateSelectionRank += 1
        do {
            try Self.saveCandidateSelectionRanks(candidateSelectionRanks)
        } catch {
            NSLog(
                "候補選択履歴の保存に失敗: %@",
                error.localizedDescription
            )
        }
    }

    private func candidatesOrderedByRecency(
        _ candidates: [String]
    ) -> [String] {
        CandidateRecencyOrderer.ordered(
            candidates,
            ranks: candidateSelectionRanks
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

    private func deleteBackward(from sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }

        inputBuffer.removeLast()
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

    private func commit(_ value: String, to sender: Any) {
        guard let textClient = sender as? IMKTextInput else {
            return
        }

        textClient.insertText(
            value,
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
        )
        inputBuffer = ""
        tabDictionaryRegistration = nil
        currentCandidates = []
        selectedCandidateIndex = nil
        candidatePanel.hide()
        candidateWindow.hide()
        previewWindow.hide()
        recordCommittedInput(value, client: sender)
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
        do {
            try Self.saveNextInputPredictionModel(nextInputPredictionModel)
        } catch {
            NSLog(
                "次入力履歴の保存に失敗: %@",
                error.localizedDescription
            )
        }

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
            near: inputLocation(for: sender)
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

        textClient.setMarkedText(
            value,
            selectionRange: NSRange(location: value.utf16.count, length: 0),
            replacementRange: NSRange(location: NSNotFound, length: NSNotFound)
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
        let anchorFrame = currentCandidates.isEmpty
            ? inputLocation(for: sender)
            : candidateWindow.frame
        showPreview(
            for: pageTitle,
            beside: anchorFrame,
            includeDefinitions: false
        )
    }

    private func showPreview(for candidate: String) {
        showPreview(
            for: candidate,
            beside: candidateWindow.frame,
            includeDefinitions: true
        )
    }

    private func showPreview(
        for candidate: String,
        beside anchorFrame: NSRect,
        includeDefinitions: Bool
    ) {
        guard isCosensePreviewEnabled || isSystemDictionaryPreviewEnabled else {
            previewWindow.hide()
            return
        }
        let url = isCosensePreviewEnabled
            ? CosensePageURL.make(
                project: dictionarySource.project,
                pageTitle: candidate
            )
            : nil

        previewWindow.showIfPageExists(
            project: dictionarySource.project,
            pageTitle: candidate,
            url: url,
            credential: cosenseCredential,
            definitions: includeDefinitions && isSystemDictionaryPreviewEnabled
                ? definitionProvider.definitions(for: candidate)
                : [],
            showCosense: isCosensePreviewEnabled,
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
    }

    private var conversionReading: String {
        String(
            inputBuffer.prefix {
                $0.isASCII
                    && ($0.isLetter || $0 == "-" || $0 == "'")
            }
        )
    }

    private var conversionSuffix: String {
        if !JapaneseSymbolConverter.candidates(for: inputBuffer).isEmpty {
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

    private var isCosensePreviewEnabled: Bool {
        experimentalFeatureIsEnabled(
            defaultsKey: Self.cosensePreviewEnabledDefaultsKey
        )
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

    private var isGoogleSuggestionsEnabled: Bool {
        if UserDefaults.standard.object(
            forKey: Self.googleSuggestionsEnabledDefaultsKey
        ) == nil {
            return false
        }
        return UserDefaults.standard.bool(
            forKey: Self.googleSuggestionsEnabledDefaultsKey
        )
    }

    private var isGoogleSearchEnabled: Bool {
        if UserDefaults.standard.object(
            forKey: Self.googleSearchEnabledDefaultsKey
        ) == nil {
            return false
        }
        return UserDefaults.standard.bool(
            forKey: Self.googleSearchEnabledDefaultsKey
        )
    }

    private var isSystemDictionaryPreviewEnabled: Bool {
        experimentalFeatureIsEnabled(
            defaultsKey: Self.systemDictionaryPreviewEnabledDefaultsKey
        )
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

    private static func loadCandidateSelectionRanks() -> [String: Int] {
        guard
            let data = try? Data(contentsOf: candidateSelectionHistoryURL()),
            let ranks = try? JSONDecoder().decode(
                [String: Int].self,
                from: data
            )
        else {
            return [:]
        }
        return ranks
    }

    private static func saveCandidateSelectionRanks(
        _ ranks: [String: Int]
    ) throws {
        let fileManager = FileManager.default
        let fileURL = candidateSelectionHistoryURL()
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try JSONEncoder().encode(ranks).write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func candidateSelectionHistoryURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/myim/user",
                isDirectory: true
            )
            .appendingPathComponent("candidate-selection-history.json")
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

    private static func saveNextInputPredictionModel(
        _ model: NextInputPredictionModel
    ) throws {
        let fileManager = FileManager.default
        let fileURL = nextInputPredictionModelURL()
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        try JSONEncoder().encode(model).write(to: fileURL, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: fileURL.path
        )
    }

    private static func nextInputPredictionModelURL() -> URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(
                "Library/Application Support/myim/user",
                isDirectory: true
            )
            .appendingPathComponent("next-input-model.json")
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
