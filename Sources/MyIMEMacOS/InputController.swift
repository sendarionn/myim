@preconcurrency import AppKit
@preconcurrency import InputMethodKit
import MyIMECore
import OSLog

@objc(MyIMEInputController)
final class InputController: IMKInputController {
    private static let lifecycleLogger = Logger(
        subsystem: "com.sendarionn.myim",
        category: "input-lifecycle"
    )
    private static let diagnosticConfiguration = InputDiagnosticConfiguration(
        environment: ProcessInfo.processInfo.environment
    )
    private static weak var activeController: InputController?
    private static weak var emojiPanelController: InputController?
    private enum TranslationCandidateDestination {
        case standard
        case fuzzy(reading: String)

        var channel: TranslationCandidateChannel {
            switch self {
            case .standard: .standard
            case .fuzzy: .fuzzy
            }
        }
    }

    private static let featureSettings = InputFeatureSettings()
    private static let maximumCandidateCount = 4
    private static let initialFuzzyCandidateCount = 4
    /// Gap between the input line and the candidate panel below it
    private static let candidatePanelAnchorSpacing: CGFloat = 8
    private static let fuzzyCandidateDisplayDelay = Duration.milliseconds(120)
    private static let maximumMozcDictionaryPrefixCandidates = 2048
    private static let sharedBasicEntries = loadBasicEntries()
    private static let sharedBasicConversionEngine = ConversionEngine(
        entries: sharedBasicEntries
    )
    private static let sharedSymbolConversionEngine = ConversionEngine(
        entries: loadBundledEntries(resource: "symbol-dictionary")
    )
    private static let sharedMozcConversionEngine = loadMozcDictionaryEngine()
    // Learning shared by every InputController; each controller only keeps
    // its own candidate session and typing context
    private static let sharedCandidateSelectionHistoryStore =
        CandidateSelectionHistoryStore(
            history: loadCandidateSelectionHistory(),
            writer: DeferredJSONFileWriter(
                fileURL: candidateSelectionHistoryURL(),
                queueLabel: "myim.candidate-selection-history",
                errorHandler: {
                    NSLog(
                        "候補選択履歴の保存に失敗: %@",
                        $0.localizedDescription
                    )
                }
            )
        )
    private static let sharedUnselectedInputLearningStore =
        UnselectedInputLearningStore(
            history: loadUnselectedInputLearningHistory(),
            writer: DeferredJSONFileWriter(
                fileURL: unselectedInputLearningHistoryURL(),
                queueLabel: "myim.unselected-input-learning",
                errorHandler: {
                    NSLog(
                        "未選択確定履歴の保存に失敗: %@",
                        $0.localizedDescription
                    )
                }
            )
        )
    private static let sharedNextInputLearningStore = NextInputLearningStore(
        model: loadNextInputPredictionModel(),
        writer: DeferredJSONFileWriter(
            fileURL: nextInputPredictionModelURL(),
            queueLabel: "myim.next-input-history",
            errorHandler: {
                NSLog(
                    "次入力履歴の保存に失敗: %@",
                    $0.localizedDescription
                )
            }
        )
    )
    private static let sharedDeferredSystemCandidates = DeferredSystemCandidates(
        text: loadBundledText(resource: "mozc-person-name-hints") ?? ""
    )
    private static let sharedVerbConjugations = VerbConjugationDictionary(
        text: loadBundledText(resource: "mozc-verb-classes") ?? ""
    )
    private static let sharedVerbInflectionGenerator =
        VerbInflectionCandidateGenerator(entries: sharedBasicEntries)
    private static let sharedBasicFuzzyEntries = sharedBasicEntries
        + VerbInflectionCandidateGenerator.typoSearchEntries(
            from: sharedBasicEntries,
            conjugations: sharedVerbConjugations
        )
    private static let sharedBasicFuzzyKey = "bundled-\(sharedBasicEntries.count)-\(sharedBasicFuzzyEntries.count)"
    private nonisolated(unsafe) static var sharedImportedDictionaryRuntime =
        ImportedDictionaryRuntime(
            dictionaries: importedDictionaryStore.loadDictionaries()
        )
    private static let fuzzyEngineRepository = FuzzyEngineRepository()
    private static let basicDictionaryUpdateCoordinator =
        BasicDictionaryUpdateCoordinator()
    private static let javaScriptExtensionClient = JavaScriptExtensionClient()
    private static let candidateFilterIDSStore =
        CandidateFilterIDSStore.applicationSupport()
    private static var candidateFilterDatabaseCache =
        CandidateFilterDatabaseCache(
            bundledText: loadBundledText(resource: "kanji-filter-data") ?? "",
            store: candidateFilterIDSStore
        )
    private static let candidateFilterChoiceGenerator =
        CandidateFilterChoiceGenerator(
            aliasDictionaryText: loadBundledText(
                resource: "candidate-filter-aliases"
            ) ?? ""
        )

    private var inputBuffer: String { inputSession.input }
    private var inputCursor: Int { inputSession.cursorPosition }
    private var reconversionOriginal: String?
    private var translationCandidateSession = TranslationCandidateSession()
    private var recentCommittedContext = ""
    private var secureInputPassthroughActive = false
    private var candidateSession = CandidateSession()
    private var candidateFilterCoordinator = CandidateFilterCoordinator()
    private var calendarSelectionSession = CalendarFormatSelectionSession()
    private var fuzzyCandidateSession = FuzzyCandidateSession()
    private let userDictionaryStore: UserDictionaryStore
    private var dictionaryRuntime: ConversionDictionaryRuntime
    private let shortcutSettingsController = ShortcutSettingsController()
    private lazy var javaScriptExtensionSettingsController =
        JavaScriptExtensionSettingsController(
            client: Self.javaScriptExtensionClient
        )
    private let candidateSelectionHistoryStore: CandidateSelectionHistoryStore
    private let unselectedInputLearningStore: UnselectedInputLearningStore
    private var closingBracketTracker = ClosingBracketTracker()
    private var emojiSearchLearning = EmojiSearchLearning()
    private let nextInputCandidateCoordinator: NextInputCandidateCoordinator
    private let candidateSearchCoordinator = CandidateSearchCoordinator()
    private let specialConversionCandidateSource =
        SpecialConversionCandidateSource()
    private var externalCandidates: [Candidate] = []
    private var javaScriptExtensionCandidates: [String] = []
    private var postalAddressCandidates: [String] = []
    private var postalAddressCache: [String: [String]] = [:]
    private var dictionaryRegistrationSession: DictionaryRegistrationSession?
    private var basicDictionaryStatus = BasicDictionaryStatus.unchecked
    private let panelCoordinator = InputPanelCoordinator()
    private let locationCoordinator = InputLocationCoordinator(
        logger: lifecycleLogger
    )
    private let definitionProvider = SystemDictionaryDefinitionProvider()
    private let romajiConverter = RomajiConverter()
    private let settingsWindowPresenter = SettingsWindowPresenter()
    private var activeInputClient: Any?
    private let lifecycleCoordinator = InputLifecycleCoordinator(
        clientBundleIdentifier: nil
    )
    private var isInsertingCommittedText = false
    private let controllerID = String(UUID().uuidString.prefix(8))
    private var inputSession = InputSession()
    private var lastTracedMarkedRange = NSRange(
        location: NSNotFound,
        length: 0
    )
    private var lastTracedSelectedRange = NSRange(
        location: NSNotFound,
        length: 0
    )
    private var keyHandlingLatencyWindow = LatencySampleWindow(
        capacity: 128,
        slowThresholdMicroseconds: 50_000
    )

    private var primaryCandidatePanel: CandidatePanelController {
        panelCoordinator.primaryCandidatePanel
    }

    private var candidateFilterDraftWindow: CandidatePanelController {
        panelCoordinator.candidateFilterDraft
    }

    private var calendarWindow: CalendarWindowController {
        panelCoordinator.calendar
    }

    private var emojiWindow: EmojiWindowController {
        panelCoordinator.emoji
    }

    private var secondaryCandidatePanel: SecondaryCandidatePanelController {
        panelCoordinator.secondaryCandidatePanel
    }

    private var previewWindow: ExternalInformationWindowController {
        panelCoordinator.externalInformation
    }

    private var symbolTipsWindow: SymbolTipsWindowController {
        panelCoordinator.symbolTips
    }

    static func handleGlobalEmojiShortcut() {
        guard let controller = activeController,
              let client = controller.activeInputClient else {
            EmojiDiagnostics.logger.error(
                "global hot key has no active input controller"
            )
            return
        }
        EmojiDiagnostics.logger.notice(
            "global hot key routed to active controller"
        )
        controller.toggleEmojiWindow(client: client)
    }

    static func handleGlobalEmojiPanelCommand(_ command: UInt32) {
        guard let controller = activeController ?? emojiPanelController,
              controller.emojiWindow.isVisible else {
            EmojiGlobalHotKey.shared.endPanelCapture()
            return
        }
        defer { controller.updateCandidateDeletionShortcutCapture() }
        let client: Any? = controller.activeInputClient
            ?? (controller.client() as Any?)
        switch command {
        case 4:
            controller.handleEmojiArrow(.left, client: client)
        case 5:
            controller.handleEmojiArrow(.right, client: client)
        case 6:
            controller.handleEmojiArrow(.up, client: client)
        case 7:
            controller.handleEmojiArrow(.down, client: client)
        case 8, 9:
            guard let client else { return }
            if let emoji = controller.emojiWindow.selectedEmoji {
                controller.commitSelectedEmoji(emoji, to: client)
                return
            }
            guard controller.emojiWindow.isSearchConfirmed else {
                controller.confirmEmojiSearch(client: client)
                return
            }
            return
        case 10:
            controller.handleEmojiEscape(client: client)
        case 11:
            guard controller.emojiWindow.canSelectEmoji else { return }
            controller.emojiWindow.advanceSelection(backward: false)
        case 12:
            guard controller.emojiWindow.canSelectEmoji else { return }
            controller.emojiWindow.advanceSelection(backward: true)
        default:
            break
        }
    }

    static func handleGlobalCandidateDeletionShortcut() {
        guard let controller = activeController,
              let client = controller.activeInputClient,
              let textClient = client as? IMKTextInput,
              InputClientRole.resolve(
                bundleIdentifier: textClient.bundleIdentifier()
              ).participatesInInputSessionLifecycle,
              !SecureInputDetector.isEnabled else {
            CandidateDeletionGlobalHotKey.shared.deactivate()
            return
        }
        guard controller.removeSelectedCandidate(client: client) else {
            CandidateDeletionGlobalHotKey.shared.deactivate()
            return
        }
        controller.updateCandidateDeletionShortcutCapture()
    }

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let cachedUserEntries = Self.loadUserEntries()
        let bundledEntries = Self.sharedBasicEntries
        let indexedMozcEngine = Self.sharedMozcConversionEngine

        userDictionaryStore = UserDictionaryStore(
            entries: cachedUserEntries,
            persist: { entries in
                let cache = try Self.userDictionaryCache()
                try cache.save(
                    dictionaryText: DictionarySerializer.text(from: entries),
                    metadata: DictionaryCacheMetadata(
                        syncedAt: Date(),
                        entryCount: entries.count
                    )
                )
            }
        )
        dictionaryRuntime = ConversionDictionaryRuntime(
            userEntries: cachedUserEntries,
            imported: Self.sharedImportedDictionaryRuntime,
            disabledImportedFilenames: Self.featureSettings
                .disabledImportedDictionaryFilenames,
            basicEntries: bundledEntries,
            basicEngine: Self.sharedBasicConversionEngine,
            verbInflectionGenerator: Self.sharedVerbInflectionGenerator,
            systemEngine: indexedMozcEngine
        )
        candidateSelectionHistoryStore = Self.sharedCandidateSelectionHistoryStore
        unselectedInputLearningStore = Self.sharedUnselectedInputLearningStore
        unselectedInputLearningStore.remove(candidates: Set(
            cachedUserEntries.flatMap(\.candidates).map {
                DictionaryCandidateRepresentation.value(from: $0)
            }
        ))
        nextInputCandidateCoordinator = NextInputCandidateCoordinator(
            store: Self.sharedNextInputLearningStore
        )
        JavaScriptExtensionClient.prepareUserExtensionDirectory()
        super.init(server: server, delegate: delegate, client: inputClient)
        lifecycleCoordinator.updateClient(
            bundleIdentifier: (inputClient as? IMKTextInput)?
                .bundleIdentifier()
        )
        previewWindow.onInteractionBegan = { [weak self] in
            self?.trace(
                "externalPanel.interaction",
                sender: self?.client(),
                detail: "phase=began"
            )
        }
        previewWindow.onInteractionEnded = { [weak self] in
            self?.trace(
                "externalPanel.interaction",
                sender: self?.client(),
                detail: "phase=ended"
            )
        }
        previewWindow.onDiagnosticEvent = { [weak self] event in
            self?.trace(event, sender: self?.client())
        }
        trace("InputController.created", sender: inputClient)

        basicDictionaryStatus = bundledEntries.isEmpty
            ? .loadFailed
            : .loaded(
                basicReadingCount: bundledEntries.count,
                mozcReadingCount: indexedMozcEngine.readingCount
            )
        rebuildFuzzyConversionEngine()
        updateBasicDictionaryIfNeeded(nil)
    }

    deinit {
        trace("InputController.deinit", sender: nil)
    }

    /// Key handling slower than this is logged, since the client app waits
    /// for it before drawing the next character
    private static let slowKeyHandlingThreshold = Duration.milliseconds(50)
    private static let slowCandidateRefreshThreshold = Duration.milliseconds(40)

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        let clock = ContinuousClock()
        let start = clock.now
        let tracesNavigation = beginNavigationTrace(for: event)
        let handled = handleUnmeasured(event, client: sender)
        updateCandidateDeletionShortcutCapture()
        if tracesNavigation {
            endNavigationTrace(handled: handled)
        }
        let elapsed = clock.now - start
        if let event, event.type == .keyDown {
            let microseconds = Self.microseconds(elapsed)
            if let summary = keyHandlingLatencyWindow.record(
                microseconds: microseconds
            ) {
                Self.lifecycleLogger.notice(
                    "key handling distribution samples=\(summary.count, privacy: .public) totalMs=\(summary.totalMicroseconds / 1_000, privacy: .public) p50Ms=\(summary.p50Microseconds / 1_000, privacy: .public) p95Ms=\(summary.p95Microseconds / 1_000, privacy: .public) p99Ms=\(summary.p99Microseconds / 1_000, privacy: .public) maxMs=\(summary.maximumMicroseconds / 1_000, privacy: .public) over50ms=\(summary.slowSampleCount, privacy: .public) app=\(self.lifecycleCoordinator.clientBundleIdentifier ?? "unknown", privacy: .public)"
                )
            }
        }
        if elapsed >= Self.slowKeyHandlingThreshold, let event,
           event.type == .keyDown {
            let milliseconds = Self.milliseconds(elapsed)
            Self.lifecycleLogger.notice(
                "slow key handling ms=\(milliseconds, privacy: .public) keyCode=\(event.keyCode, privacy: .public) app=\(self.lifecycleCoordinator.clientBundleIdentifier ?? "unknown", privacy: .public) compositionLength=\(self.inputBuffer.count, privacy: .public) candidateCount=\(self.currentCandidateModels.count, privacy: .public)"
            )
        }
        return handled
    }

    /// Temporary diagnostics for left and right arrows, enabled with
    /// `defaults write io.github.sendarionn.inputmethod.myime NavigationDiagnosticsEnabled -bool true`;
    /// records the handling path and cursor positions, never the text
    private static let navigationDiagnosticsKey = "NavigationDiagnosticsEnabled"
    private var navigationTraceSteps: [String]?

    private func beginNavigationTrace(for event: NSEvent?) -> Bool {
        guard let event, event.type == .keyDown,
              event.keyCode == 123 || event.keyCode == 124,
              UserDefaults.standard.bool(forKey: Self.navigationDiagnosticsKey)
        else {
            return false
        }
        navigationTraceSteps = []
        Self.lifecycleLogger.notice(
            "NAVTRACE begin key=\(event.keyCode == 123 ? "left" : "right", privacy: .public) state=\(String(describing: self.interactionState), privacy: .public) \(self.navigationSnapshot, privacy: .public)"
        )
        return true
    }

    private func endNavigationTrace(handled: Bool) {
        let steps = navigationTraceSteps ?? []
        navigationTraceSteps = nil
        Self.lifecycleLogger.notice(
            "NAVTRACE end consumed=\(handled, privacy: .public) state=\(String(describing: self.interactionState), privacy: .public) \(self.navigationSnapshot, privacy: .public) steps=\(steps.isEmpty ? "none" : steps.joined(separator: " > "), privacy: .public)"
        )
    }

    private var navigationSnapshot: String {
        "standard=\(selectedCandidateIndex.map(String.init) ?? "none") fuzzy=\(selectedFuzzyCandidateIndex.map(String.init) ?? "none") cursor=\(inputCursor) inputLength=\(inputBuffer.count) primaryVisible=\(primaryCandidatePanel.isVisible) secondaryVisible=\(secondaryCandidatePanel.isVisible) \(translationSnapshot)"
    }

    /// Translation requests outlive the key that started them, so they are
    /// logged on their own while navigation diagnostics are enabled
    private func logTranslationDiagnostics(
        _ message: @autoclosure () -> String
    ) {
        guard UserDefaults.standard.bool(
            forKey: Self.navigationDiagnosticsKey
        ) else { return }
        let text = message()
        Self.lifecycleLogger.notice(
            "NAVTRACE translation \(text, privacy: .public) \(self.translationSnapshot, privacy: .public)"
        )
    }

    private var translationSnapshot: String {
        let shown = translationCandidateSession.visibleSource
        let current = currentTranslationSource
        return "shownChannel=\(shown.map { "\($0.channel)" } ?? "none") currentChannel=\(current.map { "\($0.channel)" } ?? "none") showsCurrent=\(current.map(translationCandidateSession.isShowingTranslations(of:)) ?? false) panels=\(panelCoordinator.visibleTranslationCandidateFrames.count)"
    }

    private func noteNavigation(_ step: @autoclosure () -> String) {
        guard navigationTraceSteps != nil else { return }
        navigationTraceSteps?.append(step())
    }

    private func handleUnmeasured(
        _ event: NSEvent!,
        client sender: Any!
    ) -> Bool {
        guard let event, let sender else {
            return false
        }
        let senderBundleIdentifier = (sender as? IMKTextInput)?
            .bundleIdentifier()
        guard InputClientRole.resolve(
            bundleIdentifier: senderBundleIdentifier
        ).participatesInInputSessionLifecycle else {
            return false
        }

        guard event.type == .keyDown else {
            return false
        }
        trace(
            "keyDown",
            sender: sender,
            detail: "keyCode=\(event.keyCode) characters=\(event.characters ?? "")"
        )

        if event.keyCode == 14 {
            let modifiers = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask).rawValue
            EmojiDiagnostics.logger.notice(
                "E key reached handle modifiers=\(modifiers, privacy: .public)"
            )
        }

        if SecureInputDetector.isEnabled {
            beginSecureInputPassthroughIfNeeded(client: sender)
            return false
        }
        secureInputPassthroughActive = false

        if inputBuffer.isEmpty {
            logPanelSnapshot(event: "keyDown.emptyBuffer.beforeAnchor", sender: sender)
            locationCoordinator.captureCompositionAnchor(from: sender)
            logPanelSnapshot(event: "keyDown.emptyBuffer.afterAnchor", sender: sender)
        }

        if FunctionKeyEventPolicy.shouldIgnore(keyCode: event.keyCode) {
            return true
        }

        if isEmojiShortcut(event) {
            toggleEmojiWindow(client: sender)
            return true
        }

        if emojiWindow.isVisible {
            return handleEmojiPanelEvent(event, client: sender)
        }

        if previewWindow.isInteractionActive {
            previewWindow.finishInteraction()
            if event.keyCode == 53 {
                return true
            }
        }

        if isSystemUndoRedoShortcut(event) {
            if !inputBuffer.isEmpty || dictionaryRegistrationSession != nil {
                clearCompositionForSystemPaste(in: sender)
            }
            if nextInputCandidateCoordinator.hasCandidates {
                dismissNextInputCandidates(clearMarkedTextIn: sender)
            }
            return false
        }

        if calendarWindow.isVisible {
            return calendarWindow.handleKeyEvent(event)
        }

        if calendarSelectionSession.isSelectingFormat {
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


        if candidateFilterCoordinator.draft != nil {
            return handleCandidateFilterInput(event, client: sender)
        }

        if candidateSession.unfilteredCandidates != nil,
           let offset = CandidateFilterArrowNavigation.offset(
               forKeyCode: Int(event.keyCode)
           ) {
            return moveCandidate(
                offset > 0 ? .down : .up,
                client: sender
            )
        }

        if isCandidateFilterShortcut(event) {
            return beginCandidateFilterInput(client: sender)
        }

        if interactionState == .registeringDictionary {
            return handleDictionaryRegistration(event, client: sender)
        }

        if isUserDictionaryDeletionShortcut(event) {
            if removeSelectedCandidate(client: sender) {
                return true
            }
            if !inputBuffer.isEmpty {
                NSSound.beep()
                return true
            }
            return false
        }

        if inputBuffer.isEmpty,
           event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
           let typedText = event.characters,
           let selectedNextInput = nextInputCandidateCoordinator
            .selectedCandidate,
           closingBracketTracker.shouldConsumeTypedClosing(
                typedText,
                selectedCandidate: selectedNextInput
           ) {
            commitNextInputCandidate(selectedNextInput, to: sender)
            return true
        }

        commitSelectedNextInputBeforeNewInput(event, client: sender)

        if shouldDismissNextInputCandidates(for: event) {
            dismissNextInputCandidates(clearMarkedTextIn: sender)
        }

        if event.keyCode == 15,
           event.modifierFlags.contains([.command, .option, .control]) {
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

        if isDictionaryRegistrationShortcut(event),
           !inputBuffer.isEmpty {
            return beginDictionaryRegistration(client: sender)
        }

        if handleInputFormFunctionKey(event, client: sender) {
            return true
        }

        if let handled = handleTranslationCandidateSelection(
            event,
            client: sender
        ) {
            return handled
        }

        if let handled = handleFuzzyCandidateSelection(
            event,
            client: sender
        ) {
            return handled
        }

        if isFuzzyCandidateEntryShortcut(event),
           !fuzzyCandidateSession.isEmpty {
            return selectFuzzyCandidate(index: 0, client: sender)
        }

        if let handled = handleStandardKeyEvent(event, client: sender) {
            return handled
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
            commit(selectedValue + compositionSuffix, to: sender)
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

    private func handleStandardKeyEvent(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool? {
        switch InputKey(keyCode: event.keyCode) {
        case .tab:
            return handleTab(event, client: sender)
        case .space:
            let space = isFullWidthSpaceShortcut(event) ? "　" : " "
            if space == " ", inputBuffer.isEmpty,
               shouldSuppressActivationSpace(event) {
                lifecycleCoordinator.clearActivationTime()
                return true
            }
            return handleSpace(space: space, client: sender)
        case .leftArrow:
            return handleHorizontalArrow(.left, client: sender)
        case .rightArrow:
            return handleHorizontalArrow(.right, client: sender)
        case .downArrow:
            return handleVerticalArrow(.down, client: sender)
        case .upArrow:
            return handleVerticalArrow(.up, client: sender)
        case .returnKey:
            return handleReturnKey(client: sender)
        case .delete:
            return deleteBackward(
                from: sender,
                unit: deletionUnit(for: event)
            )
        case .escape:
            if candidateSession.unfilteredCandidates != nil {
                removeLastCandidateFilter(client: sender)
                return true
            }
            return cancelInput(in: sender)
        case .inputFormFunction, .other:
            return nil
        }
    }

    private func handleHorizontalArrow(
        _ direction: CandidateNavigationDirection,
        client sender: Any
    ) -> Bool {
        if inputBuffer.isEmpty, nextInputCandidateCoordinator.hasCandidates {
            noteNavigation("horizontalArrow.nextInput")
            guard nextInputCandidateCoordinator.selectedIndex != nil else {
                dismissNextInputCandidates(clearMarkedTextIn: nil)
                return false
            }
            return moveNextInputCandidate(direction, client: sender)
        }
        if selectedCandidateIndex != nil,
           shouldEnterTranslationCandidates(
                direction: direction,
                from: primaryCandidatePanel.frame
           ) {
            noteNavigation("horizontalArrow.enterTranslation")
            return enterTranslationCandidates(client: sender)
        }
        let offset = direction == .left ? -1 : 1
        noteNavigation(selectedCandidateIndex == nil
            ? "horizontalArrow.moveInputCursor"
            : "horizontalArrow.enterFuzzy")
        return selectedCandidateIndex == nil
            ? moveInputCursor(by: offset, client: sender)
            : enterFuzzyCandidatesOrConsumeArrow(client: sender)
    }

    private func handleVerticalArrow(
        _ direction: CandidateNavigationDirection,
        client sender: Any
    ) -> Bool {
        if inputBuffer.isEmpty, nextInputCandidateCoordinator.hasCandidates {
            guard nextInputCandidateCoordinator.selectedIndex != nil else {
                dismissNextInputCandidates(clearMarkedTextIn: nil)
                return false
            }
            return moveNextInputCandidate(direction, client: sender)
        }
        return selectedCandidateIndex == nil
            ? false
            : moveCandidate(direction, client: sender)
    }

    private func handleReturnKey(client sender: Any) -> Bool {
        if inputBuffer.isEmpty, nextInputCandidateCoordinator.hasCandidates {
            if let selectedNextInput = nextInputCandidateCoordinator
                .selectedCandidate {
                commitNextInputCandidate(selectedNextInput, to: sender)
                return true
            }
            dismissNextInputCandidates(clearMarkedTextIn: sender)
            return true
        }
        if inputBuffer.isEmpty {
            nextInputCandidateCoordinator.breakSequence()
            closingBracketTracker.reset()
            recentCommittedContext = String(
                (recentCommittedContext + "\n").suffix(256)
            )
            return false
        }
        if candidateSession.unfilteredCandidates != nil,
           currentCandidates.isEmpty {
            return true
        }
        return commitFirstCandidateOrInput(to: sender)
    }

    private func handleEmojiPanelEvent(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool {
        // The controller receiving the panel's keys holds its search text,
        // which may not be the controller that opened the shared panel
        if Self.emojiPanelController !== self {
            EmojiDiagnostics.logger.notice(
                "panel keys taken over owner=\(Self.emojiPanelController?.controllerID ?? "nil", privacy: .public) controller=\(self.controllerID, privacy: .public)"
            )
            Self.emojiPanelController = self
        }
        defer { updateCandidateDeletionShortcutCapture() }
        if isUserDictionaryDeletionShortcut(event),
           selectedCandidateDeletionTarget == .recentEmoji {
            removeSelectedRecentEmoji()
            return true
        }
        switch InputKey(keyCode: event.keyCode) {
        case .tab:
            if emojiWindow.canSelectEmoji {
                emojiWindow.advanceSelection(
                    backward: event.modifierFlags.contains(.shift)
                )
            } else {
                _ = handleTab(event, client: sender)
                updateEmojiSearchFromComposition()
            }
        case .leftArrow:
            handleEmojiArrow(.left, client: sender)
        case .rightArrow:
            handleEmojiArrow(.right, client: sender)
        case .downArrow:
            handleEmojiArrow(.down, client: sender)
        case .upArrow:
            handleEmojiArrow(.up, client: sender)
        case .returnKey:
            if let emoji = emojiWindow.selectedEmoji {
                commitSelectedEmoji(emoji, to: sender)
                return true
            }
            if !emojiWindow.isSearchConfirmed {
                confirmEmojiSearch(client: sender)
            }
        case .escape:
            handleEmojiEscape(client: sender)
        case .delete:
            if inputBuffer.isEmpty {
                emojiWindow.hide()
                Self.emojiPanelController = nil
                return true
            }
            if !emojiWindow.isSearchConfirmed {
                _ = deleteBackward(
                    from: sender,
                    unit: deletionUnit(for: event)
                )
                updateEmojiSearchFromComposition()
            }
        case .inputFormFunction:
            if !emojiWindow.isSearchConfirmed {
                _ = handleInputFormFunctionKey(
                    event,
                    client: sender,
                    preservesEmojiWindow: true
                )
                updateEmojiSearchFromComposition()
            }
        case .space, .other:
            let modifiers = event.modifierFlags.intersection(
                [.command, .control, .option]
            )
            if !emojiWindow.isSearchConfirmed,
               modifiers.isEmpty,
               let characters = event.characters,
               !characters.isEmpty {
                insertIntoInputBuffer(characters)
                selectedCandidateIndex = nil
                previewWindow.hide()
                updateMarkedText(in: sender)
                refreshCandidates(client: sender)
                updateEmojiSearchFromComposition()
            }
        }
        return true
    }

    private func handleEmojiArrow(
        _ direction: EmojiGridDirection,
        client sender: Any?
    ) {
        let action = EmojiSearchActivationPolicy.arrowAction(
            direction: direction,
            searchText: emojiWindow.searchText,
            isSearchConfirmed: emojiWindow.isSearchConfirmed
        )
        switch action {
        case .moveSearchCandidate:
            guard let sender else { return }
            let candidateDirection: CandidateNavigationDirection = switch direction {
            case .up: .up
            case .down: .down
            case .left: .left
            case .right: .right
            }
            _ = moveCandidate(candidateDirection, client: sender)
            updateEmojiSearchFromComposition()
        case .enterEmojiSelection:
            guard let sender else { return }
            confirmEmojiSearch(client: sender)
            emojiWindow.moveSelection(direction)
        case .moveEmojiSelection:
            emojiWindow.moveSelection(direction)
        }
    }

    private func handleEmojiEscape(client sender: Any?) {
        switch EmojiSearchActivationPolicy.escapeAction(
            isSearchConfirmed: emojiWindow.isSearchConfirmed
        ) {
        case .resumeSearchEditing:
            guard let sender else { return }
            let searchText = selectedCandidateIndex.flatMap { index in
                currentCandidates.indices.contains(index)
                    ? candidateDisplayValue(currentCandidates[index])
                    : nil
            } ?? inputBuffer
            emojiWindow.updateSearchText(searchText)
            setMarkedText(searchText, in: sender)
            showPrimaryCandidatePanel(client: sender)
        case .closePanel:
            if let sender {
                clearCompositionForSystemPaste(in: sender)
            }
            emojiWindow.hide()
            Self.emojiPanelController = nil
        }
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        currentCandidateModels.map(\.displayText)
    }

    override func doCommand(
        by aSelector: Selector!,
        command infoDictionary: [AnyHashable: Any]!
    ) {
        if let aSelector,
           emojiWindow.isVisible,
           emojiWindow.canSelectEmoji,
           case let .moveSelection(backward) = EmojiPanelCommand(
               selectorName: NSStringFromSelector(aSelector)
           ) {
            EmojiDiagnostics.logger.notice(
                "Tab command routed to emoji panel backward=\(backward, privacy: .public)"
            )
            emojiWindow.advanceSelection(backward: backward)
            return
        }
        if let aSelector,
           dictionaryRegistrationSession != nil,
           let inputClient = client() {
            switch NSStringFromSelector(aSelector) {
            case "insertNewline:", "insertNewlineIgnoringFieldEditor:":
                _ = confirmDictionaryRegistration(client: inputClient)
                return
            case "cancelOperation:":
                cancelDictionaryRegistration(client: inputClient)
                return
            default:
                break
            }
        }
        if let aSelector,
           inputBuffer.isEmpty,
           !nextInputCandidateCoordinator.hasCandidates,
           ["insertNewline:", "insertNewlineIgnoringFieldEditor:"]
            .contains(NSStringFromSelector(aSelector)) {
            nextInputCandidateCoordinator.breakSequence()
            closingBracketTracker.reset()
        }
        if let aSelector,
           candidateFilterCoordinator.draft != nil
                || candidateSession.unfilteredCandidates != nil,
           let inputClient = client() {
            let command = NSStringFromSelector(aSelector)
            if let offset = CandidateFilterArrowNavigation.offset(
                forCommand: command
            ) {
                if candidateFilterCoordinator.draft != nil {
                    moveCandidateFilterDraftSelection(
                        by: offset,
                        client: inputClient
                    )
                } else {
                    _ = moveCandidate(
                        offset > 0 ? .down : .up,
                        client: inputClient
                    )
                }
                return
            }
            switch command {
            case "cancelOperation:":
                if candidateFilterCoordinator.draft != nil {
                    handleCandidateFilterEscape(client: inputClient)
                } else {
                    removeLastCandidateFilter(client: inputClient)
                }
                return
            case "deleteBackward:":
                if candidateFilterCoordinator.draft?.stage == .filter {
                    return
                }
            case "insertNewline:", "insertNewlineIgnoringFieldEditor:":
                if candidateSession.unfilteredCandidates != nil,
                   currentCandidates.isEmpty {
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
                openCandidateFilterIDSDirectory: #selector(
                    openCandidateFilterIDSDirectory(_:)
                ),
                manageJavaScriptExtensions: #selector(
                    manageJavaScriptExtensions(_:)
                ),
                showStatus: #selector(showStatus(_:))
            )
        )
    }

    @objc
    private func openSettingsWindow(_ sender: Any?) {
        let inputFrame = activeInputClient.map { inputLocation(for: $0) }
            ?? .zero
        settingsWindowPresenter.show(near: inputFrame) {
            SettingsWindowBuilder.make(
                target: self,
                states: settingsFeatureStates,
                actions: settingsActions
            )
        }
    }

    private var settingsFeatureStates: SettingsWindowBuilder.FeatureStates {
        SettingsWindowBuilder.FeatureStates(
            englishCompletion: Self.featureSettings.isEnglishCompletionEnabled,
            wikipediaSuggestions: Self.featureSettings.isWikipediaSuggestionsEnabled,
            googleJapaneseInput: Self.featureSettings.isGoogleJapaneseInputEnabled,
            appleTranslation: Self.featureSettings.isAppleTranslationEnabled,
            translationLanguageIdentifiers:
                Set(Self.featureSettings.translationTargetLanguages.map(\.identifier)),
            nextInputPrediction: Self.featureSettings.isNextInputPredictionEnabled,
            fuzzyCandidates: Self.featureSettings.isFuzzyCandidatesEnabled,
            dateTimeCandidates: Self.featureSettings.isDateTimeCandidatesEnabled,
            externalInformationPanel: Self.featureSettings.isExternalInformationPanelEnabled,
            systemDictionaryPreview: Self.featureSettings.isSystemDictionaryPreviewEnabled,
            webSearch: Self.featureSettings.isWebSearchEnabled,
            importedDictionaries: ImportedDictionaryChecklist.items(
                dictionaries: dictionaryRuntime.imported.dictionaries,
                disabledFilenames: Self.featureSettings
                    .disabledImportedDictionaryFilenames
            ).map {
                SettingsWindowBuilder.ImportedDictionaryState(
                    filename: $0.filename,
                    isEnabled: $0.isEnabled
                )
            }
        )
    }

    private var settingsActions: SettingsWindowBuilder.Actions {
        SettingsWindowBuilder.Actions(
            toggleEnglishCompletion: #selector(toggleEnglishCompletion(_:)),
            toggleWikipediaSuggestions: #selector(toggleWikipediaSuggestions(_:)),
            toggleGoogleJapaneseInput: #selector(toggleGoogleJapaneseInput(_:)),
            toggleAppleTranslation: #selector(toggleAppleTranslation(_:)),
            toggleTranslationLanguage: #selector(
                toggleTranslationLanguage(_:)
            ),
            toggleNextInputPrediction: #selector(toggleNextInputPrediction(_:)),
            toggleFuzzyCandidates: #selector(toggleFuzzyCandidates(_:)),
            toggleDateTimeCandidates: #selector(toggleDateTimeCandidates(_:)),
            clearNextInputHistory: #selector(clearNextInputPredictionHistory(_:)),
            toggleExternalInformationPanel: #selector(toggleExternalInformationPanel(_:)),
            toggleSystemDictionaryPreview: #selector(toggleSystemDictionaryPreview(_:)),
            configureSystemDictionaries: #selector(configureSystemDictionaries(_:)),
            toggleWebSearch: #selector(toggleWebSearch(_:)),
            configureShortcuts: #selector(configureShortcuts(_:)),
            importSKKDictionary: #selector(importSKKDictionary(_:)),
            toggleImportedDictionary: #selector(toggleImportedDictionary(_:)),
            updateBasicDictionary: #selector(updateBasicDictionaryIfNeeded(_:)),
            downloadCandidateFilterIDS: #selector(downloadCandidateFilterIDS(_:)),
            openCandidateFilterIDSDirectory: #selector(
                openCandidateFilterIDSDirectory(_:)
            )
        )
    }

    @objc
    private func configureShortcuts(_ sender: Any?) {
        shortcutSettingsController.show()
    }

    @objc
    private func importSKKDictionary(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "SKK辞書をインポート"
        panel.prompt = "インポート"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true

        let completion: (NSApplication.ModalResponse) -> Void = {
            [weak self] response in
            guard response == .OK, let self else { return }
            do {
                let summary = try Self.importedDictionaryStore.importSKKFiles(
                    panel.urls
                ) {
                    Self.featureSettings.setImportedDictionary(
                        $0.fileURL.lastPathComponent,
                        enabled: true
                    )
                }
                let imported = ImportedDictionaryRuntime(
                    dictionaries: Self.importedDictionaryStore.loadDictionaries()
                )
                Self.sharedImportedDictionaryRuntime = imported
                dictionaryRuntime.replaceImported(
                    imported,
                    userEntries: userDictionaryStore.entries,
                    disabledImportedFilenames: Self.featureSettings
                        .disabledImportedDictionaryFilenames
                )
                rebuildFuzzyConversionEngine()
                settingsWindowPresenter.refreshIfPresented {
                    SettingsWindowBuilder.make(
                        target: self,
                        states: self.settingsFeatureStates,
                        actions: self.settingsActions
                    )
                }
                let alert = NSAlert()
                alert.messageText = "SKK辞書をインポートしました"
                alert.informativeText = summary.description
                alert.runModal()
            } catch {
                let alert = NSAlert(error: error)
                alert.messageText = "SKK辞書をインポートできません"
                alert.runModal()
            }
        }
        settingsWindowPresenter.run(panel, completion: completion)
    }

    @objc
    private func toggleImportedDictionary(_ sender: NSButton) {
        guard let filename = sender.identifier?.rawValue else { return }
        Self.featureSettings.setImportedDictionary(filename, enabled: sender.state == .on)
        rebuildConversionEngine()
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
    private func openCandidateFilterIDSDirectory(_ sender: Any?) {
        guard let store = Self.candidateFilterIDSStore else {
            showJavaScriptExtensionDirectoryError(
                title: "IDSデータフォルダを開けません",
                message: "Application Supportフォルダが見つかりません"
            )
            return
        }
        do {
            try store.prepareDirectory()
            JavaScriptExtensionDirectoryPresenter.open(store.directoryURL)
        } catch {
            showJavaScriptExtensionDirectoryError(
                title: "IDSデータフォルダを開けません",
                message: error.localizedDescription
            )
        }
    }

    @objc
    private func downloadCandidateFilterIDS(_ sender: Any?) {
        let confirmation = NSAlert()
        confirmation.messageText = "CJKVI IDSデータをダウンロード"
        confirmation.informativeText = """
        取得元: github.com/cjkvi/cjkvi-ids
        対象: ids.txt
        ライセンス: CHISE由来で配布元の条件が適用

        データはApplication Supportへ保存され、myim本体には同梱されません
        既にダウンロード済みの場合は同じファイルを置き換えます
        配布元のライセンスに従って利用してください
        """
        confirmation.addButton(withTitle: "ダウンロード")
        confirmation.addButton(withTitle: "キャンセル")
        guard confirmation.runModal() == .alertFirstButtonReturn else { return }

        let button = sender as? NSButton
        let originalTitle = button?.title
        button?.title = "ダウンロード中…"
        button?.isEnabled = false
        Task { @MainActor [weak self, weak button] in
            defer {
                button?.title = originalTitle ?? "CJKVI IDSデータをダウンロード"
                button?.isEnabled = true
            }
            do {
                let data = try await OptionalIDSDataClient().fetch()
                guard let store = Self.candidateFilterIDSStore else {
                    throw OptionalIDSDataError.invalidData
                }
                try store.saveCJKVIIDS(data, downloadedAt: Date())
                let cache = Self.candidateFilterDatabaseCache
                let database = await Task.detached(priority: .utility) {
                    cache.loadDatabase()
                }.value
                Self.candidateFilterDatabaseCache.replace(with: database)
                self?.showCandidateFilterIDSDownloadResult(
                    title: "ダウンロード完了",
                    message: "次の候補フィルターから構成要素検索へ反映されます"
                )
            } catch {
                self?.showCandidateFilterIDSDownloadResult(
                    title: "ダウンロードできませんでした",
                    message: error.localizedDescription
                )
            }
        }
    }

    private func showCandidateFilterIDSDownloadResult(
        title: String,
        message: String
    ) {
        let alert = NSAlert()
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "閉じる")
        alert.runModal()
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
            "ユーザー辞書: \(userDictionaryStore.count)読み",
            "TKGJE更新: \(basicDictionaryStatus.description)",
            "保護入力: \(secureInputStatusDescription)"
        ].joined(separator: "\n")
        alert.addButton(withTitle: "閉じる")
        alert.window.level = .floating
        NSApp.activate(ignoringOtherApps: true)
        _ = alert.runModal()
    }

    override func candidateSelectionChanged(_ candidateString: NSAttributedString!) {
        guard let candidateText = candidateString?.string else {
            previewWindow.hide()
            return
        }

        guard let index = CandidateSelectionProjection.index(
            for: candidateText,
            preferredIndex: selectedCandidateIndex,
            in: currentCandidateModels
        ) else { return }
        selectedCandidateIndex = index
        let candidate = currentCandidateModels[index]
        if let inputClient = client() {
            setMarkedText(
                CandidateSelectionProjection.markedText(
                    for: candidate,
                    prefix: compositionPrefix,
                    suffix: conversionSuffix + compositionSuffix
                ),
                in: inputClient
            )
        }
        showPreview(for: candidate.storageText)
    }

    override func candidateSelected(_ candidateString: NSAttributedString!) {
        guard let candidateText = candidateString?.string else {
            return
        }

        let resolvedIndex = CandidateSelectionProjection.index(
            for: candidateText,
            preferredIndex: selectedCandidateIndex,
            in: currentCandidateModels
        )
        let storedCandidate: Candidate
        if let resolvedIndex {
            selectedCandidateIndex = resolvedIndex
            storedCandidate = currentCandidateModels[resolvedIndex]
        } else if currentCandidateModels.contains(where: {
            $0.displayText == candidateText || $0.storageText == candidateText
        }) {
            NSSound.beep()
            return
        } else {
            storedCandidate = Candidate(storageText: candidateText)
        }
        recordCandidateSelectionForCurrentInput(storedCandidate)
        if emojiWindow.isVisible {
            confirmEmojiSearch(client: client() as Any)
            return
        }
        let historyValue = CalculationInputHistory.value(
            input: inputBuffer,
            selectedCandidate: storedCandidate.storageText,
            generatedCandidates: cachedJavaScriptCalculationCandidates
        )
        let punctuation = compositionSuffix
        commit(
            storedCandidate.commitText + conversionSuffix,
            to: client() as Any,
            historyValue: historyValue
        )
        if let sender = client() {
            continueWithTrailingPunctuation(punctuation, client: sender)
        }
    }

    override func commitComposition(_ sender: Any!) {
        guard lifecycleCoordinator.participatesInInputSessionLifecycle else {
            super.commitComposition(sender)
            return
        }
        trace("commitComposition.request", sender: sender)
        guard let sender else {
            return
        }
        guard !isInsertingCommittedText else {
            Self.lifecycleLogger.notice(
                "suppressed reentrant system commit during insertText"
            )
            return
        }

        if lifecycleCoordinator.consumeSystemCommitSuppression(
            hasComposition: !inputBuffer.isEmpty
        ) {
            Self.lifecycleLogger.notice(
                "suppressed transient system commit bufferLength=\(self.inputBuffer.count, privacy: .public)"
            )
            updateMarkedText(in: sender)
            return
        }

        if dictionaryRegistrationSession != nil {
            showDictionaryRegistration(client: sender)
            return
        }
        if reconversionOriginal != nil {
            restoreReconversionOriginal(client: sender)
            return
        }
        if inputBuffer.isEmpty {
            if closingBracketTracker
                .shouldPreserveCandidatesDuringEmptySystemCommit(
                    hasCandidates: nextInputCandidateCoordinator.hasCandidates
                ) {
                Self.lifecycleLogger.notice(
                    "preserved structural next-input candidate after empty system commit"
                )
                return
            }
            dismissNextInputCandidates(clearMarkedTextIn: sender)
            return
        }

        trace("commitComposition.execute", sender: sender)
        commitCurrentCompositionFromSystem(to: sender)
    }

    private func commitCurrentCompositionFromSystem(to sender: Any) {
        let plan = SystemCompositionCommitPlan.resolve(
            originalInput: inputBuffer,
            selectedCandidate: candidateSession.selectedCandidate,
            conversionSuffix: conversionSuffix,
            compositionSuffix: compositionSuffix
        )
        if let selectedCandidate = plan.selectedCandidate {
            recordCandidateSelectionForCurrentInput(selectedCandidate)
        }
        commit(plan.committedText, to: sender)
        learnUnselectedInput(plan.unselectedInputLearningEntry)
    }

    override func cancelComposition() {
        guard lifecycleCoordinator.participatesInInputSessionLifecycle else {
            super.cancelComposition()
            return
        }
        trace("cancelComposition", sender: client())
        super.cancelComposition()
    }

    override func activateServer(_ sender: Any!) {
        let activatingBundleIdentifier = (sender as? IMKTextInput)?
            .bundleIdentifier()
        let activatingRole = lifecycleCoordinator.updateClient(
            bundleIdentifier: activatingBundleIdentifier
        )
        guard activatingRole.participatesInInputSessionLifecycle else {
            super.activateServer(sender)
            Self.lifecycleLogger.notice(
                "ignored auxiliary activation client=\(activatingBundleIdentifier ?? "unknown", privacy: .public)"
            )
            return
        }
        let now = ProcessInfo.processInfo.systemUptime
        let activation = lifecycleCoordinator.activate(
            now: now,
            hasComposition: !inputBuffer.isEmpty
        )
        let resumesTransientDeactivation = activation
            .resumesTransientDeactivation
        if !resumesTransientDeactivation {
            locationCoordinator.forgetPreviousLocation()
        }
        activeInputClient = sender
        inputSession.activate(sessionGeneration: activation.globalGeneration)
        Self.activeController = self
        updateCandidateDeletionShortcutCapture()
        EmojiGlobalHotKey.shared.activate()
        super.activateServer(sender)
        Self.lifecycleLogger.notice(
            "activated bufferLength=\(self.inputBuffer.count, privacy: .public) resumed=\(resumesTransientDeactivation, privacy: .public) deactivationDuration=\(activation.deactivationDuration ?? -1, privacy: .public) client=\(self.lifecycleCoordinator.clientBundleIdentifier ?? "unknown", privacy: .public) appGeneration=\(self.lifecycleCoordinator.applicationGeneration ?? 0, privacy: .public) globalGeneration=\(activation.globalGeneration, privacy: .public) pid=\(ProcessInfo.processInfo.processIdentifier, privacy: .public)"
        )
        trace("activateServer", sender: sender)
    }

    override func deactivateServer(_ sender: Any!) {
        guard lifecycleCoordinator.participatesInInputSessionLifecycle else {
            Self.lifecycleLogger.notice(
                "ignored auxiliary deactivation client=\(self.lifecycleCoordinator.clientBundleIdentifier ?? "unknown", privacy: .public)"
            )
            super.deactivateServer(sender)
            return
        }
        trace("deactivateServer", sender: sender)
        let deactivation = lifecycleCoordinator.beginDeactivation(
            hasComposition: !inputBuffer.isEmpty
        )
        CandidateDeletionGlobalHotKey.shared.deactivate()
        EmojiGlobalHotKey.shared.deactivate()
        if Self.activeController === self {
            Self.activeController = nil
        }
        let frontmostBundleIdentifier = NSWorkspace.shared
            .frontmostApplication?.bundleIdentifier
        let preservesExternalInformation = previewWindow
            .shouldPreserveForExternalInteraction(
                frontmostBundleIdentifier: frontmostBundleIdentifier
            )
        let panelPolicy = InputPanelDismissalPolicy.deactivation(
            isExternalInformationInteractionActive: preservesExternalInformation,
            isCalendarInteractionActive: calendarSelectionSession.isActive
        )
        dismissInputSessionPanels(using: panelPolicy)
        if preservesExternalInformation {
            Self.lifecycleLogger.notice(
                "preserved composition for information panel interaction bufferLength=\(self.inputBuffer.count, privacy: .public) frontmost=\(frontmostBundleIdentifier ?? "unknown", privacy: .public)"
            )
            activeInputClient = nil
            super.deactivateServer(sender)
            return
        }
        if calendarSelectionSession.isActive {
            activeInputClient = nil
            super.deactivateServer(sender)
            return
        }
        lifecycleCoordinator.deferDeactivation(deactivation) { [weak self] outcome in
            guard let self else { return }
            switch outcome {
            case .ignored:
                return
            case .superseded:
                Self.lifecycleLogger.notice(
                    "discarded stale deactivation client=\(deactivation.application ?? "unknown", privacy: .public) appGeneration=\(deactivation.applicationGeneration ?? 0, privacy: .public) globalGeneration=\(deactivation.globalGeneration, privacy: .public) bufferLength=\(self.inputBuffer.count, privacy: .public)"
                )
                self.retireSupersededControllerUI()
            case .transientFollowUp:
                Self.lifecycleLogger.notice(
                    "discarded transient follow-up deactivation client=\(deactivation.application ?? "unknown", privacy: .public) frontmost=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier ?? "unknown", privacy: .public) bufferLength=\(self.inputBuffer.count, privacy: .public)"
                )
            case .commit:
                Self.lifecycleLogger.notice(
                    "deactivation committed after grace period bufferLength=\(self.inputBuffer.count, privacy: .public)"
                )
                self.finishControllerSession(
                    client: sender,
                    commitsComposition: true,
                    closesController: false
                )
                self.activeInputClient = nil
            }
        }
        Self.lifecycleLogger.notice(
            "deactivation deferred bufferLength=\(self.inputBuffer.count, privacy: .public)"
        )
        super.deactivateServer(sender)
    }

    override func inputControllerWillClose() {
        guard lifecycleCoordinator.participatesInInputSessionLifecycle else {
            Self.lifecycleLogger.notice(
                "ignored auxiliary controller close client=\(self.lifecycleCoordinator.clientBundleIdentifier ?? "unknown", privacy: .public)"
            )
            super.inputControllerWillClose()
            return
        }
        trace("InputController.willClose", sender: client())
        let closure = lifecycleCoordinator.close()
        if Self.activeController === self {
            CandidateDeletionGlobalHotKey.shared.deactivate()
            Self.activeController = nil
        }
        activeInputClient = nil
        Self.lifecycleLogger.notice(
            "input controller closing bufferLength=\(self.inputBuffer.count, privacy: .public) pendingDeactivation=\(closure.deactivationWasPending, privacy: .public) superseded=\(closure.sessionWasSuperseded, privacy: .public)"
        )
        if closure.sessionWasSuperseded {
            trace("asyncResult.rejectedAsStale", sender: client(), detail: "source=willClose")
            retireSupersededControllerUI()
            super.inputControllerWillClose()
            return
        }
        if previewWindow.shouldPreserveForExternalInteraction(
            frontmostBundleIdentifier: NSWorkspace.shared
                .frontmostApplication?.bundleIdentifier
        ) {
            dismissInputSessionPanels(using: .deactivation(
                isExternalInformationInteractionActive: true,
                isCalendarInteractionActive: false
            ))
            super.inputControllerWillClose()
            return
        }
        finishControllerSession(
            client: client(),
            commitsComposition: closure.commitsComposition,
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
            } else {
                commitCurrentCompositionFromSystem(to: sender as Any)
            }
        }
        resetTransientInteractionState()
        nextInputCandidateCoordinator.breakSequence()
        closingBracketTracker.reset()
        if closesController {
            candidateSearchCoordinator.cancel(.fuzzyIndexBuild)
        }
        flushPendingHistoryWrites()
    }

    private func retireSupersededControllerUI() {
        lifecycleCoordinator.clearPendingDeactivation()
        activeInputClient = nil
        resetTransientInteractionState()
        flushPendingHistoryWrites()
    }

    @objc
    private func toggleNextInputPrediction(_ sender: Any?) {
        let enabled = checkboxValue(sender, current: Self.featureSettings.isNextInputPredictionEnabled)
        Self.featureSettings.isNextInputPredictionEnabled = enabled
        if !enabled {
            dismissNextInputCandidates(clearMarkedTextIn: client())
            nextInputCandidateCoordinator.breakSequence()
        }
    }

    @objc
    private func toggleFuzzyCandidates(_ sender: Any?) {
        let enabled = checkboxValue(sender, current: Self.featureSettings.isFuzzyCandidatesEnabled)
        Self.featureSettings.isFuzzyCandidatesEnabled = enabled
        cancelFuzzyCandidateSearch()
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            secondaryCandidatePanel.hide()
            return
        }
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleDateTimeCandidates(_ sender: Any?) {
        let enabled = checkboxValue(sender, current: Self.featureSettings.isDateTimeCandidatesEnabled)
        Self.featureSettings.isDateTimeCandidatesEnabled = enabled
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            return
        }
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleEnglishCompletion(_ sender: Any?) {
        let enabled = checkboxValue(
            sender,
            current: Self.featureSettings.isEnglishCompletionEnabled
        )
        toggleCandidateSource {
            Self.featureSettings.isEnglishCompletionEnabled = enabled
        }
    }

    @objc
    private func toggleWikipediaSuggestions(_ sender: Any?) {
        let enabled = checkboxValue(sender, current: Self.featureSettings.isWikipediaSuggestionsEnabled)
        Self.featureSettings.isWikipediaSuggestionsEnabled = enabled
        resetExternalCandidates()
        guard !inputBuffer.isEmpty, let inputClient = client() else {
            return
        }
        selectedCandidateIndex = nil
        updateMarkedText(in: inputClient)
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleGoogleJapaneseInput(_ sender: Any?) {
        let enabled = checkboxValue(sender, current: Self.featureSettings.isGoogleJapaneseInputEnabled)
        Self.featureSettings.isGoogleJapaneseInputEnabled = enabled
        resetExternalCandidates()
        guard !inputBuffer.isEmpty, let inputClient = client() else { return }
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleAppleTranslation(_ sender: Any?) {
        let enabled = checkboxValue(sender, current: Self.featureSettings.isAppleTranslationEnabled)
        Self.featureSettings.isAppleTranslationEnabled = enabled
        resetExternalCandidates()
        guard !inputBuffer.isEmpty, let inputClient = client() else { return }
        refreshCandidates(client: inputClient)
    }

    @objc
    private func toggleTranslationLanguage(_ sender: Any?) {
        guard let item = sender as? NSMenuItem,
              let identifier = item.representedObject as? String,
              TranslationTargetLanguage.language(forIdentifier: identifier)
                != nil else {
            return
        }
        var identifiers = Set(Self.featureSettings.translationTargetLanguages.map(\.identifier))
        if item.state == .on {
            identifiers.remove(identifier)
            item.state = .off
        } else {
            identifiers.insert(identifier)
            item.state = .on
        }
        Self.featureSettings.translationLanguageIdentifiers = identifiers
        item.menu?.items.first?.title = "翻訳先言語（\(identifiers.count)）"
        cancelCandidateTranslation()
        if let inputClient = client(), !inputBuffer.isEmpty {
            showPrimaryCandidatePanel(client: inputClient)
        }
    }

    @objc
    private func toggleWebSearch(_ sender: Any?) {
        Self.featureSettings.isWebSearchEnabled = checkboxValue(sender, current: Self.featureSettings.isWebSearchEnabled)
    }

    private func resetExternalCandidates() {
        candidateSearchCoordinator.cancel(.external)
        externalCandidates = []
    }

    private func toggleCandidateSource(
        update: () -> Void
    ) {
        update()
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
        let enabled = checkboxValue(
            sender,
            current: Self.featureSettings.isExternalInformationPanelEnabled
        )
        Self.featureSettings.isExternalInformationPanelEnabled = enabled
        refreshExperimentalPreview()
    }

    @objc
    private func toggleSystemDictionaryPreview(_ sender: Any?) {
        let enabled = checkboxValue(
            sender,
            current: Self.featureSettings.isSystemDictionaryPreviewEnabled
        )
        Self.featureSettings.isSystemDictionaryPreviewEnabled = enabled
        refreshExperimentalPreview()
    }

    private func checkboxValue(_ sender: Any?, current: Bool) -> Bool {
        guard let button = sender as? NSButton else { return !current }
        return button.state == .on
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
        Self.featureSettings.setSystemDictionaryNames(names)
        candidateSearchCoordinator.cancel(.dictionaryDefinition)
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
        dismissNextInputCandidates(clearMarkedTextIn: client())
        do {
            try nextInputCandidateCoordinator.removeAllLearning()
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
        guard !basicDictionaryStatus.isChecking else {
            return
        }

        basicDictionaryStatus = .checking
        let force = sender != nil
        Task { @MainActor [weak self] in
            do {
                guard let snapshot = try await Self
                    .basicDictionaryUpdateCoordinator
                    .fetchIfNeeded(force: force) else {
                    guard let self else {
                        return
                    }
                    basicDictionaryStatus = .checked(
                        readingCount: dictionaryRuntime.basicEntries.count
                    )
                    return
                }
                let updater = BasicDictionaryUpdater(
                    cache: try Self.basicDictionaryCache(),
                    bundledRevision: Self.bundledBasicDictionaryRevision()
                )
                let result = try updater.apply(snapshot, syncedAt: Date())
                guard let self else {
                    return
                }
                switch result {
                case .alreadyLatest:
                    if dictionaryRuntime.basicEntries.isEmpty {
                        applyBasicDictionarySnapshot(snapshot)
                    }
                    basicDictionaryStatus = .latest(
                        readingCount: snapshot.entries.count
                    )
                case .updated:
                    applyBasicDictionarySnapshot(snapshot)
                    basicDictionaryStatus = .updated(
                        readingCount: snapshot.entries.count
                    )
                    if !inputBuffer.isEmpty, let inputClient = client() {
                        selectedCandidateIndex = nil
                        previewWindow.hide()
                        refreshCandidates(client: inputClient)
                    }
                }
            } catch {
                self?.basicDictionaryStatus = .checkFailed
                NSLog("TKGJE基本辞書の更新に失敗: %@", error.localizedDescription)
            }
        }
    }

    private func applyBasicDictionarySnapshot(
        _ snapshot: TKGDictionarySnapshot
    ) {
        dictionaryRuntime.replaceBasicEntries(
            Self.addingBundledRequiredEntries(to: snapshot.entries)
        )
        rebuildConversionEngine()
    }

    private func handleSpace(space: String, client sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            if let value = nextInputCandidateCoordinator.selectedCandidate {
                commitNextInputCandidate(
                    value,
                    appending: space,
                    replacingMarkedText: false,
                    to: sender
                )
                return true
            }
            guard space == "　" else {
                nextInputCandidateCoordinator.appendSeparatorToLastInput(space)
                return false
            }
            commit(space, to: sender)
            return true
        }
        if selectedCandidateIndex == nil,
           isCalculationExpressionDraft {
            insertIntoInputBuffer(space)
            refreshCandidates(client: sender)
            return true
        }
        let unselectedInputLearningEntry = UnselectedInputLearningPolicy.entry(
            originalInput: inputBuffer,
            hasSelectedCandidate: selectedCandidateValue != nil
        )
        let value = selectedCandidateValue ?? inputBuffer
        let punctuation = selectedCandidateValue == nil
            ? ""
            : compositionSuffix
        let committedValue = value + (punctuation.isEmpty ? space : "")
        recordSelectedCandidate()
        // Punctuation after the text takes the place of the space
        commit(
            committedValue,
            to: sender,
            historyValue: committedValue
        )
        learnUnselectedInput(unselectedInputLearningEntry)
        continueWithTrailingPunctuation(punctuation, client: sender)
        return true
    }

    private func isFullWidthSpaceShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(
            [.command, .control, .option, .shift]
        )
        return flags == [.shift]
    }

    private func handleInputFormFunctionKey(
        _ event: NSEvent,
        client sender: Any,
        preservesEmojiWindow: Bool = false
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
            source = conversionInput
            suffix = ""
        case 109:
            form = .halfWidthUppercaseAlphanumeric
            source = conversionInput
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
            candidateSession.insert(
                Candidate(
                    storageText: candidate,
                    source: .specialConversion,
                    reading: conversionReading
                ),
                at: 0
            )
            index = 0
        }
        selectedCandidateIndex = index
        cancelAuxiliaryCandidateSearches()
        primaryCandidatePanel.hide()
        secondaryCandidatePanel.hide()
        if !preservesEmojiWindow {
            emojiWindow.hide()
        }
        previewWindow.hide()
        setMarkedText(
            compositionPrefix + candidate,
            in: sender
        )
        return true
    }

    private func shouldDismissNextInputCandidates(
        for event: NSEvent
    ) -> Bool {
        guard nextInputCandidateCoordinator.hasCandidates else {
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
            shouldDismissNextInputCandidates(for: event),
            let selectedNextInput = nextInputCandidateCoordinator
                .selectedCandidate,
            event.modifierFlags.intersection([.command, .control, .option]).isEmpty,
            let characters = event.characters,
            !characters.isEmpty
        else {
            return
        }
        commitNextInputCandidate(selectedNextInput, to: sender)
    }

    private func handleTab(_ event: NSEvent, client sender: Any) -> Bool {
        let flags = event.modifierFlags.intersection(
            [.command, .control, .option, .shift]
        )
        if flags == [.shift] {
            return true
        }
        if inputBuffer.isEmpty {
            if nextInputCandidateCoordinator.selectedIndex != nil,
               flags.isEmpty {
                return selectNextInputCandidate(offset: 1, client: sender)
            }
            if flags.isEmpty,
               beginReconversionIfPossible(client: sender) {
                return true
            }
            if flags.isEmpty, nextInputCandidateCoordinator.hasCandidates {
                return selectNextInputCandidate(offset: 1, client: sender)
            }
            return false
        }

        guard flags.isEmpty else { return false }
        guard !currentCandidates.isEmpty else {
            // Fuzzy candidates are then the only candidates to choose
            if !fuzzyCandidateSession.isEmpty {
                return selectFuzzyCandidate(index: 0, client: sender)
            }
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
        replaceInputBuffer(reading, cursorPosition: reading.count)
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
        dictionaryRuntime.readings(for: candidate)
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

    private func beginDictionaryRegistration(client sender: Any) -> Bool {
        guard let reading = UserDictionaryRegistrationReading.resolve(
            conversionReading: conversionReading,
            originalInput: inputBuffer
        ) else {
            NSSound.beep()
            return true
        }
        let registration = DictionaryRegistrationSession(
            originalInput: inputBuffer,
            reading: reading
        )
        dictionaryRegistrationSession = registration
        clearInputBuffer()
        clearCandidateState()
        previewWindow.hide()
        setMarkedText("", in: sender)
        showDictionaryRegistration(client: sender)
        return true
    }

    private func isDictionaryRegistrationShortcut(_ event: NSEvent) -> Bool {
        MyIMFeatureShortcut.dictionaryRegistration.shortcut.matches(event)
    }

    private func handleDictionaryRegistration(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool {
        guard var registration = dictionaryRegistrationSession else {
            return false
        }

        if isDictionaryRegistrationShortcut(event) {
            return toggleDictionaryRegistrationField(
                registration: &registration,
                client: sender
            )
        }

        if handleInputFormFunctionKey(event, client: sender) {
            return true
        }

        switch event.keyCode {
        case 36, 76:
            return confirmDictionaryRegistration(client: sender)
        case 49:
            if inputBuffer.isEmpty,
               registration.pastedCandidate == nil {
                registration.appendSpace()
                dictionaryRegistrationSession = registration
                setMarkedText(registration.confirmedCandidate ?? "", in: sender)
                showDictionaryRegistration(client: sender)
                return true
            }
            let currentCandidate = registration.pastedCandidate
                ?? selectedCandidateValue
                ?? inputBuffer
            if registration.pastedCandidate == nil,
               selectedCandidateValue != nil {
                recordSelectedCandidate()
            }
            registration.appendConfirmed(
                currentCandidate,
                trailingSpace: true
            )
            dictionaryRegistrationSession = registration
            clearInputBuffer()
            clearCandidateState()
            setMarkedText(registration.confirmedCandidate ?? "", in: sender)
            showDictionaryRegistration(client: sender)
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
               registration.deleteBackwardFromConfirmed(
                   unit: deletionUnit(for: event)
               ) {
                dictionaryRegistrationSession = registration
                setMarkedText(
                    registration.confirmedCandidate ?? "",
                    in: sender
                )
                showDictionaryRegistration(client: sender)
                return true
            }
            registration.discardPendingPaste()
            dictionaryRegistrationSession = registration
            if inputBuffer.isEmpty {
                return true
            }
            return deleteBackward(
                from: sender,
                unit: deletionUnit(for: event)
            )
        case 53:
            cancelDictionaryRegistration(client: sender)
            return true
        default:
            break
        }

        if isPasteShortcut(event) {
            let pasted = NSPasteboard.general.string(forType: .string) ?? ""
            guard !pasted.isEmpty else {
                NSSound.beep()
                return true
            }
            registration.replacePendingPaste(with: pasted)
            dictionaryRegistrationSession = registration
            clearInputBuffer()
            clearCandidateState()
            setMarkedText(
                (registration.confirmedCandidate ?? "") + pasted,
                in: sender
            )
            showDictionaryRegistration(client: sender)
            return true
        }

        guard let characters = event.characters,
              UserDictionaryInputPolicy.accepts(
                  characters,
                  hasCommandModifier: event.modifierFlags.contains(.command),
                  hasControlModifier: event.modifierFlags.contains(.control)
              ) else {
            return true
        }
        registration.absorbPendingPaste()
        if let selectedValue = selectedCandidateValue {
            recordSelectedCandidate()
            registration.appendConfirmed(selectedValue)
            clearInputBuffer()
            clearCandidateState()
        }
        dictionaryRegistrationSession = registration
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

    private func confirmDictionaryRegistration(client sender: Any) -> Bool {
        guard var registration = dictionaryRegistrationSession else {
            return false
        }
        let currentCandidate = selectedCandidateValue
            ?? inputBuffer.nilIfEmpty
        if currentCandidate == nil,
           let completion = registration.completionAbsorbingPendingPaste() {
            do {
                try saveUserDictionaryEntry(
                    reading: completion.reading,
                    candidate: completion.output,
                    display: completion.display
                )
                dictionaryRegistrationSession = nil
                commit(
                    completion.output,
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
            dictionaryRegistrationSession = registration
            setMarkedText(registration.confirmedCandidate ?? "", in: sender)
            showDictionaryRegistration(client: sender)
            NSSound.beep()
            return true
        }
        if selectedCandidateValue != nil {
            recordSelectedCandidate()
        }
        registration.appendConfirmed(currentCandidate)
        dictionaryRegistrationSession = registration
        clearInputBuffer()
        clearCandidateState()
        setMarkedText(registration.confirmedCandidate ?? "", in: sender)
        showDictionaryRegistration(client: sender)
        return true
    }

    private func cancelDictionaryRegistration(client sender: Any) {
        guard let registration = dictionaryRegistrationSession else { return }
        dictionaryRegistrationSession = nil
        replaceInputBuffer(
            registration.originalInput,
            cursorPosition: registration.originalInput.count
        )
        clearCandidateState()
        updateMarkedText(in: sender)
        refreshCandidates(client: sender)
    }

    private func toggleDictionaryRegistrationField(
        registration: inout DictionaryRegistrationSession,
        client sender: Any
    ) -> Bool {
        let pending = registration.pastedCandidate
            ?? selectedCandidateValue
            ?? inputBuffer.nilIfEmpty
        if registration.pastedCandidate == nil,
           selectedCandidateValue != nil {
            recordSelectedCandidate()
        }
        registration.toggleInputField(absorbing: pending)
        dictionaryRegistrationSession = registration
        clearInputBuffer()
        clearCandidateState()
        setMarkedText(registration.confirmedCandidate ?? "", in: sender)
        showDictionaryRegistration(client: sender)
        return true
    }

    private func showDictionaryRegistration(client sender: Any) {
        guard let registration = dictionaryRegistrationSession else {
            return
        }
        let pending = registration.pastedCandidate ?? inputBuffer.nilIfEmpty
        let fields: [(DictionaryRegistrationInputField, String, String)] = [
            (.displayText, "表示", registration.displayText(pending: pending)),
            (
                .insertedText,
                "挿入",
                registration.visibleInsertedText(pending: pending)
            )
        ]
        let activeRow = fields.firstIndex {
            $0.0 == registration.activeInputField
        }
        logPanelSnapshot(event: "candidatePanel.beforeShow", sender: sender)
        primaryCandidatePanel.show(
            candidates: ["読み: \(registration.reading)"] + fields.map {
                "\($0.1): \($0.2)"
            },
            inputCaretIndicators: [false] + fields.map {
                $0.0 == registration.activeInputField
            },
            selectedIndex: activeRow.map { $0 + 1 },
            near: inputLocation(for: sender),
            isAccented: true
        )
    }

    private func shouldSuppressActivationSpace(_ event: NSEvent) -> Bool {
        let switchModifiers: NSEvent.ModifierFlags = [
            .command, .control, .option
        ]
        if !event.modifierFlags.intersection(switchModifiers).isEmpty {
            return true
        }
        return lifecycleCoordinator.isWithinActivationKeyWindow()
    }

    private func moveCandidate(
        _ direction: CandidateNavigationDirection,
        client sender: Any
    ) -> Bool {
        guard !inputBuffer.isEmpty else {
            return moveNextInputCandidate(direction, client: sender)
        }

        return moveDisplayedCandidate(direction, client: sender)
    }

    private func moveDisplayedCandidate(
        _ direction: CandidateNavigationDirection,
        client sender: Any
    ) -> Bool {

        guard !currentCandidates.isEmpty else {
            return true
        }

        guard let selectedCandidateIndex else {
            return selectCandidate(index: 0, client: sender)
        }

        let fallbackOffset: Int
        switch direction {
        case .left:
            fallbackOffset = -1
        case .right:
            fallbackOffset = 1
        case .up:
            fallbackOffset = -1
        case .down:
            fallbackOffset = 1
        }
        guard let nextIndex = LinearCandidateNavigator.index(
            from: selectedCandidateIndex,
            offset: fallbackOffset,
            candidateCount: currentCandidates.count
        ) else { return true }
        return selectCandidate(index: nextIndex, client: sender)
    }

    private func selectCandidate(index: Int, client sender: Any) -> Bool {
        guard currentCandidates.indices.contains(index) else {
            return true
        }
        let candidate = currentCandidateModels[index]
        selectedCandidateIndex = index
        selectedFuzzyCandidateIndex = nil
        showPrimaryCandidatePanel(client: sender)
        let registrationPrefix = dictionaryRegistrationSession?
            .confirmedCandidate ?? compositionPrefix
        setMarkedText(
            CandidateSelectionProjection.markedText(
                for: candidate,
                prefix: registrationPrefix,
                suffix: conversionSuffix + compositionSuffix
            ),
            in: sender
        )
        showPreview(for: candidate.storageText)
        if !translationCandidateSession.contains(
            candidate.storageText,
            in: .standard
        ) {
            updateTranslationCandidates(
                for: candidate.commitText,
                destination: .standard,
                client: sender
            )
        }
        return true
    }

    private func enterFuzzyCandidatesOrConsumeArrow(client sender: Any) -> Bool {
        guard let index = fuzzyCandidateSession
            .indexAlignedWithStandardCandidate(
                standardSelectedIndex: selectedCandidateIndex,
                maximumCount: Self.maximumCandidateCount
            ) else {
            noteNavigation("enterFuzzy.consumedWithoutFuzzyCandidates")
            return true
        }
        noteNavigation("enterFuzzy index=\(index)")
        return selectFuzzyCandidate(
            index: index,
            client: sender
        )
    }

    private func isCandidateFilterShortcut(_ event: NSEvent) -> Bool {
        MyIMFeatureShortcut.candidateFilter.shortcut.matches(event)
    }

    private func isCalendarShortcut(_ event: NSEvent) -> Bool {
        MyIMFeatureShortcut.calendar.shortcut.matches(event)
    }

    private func isEmojiShortcut(_ event: NSEvent) -> Bool {
        if UserDefaults.standard.object(
            forKey: MyIMFeatureShortcut.emoji.defaultsKey
        ) == nil {
            let modifiers = event.modifierFlags
                .intersection(.deviceIndependentFlagsMask)
                .subtracting([.capsLock, .numericPad])
            return event.keyCode == 14 && modifiers == [.option]
        }
        return MyIMFeatureShortcut.emoji.shortcut.matches(event)
    }

    private func toggleEmojiWindow(client sender: Any) {
        if emojiWindow.isVisible {
            EmojiDiagnostics.logger.notice("hiding emoji panel")
            clearCompositionForSystemPaste(in: sender)
            emojiWindow.hide()
            Self.emojiPanelController = nil
            return
        }
        EmojiDiagnostics.logger.notice("showing emoji panel")
        dismissNextInputCandidates(clearMarkedTextIn: sender)
        primaryCandidatePanel.hide()
        previewWindow.hide()
        emojiSearchLearning.reset()
        emojiWindow.show(near: inputLocation(for: sender))
        Self.emojiPanelController = self
        updateEmojiSearchFromComposition()
        if EmojiSearchActivationPolicy.startsInSelectionMode(
            searchText: emojiWindow.searchText
        ) {
            emojiWindow.confirmSearch()
        }
    }

    /// The composition is the search text of the emoji panel this
    /// controller opened
    private var isEditingEmojiSearch: Bool {
        emojiWindow.isVisible && Self.emojiPanelController === self
    }

    private func updateEmojiSearchFromComposition() {
        let searchText = selectedCandidateIndex.flatMap { index in
            currentCandidates.indices.contains(index)
                ? candidateDisplayValue(currentCandidates[index])
                : nil
        } ?? inputBuffer
        emojiSearchLearning.searchChanged(to: searchText)
        emojiWindow.updateSearchText(searchText)
    }

    /// Commits the emoji, registering it under the letters typed for the
    /// search like a learnable candidate chosen in ordinary conversion
    private func commitSelectedEmoji(_ emoji: String, to sender: Any) {
        if let reading = EmojiSearchRegistration.reading(
            typedInput: inputBuffer,
            conversionReading: conversionReading,
            isRecentEmoji: emojiWindow.selectedRecentEmoji != nil
        ) {
            recordCandidateSelection(
                emoji,
                reading: reading,
                isLearnable: true
            )
        }
        emojiWindow.recordUsage(emoji)
        emojiWindow.hide()
        commit(emoji, to: sender, replacingMarkedText: true)
    }

    private func confirmEmojiSearch(client sender: Any) {
        let chosenCandidate = selectedCandidateIndex.flatMap { index in
            currentCandidateModels.indices.contains(index)
                ? currentCandidateModels[index]
                : nil
        }
        let searchText = selectedCandidateIndex.flatMap { index in
            currentCandidates.indices.contains(index)
                ? candidateDisplayValue(currentCandidates[index])
                : nil
        } ?? inputBuffer
        // A search chosen from the conversion candidates is learned as the
        // same commit of that candidate would be
        if emojiSearchLearning.learns(
            confirming: searchText,
            choseCandidate: chosenCandidate != nil
        ), let chosenCandidate {
            recordCandidateSelectionForCurrentInput(chosenCandidate)
        }
        emojiWindow.updateSearchText(searchText)
        setMarkedText(searchText, in: sender)
        hideConversionPanels()
        emojiWindow.confirmSearch()
    }

    private func beginCalendarSelection(
        client sender: Any,
        anchorFrame: NSRect,
        returnApplication: NSRunningApplication?
    ) -> Bool {
        guard inputBuffer.isEmpty,
              dictionaryRegistrationSession == nil else {
            return true
        }
        dismissNextInputCandidates(clearMarkedTextIn: sender)
        primaryCandidatePanel.hide()
        emojiWindow.hide()
        previewWindow.hide()
        symbolTipsWindow.hide()
        candidateSearchCoordinator.cancel(.calendarFormat)
        calendarSelectionSession.beginCalendarSelection()
        guard let date = panelCoordinator.beginCalendarSelection(
            near: anchorFrame,
            returnTo: returnApplication
        ) else {
            trace("calendar.dateCancelled", sender: sender)
            clearCalendarSelection()
            primaryCandidatePanel.hide()
            return true
        }
        loadCalendarFormats(for: date, client: sender)
        return true
    }

    private func loadCalendarFormats(for date: Date, client sender: Any) {
        candidateSearchCoordinator.cancel(.calendarFormat)
        calendarSelectionSession.beginFormatLoading()
        primaryCandidatePanel.hide()
        trace(
            "calendar.formats.start",
            sender: sender,
            detail: "controller=\(ObjectIdentifier(self).hashValue)"
        )
        candidateSearchCoordinator.start(
            .calendarFormat,
            query: String(date.timeIntervalSinceReferenceDate),
            operation: {
                await Self.javaScriptExtensionClient
                    .calendarCandidates(for: date)
            },
            validate: { [weak self] in
                guard let self else { return false }
                guard self.calendarSelectionSession.isActive else {
                    self.trace(
                        "calendar.formats.rejected",
                        sender: sender,
                        detail: "reason=sessionInactive"
                    )
                    return false
                }
                return true
            },
            apply: { [weak self] candidates in
                guard let self else { return }
                self.trace(
                    "calendar.formats.complete",
                    sender: sender,
                    detail: "count=\(candidates.count)"
                )
                self.calendarSelectionSession.replaceCandidates(
                    self.candidatesOrderedByRecency(candidates)
                )
                self.showCalendarFormatCandidates(client: sender)
                guard let orderedCandidates = self.calendarSelectionSession
                    .candidates,
                      !orderedCandidates.isEmpty else {
                    return
                }
                guard let selectedIndex = self.panelCoordinator
                    .runCalendarFormatSelection(
                    candidateCount: orderedCandidates.count,
                    fallbackLocation: self.inputLocation(for: sender),
                    directionalSelection: { [weak self] index, direction in
                        self?.calendarFormatSelectionIndex(
                            from: index,
                            direction: direction,
                            candidateCount: orderedCandidates.count
                        )
                    },
                    selectionChanged: { [weak self] index in
                        guard let self else { return }
                        self.calendarSelectionSession.select(index: index)
                        self.showCalendarFormatCandidates(client: sender)
                    }
                ), orderedCandidates.indices.contains(selectedIndex) else {
                    self.clearCalendarSelection()
                    self.primaryCandidatePanel.hide()
                    return
                }
                let value = orderedCandidates[selectedIndex]
                self.recordCandidateSelection(value)
                self.clearCalendarSelection()
                self.commit(value, to: sender)
            },
            retainQueryAfterCompletion: false
        )
    }

    private func handleCalendarFormatSelection(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool {
        guard let candidates = calendarSelectionSession.candidates else {
            return false
        }
        switch event.keyCode {
        case 48:
            guard !candidates.isEmpty else { return true }
            let offset = event.modifierFlags.contains(.shift) ? -1 : 1
            calendarSelectionSession.moveSelection(by: offset)
            showCalendarFormatCandidates(client: sender)
        case 123, 124, 125, 126:
            guard !candidates.isEmpty else { return true }
            let direction: CandidateNavigationDirection = switch event.keyCode {
            case 123: .left
            case 124: .right
            case 125: .down
            default: .up
            }
            calendarSelectionSession.select(index: calendarFormatSelectionIndex(
                from: calendarSelectionSession.selectedIndex,
                direction: direction,
                candidateCount: candidates.count
            ))
            showCalendarFormatCandidates(client: sender)
        case 36, 76:
            guard let index = calendarSelectionSession.selectedIndex,
                  candidates.indices.contains(index) else {
                return true
            }
            let value = candidates[index]
            recordCandidateSelection(value)
            clearCalendarSelection()
            commit(value, to: sender)
        case 53:
            clearCalendarSelection()
            primaryCandidatePanel.hide()
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
        if let localNextIndex = primaryCandidatePanel.adjacentIndex(
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
        guard let candidates = calendarSelectionSession.candidates else {
            return
        }
        guard !candidates.isEmpty else {
            primaryCandidatePanel.hide()
            return
        }
        let pageRange = calendarSelectionSession.pageRange(
            pageSize: Self.maximumCandidateCount
        )
        primaryCandidatePanel.show(
            candidates: Array(candidates[pageRange]),
            selectedIndex: calendarSelectionSession.selectedIndex.map {
                $0 - pageRange.lowerBound
            },
            near: calendarInputLocation(for: sender)
        )
    }

    private func clearCalendarSelection(caller: String = #function) {
        if calendarSelectionSession.isActive {
            trace("calendar.clear", sender: client(), detail: "caller=\(caller)")
        }
        candidateSearchCoordinator.cancel(.calendarFormat)
        calendarSelectionSession.reset()
        panelCoordinator.clearCalendarPresentation()
    }

    private func calendarInputLocation(for sender: Any) -> NSRect {
        panelCoordinator.calendarInputLocation(
            fallback: inputLocation(for: sender)
        )
    }

    private func beginCandidateFilterInput(client sender: Any) -> Bool {
        guard !inputBuffer.isEmpty,
              candidateSession.unfilteredCandidates != nil
                || !currentCandidates.isEmpty else {
            return false
        }
        candidateSession.beginFiltering()
        Self.candidateFilterDatabaseCache.refreshIfChanged()
        cancelInputCandidateSearches()
        secondaryCandidatePanel.hide()
        previewWindow.hide()
        selectedCandidateIndex = nil
        showPrimaryCandidatePanel(client: sender)
        candidateFilterCoordinator.beginDraft()
        updateCandidateFilterChoices(client: sender)
        return true
    }

    private func handleCandidateFilterInput(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool {
        guard let draft = candidateFilterCoordinator.draft else { return false }
        switch event.keyCode {
        case 36, 76:
            if candidateFilterCoordinator.enterFilterStageForDirectInput(
                queryVariants: candidateFilterQueryVariants(for: draft.input)
            ) {
                updateCandidateFilterChoices(client: sender)
                return true
            }
            return applySelectedCandidateFilter(client: sender)
        case 48:
            moveCandidateFilterDraftSelection(by: 1, client: sender)
            return true
        case 123, 124, 125, 126:
            if let offset = CandidateFilterArrowNavigation.offset(
                forKeyCode: Int(event.keyCode)
            ) {
                moveCandidateFilterDraftSelection(by: offset, client: sender)
            }
            return true
        case 51:
            if candidateFilterCoordinator.deleteBackwardFromDraft() {
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
        candidateFilterCoordinator.appendToDraft(characters)
        updateCandidateFilterChoices(client: sender)
        return true
    }

    private func moveCandidateFilterDraftSelection(
        by offset: Int,
        client sender: Any
    ) {
        guard candidateFilterCoordinator.moveDraftSelection(by: offset) else {
            return
        }
        showCandidateFilterChoices(client: sender)
    }

    private func handleCandidateFilterEscape(client sender: Any) {
        switch candidateFilterCoordinator.escape(
            hasUnfilteredCandidates:
                candidateSession.unfilteredCandidates != nil
        ) {
        case .refreshDraftChoices:
            updateCandidateFilterChoices(client: sender)
        case .showFilteredCandidates:
            showFilteredCandidates(client: sender)
        case .restoreUnfilteredCandidates:
            restoreUnfilteredCandidatesAfterRemovingFilters(client: sender)
        case .inactive, .cancelDraft:
            break
        }
    }

    private func removeLastCandidateFilter(client sender: Any) {
        switch candidateFilterCoordinator.removeLastCondition(
            hasUnfilteredCandidates:
                candidateSession.unfilteredCandidates != nil
        ) {
        case .showFilteredCandidates:
            showFilteredCandidates(client: sender)
        case .restoreUnfilteredCandidates:
            restoreUnfilteredCandidatesAfterRemovingFilters(client: sender)
        case .inactive, .cancelDraft, .refreshDraftChoices:
            break
        }
    }

    private func restoreUnfilteredCandidatesAfterRemovingFilters(
        client sender: Any
    ) {
        _ = candidateSession.restoreUnfilteredCandidates()
        selectedCandidateIndex = nil
        resetCandidateFilters()
        updateMarkedText(in: sender)
        showPrimaryCandidatePanel(client: sender)
    }

    private func updateCandidateFilterChoices(client sender: Any) {
        candidateFilterCoordinator.refreshChoices(
            queryVariants: { [self] input in
                candidateFilterQueryVariants(for: input)
            },
            choiceGenerator: Self.candidateFilterChoiceGenerator
        )
        showCandidateFilterChoices(client: sender)
    }

    private func candidateFilterQueryVariants(for input: String) -> [String] {
        CandidateFilterQuerySource(
            userEngine: dictionaryRuntime.userEngine,
            basicEngine: dictionaryRuntime.basicEngine,
            systemEngine: dictionaryRuntime.systemEngine
        ).candidates(
            for: input,
            selectionHistory: candidateSelectionHistoryStore.snapshot
        )
    }

    private func showCandidateFilterChoices(client sender: Any) {
        guard let draft = candidateFilterCoordinator.draft,
              let page = candidateFilterCoordinator.visibleDraftPage(
                  maximumCount: Self.maximumCandidateCount
              ) else { return }
        if !primaryCandidatePanel.isVisible {
            showPrimaryCandidatePanel(client: sender)
        }
        candidateFilterDraftWindow.show(
            candidates: page.choices.map(\.label),
            selectedIndex: page.selectedIndex,
            near: inputLocation(for: sender),
            isAccented: true,
            reservesEmptyRow: true,
            minimumPanelText: draft.input.isEmpty ? "　" : draft.input
        )
        showCandidateFilterConditionPanels(client: sender)
        layoutCandidateFilterPanels()
    }

    private func applySelectedCandidateFilter(client sender: Any) -> Bool {
        guard let result = candidateFilterCoordinator.applySelectedChoice()
        else {
            return true
        }
        switch result {
        case let .convertedInput(value, reading):
            if let filterReading = CandidateFilterLearning.reading(
                for: reading
            ) {
                recordCandidateSelection(value, reading: filterReading)
            }
            updateCandidateFilterChoices(client: sender)
            return true
        case .conditionsChanged:
            showFilteredCandidates(client: sender)
            return true
        }
    }

    private func showFilteredCandidates(client sender: Any) {
        guard let unfilteredCandidates = candidateSession.unfilteredCandidates
        else { return }
        let filteredTexts = candidateFilterCoordinator.filteredCandidates(
            unfilteredCandidates.map(\.storageText),
            using: CandidateFilter(
                kanjiDatabase: Self.candidateFilterDatabaseCache.database
            ),
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
        candidateSession.applyFilteredTexts(filteredTexts)
        selectedCandidateIndex = nil
        updateMarkedText(in: sender)
        if currentCandidates.isEmpty {
            primaryCandidatePanel.hide()
            showCandidateFilterSummary(client: sender)
            return
        }
        showPrimaryCandidatePanel(client: sender)
        showCandidateFilterSummary(client: sender)
    }

    private func showCandidateFilterSummary(client sender: Any) {
        guard !candidateFilterCoordinator.conditions.isEmpty else {
            hideCandidateFilterConditionPanels()
            return
        }
        candidateFilterDraftWindow.hide()
        showCandidateFilterConditionPanels(client: sender)
        layoutCandidateFilterPanels()
    }

    private func showCandidateFilterConditionPanels(client sender: Any) {
        panelCoordinator.showFilterConditions(
            candidateFilterCoordinator.conditionLabels,
            near: inputLocation(for: sender)
        )
    }

    private func layoutCandidateFilterPanels() {
        panelCoordinator.layoutFilterPanels(
            includingDraft: candidateFilterCoordinator.draft != nil
        )
    }

    private func hideCandidateFilterConditionPanels() {
        panelCoordinator.hideFilterConditions()
    }

    private func resetCandidateFilters() {
        candidateSession.clearFilterBackup()
        candidateFilterCoordinator.reset()
        candidateFilterDraftWindow.hide()
        hideCandidateFilterConditionPanels()
    }

    private func refreshCandidates(client sender: Any) {
        let performanceClock = ContinuousClock()
        let refreshStart = performanceClock.now
        var reloadDuration = Duration.zero
        var englishDuration = Duration.zero
        var sourceDuration = Duration.zero
        var presentationDuration = Duration.zero
        trace("candidateGeneration.start", sender: sender)
        defer {
            trace(
                "candidateGeneration.complete",
                sender: sender,
                detail: "candidateCount=\(currentCandidates.count)"
            )
            let totalDuration = performanceClock.now - refreshStart
            if totalDuration >= Self.slowCandidateRefreshThreshold {
                Self.lifecycleLogger.notice(
                    "slow candidate refresh totalMs=\(Self.milliseconds(totalDuration), privacy: .public) reloadMs=\(Self.milliseconds(reloadDuration), privacy: .public) englishMs=\(Self.milliseconds(englishDuration), privacy: .public) sourceMs=\(Self.milliseconds(sourceDuration), privacy: .public) presentationMs=\(Self.milliseconds(presentationDuration), privacy: .public) candidateCount=\(self.currentCandidateModels.count, privacy: .public)"
                )
            }
        }
        guard !inputBuffer.isEmpty else {
            if emojiWindow.isVisible {
                EmojiDiagnostics.logger.notice(
                    "search emptied owner=\(Self.emojiPanelController?.controllerID ?? "nil", privacy: .public) controller=\(self.controllerID, privacy: .public) keepsPanel=\(self.isEditingEmojiSearch, privacy: .public)"
                )
            }
            clearCandidateState(includingFuzzy: true)
            dismissInputSessionPanels(
                using: isEditingEmojiSearch
                    ? .emojiSearchBecameEmpty
                    : .inputBecameEmpty
            )
            return
        }
        let reloadStart = performanceClock.now
        reloadUserDictionaryFromDiskIfNeeded()
        reloadDuration = performanceClock.now - reloadStart
        let input = conversionInput
        if !Self.diagnosticConfiguration.minimalMode {
            updatePostalAddressCandidatesIfNeeded(for: input)
        }
        let extensionInput = input
        let scriptCandidates = candidateSearchCoordinator.query(
            for: .javaScriptExtensions
        ) == extensionInput
            ? javaScriptExtensionCandidates
            : []
        defer {
            if Self.diagnosticConfiguration.enables(.jsExtensions) {
                updateJavaScriptExtensionCandidatesIfNeeded(
                    for: extensionInput
                )
            }
        }
        let specialContext = SpecialConversionCandidateContext(
            input: input,
            javaScriptCandidates: scriptCandidates,
            calculationHistoryCandidates: candidateSelectionHistoryStore
                .completions(for: input),
            postalAddressCandidates: candidateSearchCoordinator.query(
                for: .postalAddress
            ) == input ? postalAddressCandidates : []
        )
        if let result = specialConversionCandidateSource.result(
            for: specialContext
        ) {
            replaceCurrentCandidates(with: result.orderedCandidates(
                recencyRanks: candidateSelectionRanks(
                    for: candidateSelectionReading
                )
            ))
            showPrimaryCandidatePanel(client: sender)
            if result.showsSymbolTips {
                showSymbolTipsForCurrentInput(client: sender)
            }
            return
        }

        let externalSearchReading = conversionReading
        defer {
            updateExternalCandidatesIfNeeded(for: externalSearchReading)
        }

        let englishStart = performanceClock.now
        let englishCandidates = Self.featureSettings.isEnglishCompletionEnabled
            ? englishCompletions(for: conversionReading)
            : []
        englishDuration = performanceClock.now - englishStart
        let remoteCandidates = candidateSearchCoordinator.query(for: .external)
            == conversionReading
            ? externalCandidates
            : []
        let contextualCandidates = Self.featureSettings.isNextInputPredictionEnabled
            && Self.diagnosticConfiguration.enables(.nextInput)
            ? nextInputCandidateCoordinator.candidatesAfterLastInput(
                limit: NextInputPredictionModel.maximumFollowersPerContext
            )
            : []
        let standardSource = StandardConversionCandidateSource(
            userEngine: dictionaryRuntime.userDictionaryEngine,
            importedEngine: dictionaryRuntime.importedEngine,
            basicEngine: dictionaryRuntime.basicEngine,
            symbolEngine: Self.sharedSymbolConversionEngine,
            systemEngine: dictionaryRuntime.systemEngine,
            verbInflectionGenerator: dictionaryRuntime.verbInflectionGenerator,
            deferredSystemCandidates: Self.sharedDeferredSystemCandidates,
            verbConjugations: Self.sharedVerbConjugations,
            maximumSystemPrefixCandidates:
                Self.maximumMozcDictionaryPrefixCandidates
        )
        let sourceStart = performanceClock.now
        let orderedCandidates = standardSource.candidates(for: .init(
            input: input,
            conversionReading: conversionReading,
            javaScriptCandidates: scriptCandidates,
            externalCandidates: remoteCandidates,
            englishCandidates: englishCandidates,
            selectionHistory: candidateSelectionHistoryStore.snapshot,
            contextualCandidates: contextualCandidates,
            learningEnabled: Self.diagnosticConfiguration.enables(.learning)
        ))
        sourceDuration = performanceClock.now - sourceStart
        let presentationStart = performanceClock.now
        replaceCurrentCandidates(with: orderedCandidates)

        guard !currentCandidates.isEmpty else {
            selectedCandidateIndex = nil
            primaryCandidatePanel.hide()
            // A typo can leave no standard candidate, which is where
            // fuzzy candidates are needed most
            if secondaryCandidatePanel.isVisible {
                showInitialFuzzyCandidates()
            }
            updateFuzzyCandidatesIfNeeded()
            showInputPreview(client: sender)
            presentationDuration = performanceClock.now - presentationStart
            return
        }

        showPrimaryCandidatePanel(client: sender)
        updateFuzzyCandidatesIfNeeded()
        showInputPreview(client: sender)
        presentationDuration = performanceClock.now - presentationStart
    }

    private func replaceCurrentCandidates(with candidates: [String]) {
        replaceCurrentCandidates(with: candidates.map {
            Candidate(storageText: $0)
        })
    }

    private func replaceCurrentCandidates(with candidates: [Candidate]) {
        let hadSelection = selectedCandidateIndex != nil
        candidateSession.replace(
            with: candidates,
            input: conversionInput,
            reading: conversionReading
        )
        if hadSelection {
            trace(
                "candidateSelection.changed",
                sender: client(),
                detail: "standard=\(selectedCandidateIndex.map(String.init) ?? "none")"
            )
        }
        updateCandidateDeletionShortcutCapture()
    }

    private func updateFuzzyCandidatesIfNeeded() {
        guard Self.diagnosticConfiguration.enables(.fuzzyCandidate),
              Self.featureSettings.isFuzzyCandidatesEnabled,
              !conversionReading.isEmpty else {
            candidateSearchCoordinator.cancel(.fuzzy)
            secondaryCandidatePanel.hide()
            fuzzyCandidateSession.reset()
            selectedFuzzyCandidateIndex = nil
            return
        }
        let query = conversionReading
        guard candidateSearchCoordinator.query(for: .fuzzy) != query else {
            return
        }
        candidateSearchCoordinator.cancel(.fuzzy)
        let visibleCandidates = Set(currentCandidates)
        let learnedCompounds = nextInputCandidateCoordinator
            .learnedCompoundPredictions(
                matchingPrefix: query,
                excluding: visibleCandidates
            )
        let includesTypoCorrections = query.count >= 2
        guard includesTypoCorrections || !learnedCompounds.isEmpty else {
            candidateSearchCoordinator.cancel(.fuzzy)
            secondaryCandidatePanel.hide()
            fuzzyCandidateSession.reset()
            selectedFuzzyCandidateIndex = nil
            return
        }
        let source = FuzzyCandidateSource(
            query: query,
            visibleCandidates: visibleCandidates,
            userDictionary: dictionaryRuntime.userDictionaryEngine,
            importedDictionary: dictionaryRuntime.importedEngine,
            basicDictionary: dictionaryRuntime.basicEngine,
            mozcDictionary: dictionaryRuntime.systemEngine,
            fuzzyRepository: Self.fuzzyEngineRepository,
            learnedCompounds: learnedCompounds
        )
        guard let asyncSnapshot = currentInputSessionSnapshot() else {
            return
        }
        trace("candidateGeneration.start", sender: client(), detail: "source=fuzzy")
        candidateSearchCoordinator.start(
            .fuzzy,
            query: query,
            operation: {
                if includesTypoCorrections {
                    try await Task.sleep(for: .milliseconds(80))
                }
                let matchTiers = await source.matchTiers(
                    includesTypoCorrections: includesTypoCorrections
                )
                if includesTypoCorrections {
                    try await Task.sleep(for: Self.fuzzyCandidateDisplayDelay)
                }
                return matchTiers
            },
            validate: { [weak self] in
                guard let self else { return false }
                return self.conversionReading == query
                    && Self.featureSettings.isFuzzyCandidatesEnabled
                    && self.acceptsAsyncResult(
                        asyncSnapshot,
                        source: "fuzzy",
                        sender: self.client()
                    )
            },
            apply: { [weak self] matchTiers in
                guard let self else { return }
                self.trace(
                    "candidateGeneration.complete",
                    sender: self.client(),
                    detail: "source=fuzzy"
                )
                self.applyFuzzyCandidates(matchTiers)
            },
            onCancel: { [weak self] in
                self?.trace(
                    "candidateGeneration.cancel",
                    sender: self?.client(),
                    detail: "source=fuzzy"
                )
            },
            onError: { error in
                NSLog("誤入力補完に失敗: %@", error.localizedDescription)
            }
        )
    }

    private func applyFuzzyCandidates(
        _ matchTiers: [[FuzzyConversionMatch]]
    ) {
        let changed = fuzzyCandidateSession.replace(
            matchTiers: matchTiers,
            recencyRanks: candidateSelectionRanks(for: conversionReading),
            preserveSelectionWhenUnchanged: secondaryCandidatePanel.isVisible
        )
        updateCandidateDeletionShortcutCapture()
        if !changed, secondaryCandidatePanel.isVisible {
            return
        }
        trace(
            "candidateSelection.changed",
            sender: client(),
            detail: "fuzzy=none"
        )
        guard !fuzzyCandidateSession.isEmpty else {
            secondaryCandidatePanel.hide()
            return
        }
        showInitialFuzzyCandidates()
        if let inputClient = client() {
            showInputPreview(client: inputClient)
        }
    }

    private func showInitialFuzzyCandidates() {
        guard let page = fuzzyCandidateSession.initialPage(
                  maximumCount: Self.initialFuzzyCandidateCount
              ) else {
            secondaryCandidatePanel.hide()
            return
        }
        guard primaryCandidatePanel.visibleFrame != nil else {
            showFuzzyCandidatesWithoutStandardCandidates(page)
            return
        }
        secondaryCandidatePanel.show(
            candidates: page.candidates,
            selectedIndex: page.selectedIndex,
            near: primaryCandidatePanel.frame,
            avoidingFrames: [primaryCandidatePanel.frame]
                + primaryCandidatePanel.auxiliaryFrames,
            isAccented: false,
            prepareAnchor: prepareAnchorForSecondaryCandidatePanel
        )
    }

    /// Without standard candidates the secondary panel takes the primary panel's
    /// place below the input instead of leaving nothing on screen
    private func showFuzzyCandidatesWithoutStandardCandidates(
        _ page: FuzzyCandidatePage
    ) {
        guard let sender = client(),
              let inputFrame = locationCoordinator.candidateAnchor(
                for: sender
              ).location else {
            secondaryCandidatePanel.hide()
            return
        }
        let spacing = secondaryCandidatePanel.spacingFromCandidatePanel
        secondaryCandidatePanel.show(
            candidates: page.candidates,
            selectedIndex: page.selectedIndex,
            near: NSRect(
                x: inputFrame.minX - spacing,
                y: inputFrame.minY - Self.candidatePanelAnchorSpacing,
                width: 0,
                height: 0
            ),
            avoidingFrames: [inputFrame],
            isAccented: false
        )
    }

    private func handleFuzzyCandidateSelection(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool? {
        guard interactionState == .selectingFuzzyCandidate,
              let selectedCandidate = fuzzyCandidateSession
                .selectedCandidate else {
            return nil
        }
        switch event.keyCode {
        case 36, 76:
            return acceptFuzzyCandidate(
                selectedCandidate,
                suffix: "",
                client: sender
            )
        case 48, 125:
            guard let next = fuzzyCandidateSession.index(after: 1)
            else { return true }
            return selectFuzzyCandidate(index: next, client: sender)
        case 49:
            return acceptFuzzyCandidate(
                selectedCandidate,
                suffix: " ",
                client: sender
            )
        case 126:
            guard let next = fuzzyCandidateSession.index(after: -1)
            else { return true }
            return selectFuzzyCandidate(index: next, client: sender)
        case 123:
            noteNavigation("fuzzySelection.left")
            if shouldEnterTranslationCandidates(
                direction: .left,
                from: secondaryCandidatePanel.visibleFrame ?? primaryCandidatePanel.frame
            ) {
                return enterTranslationCandidates(client: sender)
            }
            return returnToStandardCandidateSelection(client: sender)
        case 124:
            noteNavigation("fuzzySelection.right")
            if shouldEnterTranslationCandidates(
                direction: .right,
                from: secondaryCandidatePanel.visibleFrame ?? primaryCandidatePanel.frame
            ) {
                return enterTranslationCandidates(client: sender)
            }
            return returnToStandardCandidateSelection(client: sender)
        case 53:
            return returnToStandardCandidateSelection(client: sender)
        case 51:
            self.selectedFuzzyCandidateIndex = nil
            secondaryCandidatePanel.hide()
            return nil
        default:
            let flags = event.modifierFlags.intersection([
                .command, .control, .option
            ])
            guard flags.isEmpty,
                  let characters = event.characters,
                  !characters.isEmpty else {
                return false
            }
            _ = acceptFuzzyCandidate(
                selectedCandidate,
                suffix: "",
                client: sender
            )
            return nil
        }
    }

    private func returnToStandardCandidateSelection(client sender: Any) -> Bool {
        if let standardIndex = fuzzyCandidateSession
            .standardCandidateIndexAlignedWithSelection(
                standardCandidateCount: currentCandidates.count,
                currentNormalIndex: selectedCandidateIndex,
                maximumCount: Self.maximumCandidateCount
            ) {
            selectedCandidateIndex = standardIndex
        }
        selectedFuzzyCandidateIndex = nil
        // Translations of the fuzzy candidate open on the other side and no
        // longer have a source, even when the candidate is not translated
        if translationCandidateSession.visibleChannel == .fuzzy {
            cancelCandidateTranslation()
            hideTranslationCandidatePanels()
        }
        if let selectedCandidateIndex,
           currentCandidateModels.indices.contains(selectedCandidateIndex) {
            // Selected as in the primary panel, which also makes it the
            // translation source and the preview
            _ = selectCandidate(index: selectedCandidateIndex, client: sender)
        } else {
            updateMarkedText(in: sender)
            showPrimaryCandidatePanel(client: sender)
        }
        // Whatever is still shown must translate the candidate selected now
        // or be on its way to it; otherwise it belongs to another candidate
        if translationCandidateSession.hasVisibleCandidates,
           !(currentTranslationSource.map(
                translationCandidateSession.isShowingTranslations(of:)
           ) ?? false),
           candidateSearchCoordinator.query(for: .translation)
                != currentTranslationSource?.text {
            noteNavigation("returnToStandard.closeStaleTranslations")
            hideTranslationCandidatePanels()
        }
        // The secondary panel keeps its rows until it is shown again, so it
        // is redrawn without the highlight; it is placed only beside a
        // primary panel already on screen and otherwise waits for the
        // primary panel, which shows it again once the input location is known
        if primaryCandidatePanel.visibleFrame != nil {
            showInitialFuzzyCandidates()
        } else {
            secondaryCandidatePanel.hide()
        }
        noteNavigation(
            "returnToStandard standard=\(selectedCandidateIndex.map(String.init) ?? "none") secondaryVisible=\(secondaryCandidatePanel.isVisible)"
        )
        return true
    }

    private func isFuzzyCandidateEntryShortcut(_ event: NSEvent) -> Bool {
        let flags = event.modifierFlags.intersection(
            [.command, .control, .option, .shift]
        )
        return event.keyCode == 48 && flags == [.shift]
    }

    private func acceptFuzzyCandidate(
        _ fuzzyCandidate: FuzzyCandidate,
        suffix: String,
        client sender: Any
    ) -> Bool {
        if let entry = fuzzyCandidate.userDictionaryEntry {
            do {
                try saveUserDictionaryEntry(
                    reading: entry.reading,
                    candidate: entry.candidate
                )
            } catch {
                NSLog(
                    "曖昧候補のユーザー辞書登録に失敗: %@",
                    error.localizedDescription
                )
            }
        }
        if fuzzyCandidate.isLearnable {
            candidateSelectionHistoryStore.record(
                fuzzyCandidate.storageText,
                readings: [conversionReading, fuzzyCandidate.reading]
            )
        }
        let value = fuzzyCandidate.storageText + conversionSuffix
        let punctuation = compositionSuffix
        let sourceTokens = fuzzyCandidate.sourceTokens.isEmpty
            ? nil
            : fuzzyCandidate.sourceTokens
        // The space committed with the candidate is part of what was typed,
        // as with the standard candidates; text after the candidate keeps
        // it from following the candidate directly
        let learnedSeparator = conversionSuffix.isEmpty ? suffix : ""
        let historyTokens = learnedSeparator.isEmpty
            ? sourceTokens
            : NextInputLearningToken.texts(
                sourceTokens ?? [fuzzyCandidate.storageText],
                followedBy: learnedSeparator
            )
        commit(
            value + suffix,
            to: sender,
            historyValue: fuzzyCandidate.storageText,
            historyTokens: historyTokens,
            historyReadings: sourceTokens == nil
                ? nil
                : fuzzyCandidate.sourceReadings,
            historyReading: fuzzyCandidate.reading,
            historyLearningSource: sourceTokens == nil
                ? .directInput
                : .acceptedCandidate
        )
        continueWithTrailingPunctuation(punctuation, client: sender)
        return true
    }

    private func removeSelectedFuzzyCandidateFromUserDictionary(
        client sender: Any
    ) {
        guard let fuzzyCandidate = fuzzyCandidateSession.selectedCandidate
        else {
            NSSound.beep()
            return
        }
        if !fuzzyCandidate.isLearnable, !fuzzyCandidate.sourceTokens.isEmpty {
            do {
                try nextInputCandidateCoordinator.suppressLearnedCandidate(
                    fuzzyCandidate.storageText
                )
                candidateSelectionHistoryStore.remove([fuzzyCandidate.storageText])
                unselectedInputLearningStore.remove(
                    candidate: fuzzyCandidate.storageText
                )
                candidateSearchCoordinator.cancel(.fuzzy)
                fuzzyCandidateSession.reset()
                selectedFuzzyCandidateIndex = nil
                updateMarkedText(in: sender)
                refreshCandidates(client: sender)
            } catch {
                NSLog(
                    "学習済み連結候補の削除保存に失敗: %@",
                    error.localizedDescription
                )
                NSSound.beep()
            }
            return
        }
        guard userDictionaryStore.canRemove(
            candidate: fuzzyCandidate.storageText,
            matchingReadings: [fuzzyCandidate.reading]
        ) else {
            NSSound.beep()
            return
        }
        do {
            try userDictionaryStore.remove(
                candidate: fuzzyCandidate.storageText,
                matchingReadings: [fuzzyCandidate.reading]
            )
            unselectedInputLearningStore.remove(
                candidate: fuzzyCandidate.storageText
            )
            rebuildConversionEngine()
            candidateSelectionHistoryStore.remove([fuzzyCandidate.storageText])
            self.selectedFuzzyCandidateIndex = nil
            updateMarkedText(in: sender)
            refreshCandidates(client: sender)
        } catch {
            NSLog(
                "曖昧候補のユーザー辞書削除に失敗: %@",
                error.localizedDescription
            )
            userDictionaryStore.restore(Self.loadUserEntries())
            rebuildConversionEngine()
            NSSound.beep()
        }
    }

    private func selectFuzzyCandidate(index: Int, client sender: Any) -> Bool {
        guard let fuzzyCandidate = fuzzyCandidateSession.select(index: index),
              let resolvedIndex = fuzzyCandidateSession.selectedIndex
        else { return true }
        trace(
            "candidateSelection.changed",
            sender: client(),
            detail: "fuzzy=\(resolvedIndex)"
        )
        updateCandidateDeletionShortcutCapture()
        primaryCandidatePanel.clearSelection()
        let displayValue = fuzzyCandidate.storageText + conversionSuffix
            + compositionSuffix
        setMarkedText(
            displayValue,
            in: sender
        )
        showFuzzyCandidatePage(selectedIndex: resolvedIndex, client: sender)
        showPreview(for: fuzzyCandidate.storageText)
        if !translationCandidateSession.contains(
            fuzzyCandidate.storageText,
            in: .fuzzy
        ) {
            updateTranslationCandidates(
                for: fuzzyCandidate.storageText,
                destination: .fuzzy(reading: fuzzyCandidate.reading),
                client: sender
            )
        }
        return true
    }

    private func showFuzzyCandidatePage(
        selectedIndex: Int,
        client sender: Any
    ) {
        guard fuzzyCandidateSession.selectedIndex == selectedIndex,
              let page = fuzzyCandidateSession.selectedPage(
                  maximumCount: Self.maximumCandidateCount
              ) else { return }
        guard primaryCandidatePanel.visibleFrame != nil else {
            showFuzzyCandidatesWithoutStandardCandidates(page)
            return
        }
        secondaryCandidatePanel.show(
            candidates: page.candidates,
            selectedIndex: page.selectedIndex,
            near: primaryCandidatePanel.frame,
            avoidingFrames: [primaryCandidatePanel.frame]
                + primaryCandidatePanel.auxiliaryFrames,
            isAccented: false,
            prepareAnchor: prepareAnchorForSecondaryCandidatePanel
        )
    }

    private func prepareAnchorForSecondaryCandidatePanel(
        width: CGFloat,
        spacing: CGFloat
    ) -> NSRect {
        panelCoordinator.prepareAnchorForSecondaryCandidatePanel(
            width: width,
            spacing: spacing
        )
    }

    private func alignSecondaryCandidatePanelToPrimary() {
        panelCoordinator.alignSecondaryCandidatePanelToPrimary()
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

    private func updateExternalCandidatesIfNeeded(for input: String) {
        guard !Self.diagnosticConfiguration.minimalMode,
              Self.featureSettings.isWikipediaSuggestionsEnabled
                || Self.featureSettings.isGoogleJapaneseInputEnabled,
              input.count >= 2,
              candidateSearchCoordinator.query(for: .external) != input else {
            return
        }
        externalCandidates = []
        let japaneseInput = romajiConverter.hiragana(from: input) ?? input
        guard let asyncSnapshot = currentInputSessionSnapshot() else {
            return
        }
        var enabledSources: [any CandidateSource] = []
        if Self.featureSettings.isWikipediaSuggestionsEnabled {
            enabledSources.append(WikipediaCandidateSource())
        }
        if Self.featureSettings.isGoogleJapaneseInputEnabled {
            enabledSources.append(GoogleJapaneseInputCandidateSource())
        }
        let sources = enabledSources
        let context = CandidateSourceContext(
            input: inputBuffer,
            conversionReading: input,
            japaneseReading: japaneseInput
        )
        candidateSearchCoordinator.start(
            .external,
            query: input,
            operation: {
                try await Task.sleep(for: .milliseconds(250))
                return await CandidateSourceCollector.candidates(
                    from: sources,
                    context: context
                )
            },
            validate: { [weak self] in
                guard let self else { return false }
                return (Self.featureSettings.isWikipediaSuggestionsEnabled
                    || Self.featureSettings.isGoogleJapaneseInputEnabled)
                    && self.conversionReading == input
                    && self.acceptsAsyncResult(
                        asyncSnapshot,
                        source: "externalCandidates",
                        sender: self.client()
                    )
            },
            apply: { [weak self] candidates in
                guard let self else { return }
                guard CandidateResultUpdatePolicy.changes(
                    current: self.externalCandidates,
                    updated: candidates
                ) else {
                    return
                }
                self.externalCandidates = candidates
                if let inputClient = self.client() {
                    self.refreshCandidates(client: inputClient)
                }
            },
            onCancel: { [weak self] in
                self?.trace(
                    "candidateGeneration.cancel",
                    sender: self?.client(),
                    detail: "source=externalCandidates"
                )
            },
            onError: { error in
                NSLog(
                    "公式外部候補の取得に失敗: %@",
                    error.localizedDescription
                )
            }
        )
    }

    private func updateJavaScriptExtensionCandidatesIfNeeded(for input: String) {
        guard Self.diagnosticConfiguration.enables(.jsExtensions),
              !input.isEmpty,
              candidateSearchCoordinator.query(for: .javaScriptExtensions)
                != input else {
            return
        }
        guard let asyncSnapshot = currentInputSessionSnapshot() else {
            return
        }
        javaScriptExtensionCandidates = []
        let dateTimeCandidatesEnabled = Self.featureSettings.isDateTimeCandidatesEnabled
        candidateSearchCoordinator.start(
            .javaScriptExtensions,
            query: input,
            operation: {
                await Self.javaScriptExtensionClient.candidates(
                    for: input,
                    dateTimeCandidatesEnabled: dateTimeCandidatesEnabled
                )
            },
            validate: { [weak self] in
                guard let self else { return false }
                return self.inputBuffer == input
                    && self.acceptsAsyncResult(
                        asyncSnapshot,
                        source: "jsExtensions",
                        sender: self.client()
                    )
            },
            apply: { [weak self] candidates in
                guard let self else { return }
                guard CandidateResultUpdatePolicy.changes(
                    current: self.javaScriptExtensionCandidates,
                    updated: candidates
                ) else {
                    return
                }
                self.javaScriptExtensionCandidates = candidates
                if let inputClient = self.client() {
                    self.refreshCandidates(client: inputClient)
                }
            }
        )
    }

    private func updatePostalAddressCandidatesIfNeeded(for input: String) {
        guard !Self.diagnosticConfiguration.minimalMode else { return }
        guard let postalCode = PostalCodeNormalizer.normalize(input) else {
            candidateSearchCoordinator.cancel(.postalAddress)
            postalAddressCandidates = []
            return
        }
        guard candidateSearchCoordinator.query(for: .postalAddress) != input else {
            return
        }
        guard let asyncSnapshot = currentInputSessionSnapshot() else {
            return
        }
        if let cached = postalAddressCache[postalCode] {
            candidateSearchCoordinator.activate(
                .postalAddress,
                query: input
            )
            postalAddressCandidates = cached
            return
        }
        postalAddressCandidates = []
        candidateSearchCoordinator.start(
            .postalAddress,
            query: input,
            operation: {
                (try? await PostalAddressCandidateClient()
                    .candidates(for: postalCode)) ?? []
            },
            validate: { [weak self] in
                guard let self else { return false }
                return self.inputBuffer == input
                    && self.acceptsAsyncResult(
                        asyncSnapshot,
                        source: "postalAddress",
                        sender: self.client()
                    )
            },
            apply: { [weak self] candidates in
                guard let self else { return }
                self.postalAddressCache[postalCode] = candidates
                guard CandidateResultUpdatePolicy.changes(
                    current: self.postalAddressCandidates,
                    updated: candidates
                ) else {
                    return
                }
                self.postalAddressCandidates = candidates
                if let inputClient = self.client() {
                    self.refreshCandidates(client: inputClient)
                }
            }
        )
    }

    private func updateTranslationCandidates(
        for source: String,
        destination: TranslationCandidateDestination,
        client sender: Any
    ) {
        cancelCandidateTranslation()
        candidateSearchCoordinator.cancel(.external)
        candidateSearchCoordinator.cancel(.javaScriptExtensions)
        if case .fuzzy = destination {
            candidateSearchCoordinator.cancel(.fuzzy)
        }
        let translates = Self.diagnosticConfiguration.enables(.translation)
            && Self.featureSettings.isAppleTranslationEnabled
            && source.containsJapaneseText
            && !Self.featureSettings.translationTargetLanguages.isEmpty
        if translationCandidateSession.transition(
            toSourceIn: destination.channel,
            translates: translates
        ) == .close {
            logTranslationDiagnostics(
                "close previous=\(translationCandidateSession.visibleChannel.map { "\($0)" } ?? "none") next=\(destination.channel)"
            )
            hideTranslationCandidatePanels()
        }
        guard translates else {
            logTranslationDiagnostics(
                "skip untranslated channel=\(destination.channel)"
            )
            return
        }
        logTranslationDiagnostics("start channel=\(destination.channel)")
        panelCoordinator.reserveTranslationCandidateSpace(
            languageCount: Self.featureSettings.translationTargetLanguages.count,
            onLeft: destination.channel.extendsLeft
        )
        guard let asyncSnapshot = currentInputSessionSnapshot() else {
            return
        }
        trace("translation.start", sender: sender, detail: "source=\(source)")
        let translationSource = AppleTranslationCandidateSource(
            targetIdentifiers: Self.featureSettings.translationTargetLanguages.map(\.identifier)
        )
        candidateSearchCoordinator.start(
            .translation,
            query: source,
            operation: {
                try await translationSource
                    .groups(for: source)
            },
            validate: { [weak self] in
                guard let self else { return false }
                // The result belongs to the candidate selected now, in the
                // same candidate group
                let sourceIsStillSelected = self.currentTranslationSource
                    == TranslationSource(
                        text: source,
                        channel: destination.channel
                    )
                self.logTranslationDiagnostics(
                    "result \(sourceIsStillSelected ? "accepted" : "rejected") channel=\(destination.channel)"
                )
                return sourceIsStillSelected
                    && self.acceptsAsyncResult(
                        asyncSnapshot,
                        source: "translation",
                        sender: sender
                    )
            },
            apply: { [weak self] groups in
                guard let self else { return }
                self.trace(
                    "translation.complete",
                    sender: sender,
                    detail: "source=\(source) languages=\(groups.map(\.targetIdentifier)) count=\(groups.map(\.candidates.count))"
                )
                let channel = destination.channel
                self.translationCandidateSession.store(
                    groups,
                    for: source,
                    channel: channel
                )
                switch destination {
                case .standard:
                    self.showPrimaryCandidatePanel(client: sender)
                    guard self.primaryCandidatePanel.visibleFrame != nil else {
                        self.hideTranslationCandidatePanels()
                        return
                    }
                    let sourceRow = self.selectedCandidateIndex.map {
                        $0 % Self.maximumCandidateCount
                    } ?? 0
                    self.showTranslationCandidatePanels(
                        groups,
                        for: source,
                        beside: self.primaryCandidatePanel.rowFrame(at: sourceRow)
                            ?? self.primaryCandidatePanel.frame,
                        channel: channel,
                        client: sender
                    )
                case .fuzzy:
                    _ = self.fuzzyCandidateSession.select(
                        candidate: source
                    )
                    self.updateCandidateDeletionShortcutCapture()
                    self.trace(
                        "candidateSelection.changed",
                        sender: self.client(),
                        detail: "fuzzy=\(self.selectedFuzzyCandidateIndex.map(String.init) ?? "none")"
                    )
                    if let index = self.selectedFuzzyCandidateIndex {
                        self.showFuzzyCandidatePage(
                            selectedIndex: index,
                            client: sender
                        )
                    }
                    guard self.secondaryCandidatePanel.visibleFrame != nil else {
                        self.hideTranslationCandidatePanels()
                        return
                    }
                    self.showTranslationCandidatePanels(
                        groups,
                        for: source,
                        beside: self.selectedFuzzyCandidateIndex.flatMap {
                            self.secondaryCandidatePanel.rowFrame(
                                at: $0 % Self.maximumCandidateCount
                            )
                        } ?? self.secondaryCandidatePanel.visibleFrame
                            ?? self.primaryCandidatePanel.frame,
                        channel: channel,
                        client: sender
                    )
                }
            },
            retainQueryAfterCompletion: false
        )
    }

    private func cancelCandidateTranslation() {
        if candidateSearchCoordinator.query(for: .translation) != nil {
            trace(
                "candidateGeneration.cancel",
                sender: client(),
                detail: "source=translation"
            )
        }
        candidateSearchCoordinator.cancel(.translation)
    }

    /// Shows one panel per language in setting order; a source without
    /// translations closes the previous source's panels
    private func showTranslationCandidatePanels(
        _ groups: [TranslationCandidateGroup],
        for source: String,
        beside sourceFrame: NSRect,
        channel: TranslationCandidateChannel,
        client sender: Any
    ) {
        let visibleGroups = groups.map {
            $0.prefix(Self.maximumCandidateCount)
        }
        let shownCount = panelCoordinator.showTranslationCandidates(
            TranslationPanelContent.panels(
                for: visibleGroups,
                configuredLanguageCount: Self.featureSettings
                    .translationTargetLanguages.count
            ).map {
                (candidates: $0.candidates, caption: $0.caption)
            },
            beside: sourceFrame,
            onLeft: channel.extendsLeft,
            near: inputLocation(for: sender)
        )
        translationCandidateSession.show(
            Array(visibleGroups.prefix(shownCount)),
            channel: channel,
            source: source
        )
    }

    private func hideTranslationCandidatePanels() {
        translationCandidateSession.show([], channel: .standard)
        panelCoordinator.hideTranslationCandidates()
    }

    private func shouldEnterTranslationCandidates(
        direction: CandidateNavigationDirection,
        from sourceFrame: NSRect
    ) -> Bool {
        // Only translations of the candidate selected now are entered;
        // panels left from another candidate are never a destination
        guard let source = currentTranslationSource,
              translationCandidateSession.isShowingTranslations(of: source),
              let nearestFrame = panelCoordinator
                .visibleTranslationCandidateFrames.first else {
            noteNavigation(
                "shouldEnterTranslation=false showsCurrentSource=\(currentTranslationSource.map(translationCandidateSession.isShowingTranslations(of:)) ?? false)"
            )
            return false
        }
        return nearestFrame.midX < sourceFrame.midX
            ? direction == .left
            : direction == .right
    }

    /// The candidate selected now: the fuzzy candidate while the secondary
    /// panel is selected, otherwise the standard candidate
    private var currentTranslationSource: TranslationSource? {
        if let fuzzy = fuzzyCandidateSession.selectedCandidate {
            return TranslationSource(text: fuzzy.storageText, channel: .fuzzy)
        }
        guard let selectedCandidateIndex,
              currentCandidateModels.indices.contains(selectedCandidateIndex)
        else {
            return nil
        }
        return TranslationSource(
            text: currentCandidateModels[selectedCandidateIndex].commitText,
            channel: .standard
        )
    }

    /// Entering from the source starts at the top of the nearest panel
    private func enterTranslationCandidates(client sender: Any) -> Bool {
        guard let candidate = translationCandidateSession.select(
            TranslationCandidateSelection(groupIndex: 0, candidateIndex: 0),
            returningToFuzzy: selectedFuzzyCandidateIndex != nil
        ) else {
            return true
        }
        return showTranslationCandidateSelection(candidate, client: sender)
    }

    private func showTranslationCandidateSelection(
        _ candidate: Candidate,
        client sender: Any
    ) -> Bool {
        // The source stays selected internally so returning restores it
        primaryCandidatePanel.clearSelection()
        secondaryCandidatePanel.clearSelection()
        if let selection = translationCandidateSession.selection {
            panelCoordinator.selectTranslationCandidate(selection)
        }
        setMarkedText(candidate.storageText, in: sender)
        return true
    }

    private func handleTranslationCandidateSelection(
        _ event: NSEvent,
        client sender: Any
    ) -> Bool? {
        guard let selectedCandidate =
                translationCandidateSession.selectedCandidate else {
            return nil
        }
        switch InputKey(keyCode: event.keyCode) {
        case .returnKey:
            commit(selectedCandidate.storageText, to: sender)
            return true
        case .tab, .downArrow:
            return translationCandidateSession.moveVertically(by: 1).map {
                showTranslationCandidateSelection($0, client: sender)
            } ?? true
        case .upArrow:
            return translationCandidateSession.moveVertically(by: -1).map {
                showTranslationCandidateSelection($0, client: sender)
            } ?? true
        case let key where key == .leftArrow || key == .rightArrow:
            noteNavigation("translationSelection.horizontal")
            switch translationCandidateSession.moveHorizontally(
                movingLeft: key == .leftArrow
            ) {
            case let .selected(candidate):
                return showTranslationCandidateSelection(
                    candidate,
                    client: sender
                )
            case .returnedToSource:
                return returnFromTranslationCandidates(client: sender)
            case .unchanged:
                return true
            }
        case .escape:
            return returnFromTranslationCandidates(client: sender)
        case .space:
            commit(selectedCandidate.storageText + " ", to: sender)
            return true
        default:
            return false
        }
    }

    private func returnFromTranslationCandidates(client sender: Any) -> Bool {
        translationCandidateSession.clearSelection()
        panelCoordinator.clearTranslationCandidateSelection()
        if translationCandidateSession.returnWasFuzzy,
           let selectedFuzzyCandidateIndex {
            return selectFuzzyCandidate(
                index: selectedFuzzyCandidateIndex,
                client: sender
            )
        }
        if let selectedCandidateIndex {
            return selectCandidate(index: selectedCandidateIndex, client: sender)
        }
        return true
    }

    private func clearSessionTranslationCandidates() {
        cancelCandidateTranslation()
        translationCandidateSession.reset()
        panelCoordinator.hideTranslationCandidates()
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
        guard Self.featureSettings.isWebSearchEnabled,
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
        try userDictionaryStore.add(
            reading: reading,
            candidate: candidate,
            display: display
        )
        unselectedInputLearningStore.remove(candidate: candidate)
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
        let removesDictionaryEntry = userDictionaryStore.canRemove(
            candidate: candidate
        )
        let removesHistory = candidateSelectionHistoryStore.containsAny(
            historyCandidates
        )
        guard removesDictionaryEntry || removesHistory else {
            NSSound.beep()
            return
        }

        do {
            if removesDictionaryEntry {
                try userDictionaryStore.remove(candidate: candidate)
                do {
                    try nextInputCandidateCoordinator.suppressLearnedCandidate(
                        candidateValueForCommit(candidate)
                    )
                } catch {
                    NSLog(
                        "削除した連結候補の再学習抑制に失敗: %@",
                        error.localizedDescription
                    )
                }
                rebuildConversionEngine()
            }
            candidateSelectionHistoryStore.remove(historyCandidates)
            unselectedInputLearningStore.remove(candidates: historyCandidates)
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
            userDictionaryStore.restore(Self.loadUserEntries())
            rebuildConversionEngine()
            NSSound.beep()
        }
    }

    private var selectedCandidateDeletionTarget: CandidateDeletionTarget? {
        CandidateDeletionCommandPolicy.target(
            hasInput: !inputBuffer.isEmpty,
            hasStandardSelection: selectedCandidateIndex != nil,
            hasFuzzySelection: selectedFuzzyCandidateIndex != nil,
            hasNextInputSelection:
                nextInputCandidateCoordinator.selectedIndex != nil,
            hasRecentEmojiSelection: isEditingEmojiSearch
                && emojiWindow.selectedRecentEmoji != nil
        )
    }

    @discardableResult
    private func removeSelectedCandidate(client sender: Any) -> Bool {
        guard let target = selectedCandidateDeletionTarget else {
            return false
        }
        switch target {
        case .standardCandidate:
            removeSelectedUserDictionaryCandidate(client: sender)
        case .fuzzyCandidate:
            removeSelectedFuzzyCandidateFromUserDictionary(client: sender)
        case .nextInputCandidate:
            removeSelectedNextInputCandidate(client: sender)
        case .recentEmoji:
            removeSelectedRecentEmoji()
        }
        return true
    }

    /// Removes the emoji from the recent history only; it stays in search
    /// results and nothing is committed
    private func removeSelectedRecentEmoji() {
        guard let emoji = emojiWindow.removeSelectedRecentEmoji() else {
            NSSound.beep()
            return
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(emoji, forType: .string)
        updateCandidateDeletionShortcutCapture()
    }

    private func updateCandidateDeletionShortcutCapture() {
        guard Self.activeController === self else { return }
        guard activeInputClient != nil,
              selectedCandidateDeletionTarget != nil,
              !SecureInputDetector.isEnabled else {
            CandidateDeletionGlobalHotKey.shared.deactivate()
            return
        }
        CandidateDeletionGlobalHotKey.shared.activate()
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
        clearInputBuffer()
        reconversionOriginal = nil
        dictionaryRegistrationSession = nil
        clearCandidateState(includingFuzzy: true)
        cancelInputCandidateSearches()
        hideConversionPanels()
    }

    private func beginSecureInputPassthroughIfNeeded(client sender: Any) {
        guard !secureInputPassthroughActive else { return }
        secureInputPassthroughActive = true
        lifecycleCoordinator.clearActivationTime()
        NSLog("myim: Secure Event Inputを検知し、キー処理を停止")
        discardComposition(in: sender)
        nextInputCandidateCoordinator.breakSequence()
        closingBracketTracker.reset()
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

    private func showPrimaryCandidatePanel(client sender: Any) {
        guard !currentCandidates.isEmpty else {
            primaryCandidatePanel.hide()
            return
        }

        let isAccentedInput = CandidatePanelAccentPolicy.isAccented(
            isDictionaryRegistration: dictionaryRegistrationSession != nil
        )
        // Asking the client for the location can handle the next key event
        // before it returns, so the page is read from the candidates after it
        let anchor = locationCoordinator.candidateAnchor(for: sender)
        guard let anchorFrame = anchor.location else {
            primaryCandidatePanel.hide()
            if anchor.shouldRetry {
                scheduleCandidateLocationRetry(for: sender)
            }
            Self.lifecycleLogger.notice(
                "deferred candidate panel until current input location is available"
            )
            return
        }
        cancelCandidateLocationRetry()
        let pageRange = LinearCandidateNavigator.pageRange(
            containing: selectedCandidateIndex ?? 0,
            pageSize: Self.maximumCandidateCount,
            candidateCount: currentCandidateModels.count
        )
        guard !pageRange.isEmpty else {
            primaryCandidatePanel.hide()
            return
        }
        let pageStart = pageRange.lowerBound
        let pageCandidates = Array(currentCandidateModels[pageRange])
        primaryCandidatePanel.show(
            candidates: pageCandidates.map(\.displayText),
            alternateCommitIndicators: pageCandidates.map(
                \.hasDistinctCommitText
            ),
            selectedIndex: selectedCandidateIndex.map { $0 - pageStart },
            near: anchorFrame,
            isAccented: isAccentedInput,
            reservedRightWidth: secondaryCandidatePanel.isVisible
                ? secondaryCandidatePanel.panelWidth
                    + secondaryCandidatePanel.spacingFromCandidatePanel
                : 0
        )
        Self.lifecycleLogger.notice(
            "candidate panel positioned anchor=\(String(describing: anchorFrame), privacy: .public) frame=\(String(describing: self.primaryCandidatePanel.frame), privacy: .public)"
        )
        logPanelSnapshot(event: "candidatePanel.afterShow", sender: sender)
        schedulePanelSnapshots(afterCandidateShowFor: sender)
        if secondaryCandidatePanel.isVisible {
            alignSecondaryCandidatePanelToPrimary()
        } else if !fuzzyCandidateSession.isEmpty {
            showInitialFuzzyCandidates()
        }
        if emojiWindow.isVisible {
            let frames = [primaryCandidatePanel.visibleFrame, secondaryCandidatePanel.visibleFrame]
                .compactMap { $0 }
            emojiWindow.avoid(frames: frames)
        }
    }

    private func inputLocation(for sender: Any) -> NSRect {
        locationCoordinator.inputLocation(for: sender)
    }

    private func scheduleCandidateLocationRetry(for sender: Any) {
        guard let sessionSnapshot = currentInputSessionSnapshot() else {
            return
        }
        let senderObject = sender as AnyObject
        locationCoordinator.scheduleCandidateRetry(
            isCurrent: { [weak self, weak senderObject] in
                guard let self, senderObject != nil else { return false }
                return self.inputSession.accepts(
                        sessionSnapshot,
                        controllerID: self.controllerID,
                        isActive: self.lifecycleCoordinator.isActive
                    )
                    && !self.inputBuffer.isEmpty
                    && !self.currentCandidates.isEmpty
            },
            retry: { [weak self, weak senderObject] in
                guard let self, let senderObject else { return }
                self.showPrimaryCandidatePanel(client: senderObject)
            }
        )
    }

    private func cancelCandidateLocationRetry() {
        locationCoordinator.cancelCandidateRetry()
    }

    private func commitFirstCandidateOrInput(to sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            guard let selectedNextInput = nextInputCandidateCoordinator
                .selectedCandidate else {
                return false
            }
            commitNextInputCandidate(selectedNextInput, to: sender)
            return true
        }

        let selectedCandidate = selectedCandidateIndex.flatMap {
            currentCandidates.indices.contains($0) ? currentCandidates[$0] : nil
        }
        let value = selectedCandidateValue ?? inputBuffer
        let calculatorNextInputCandidates = selectedCandidateIndex == nil
            ? cachedJavaScriptCalculationCandidates
            : []
        let historyValue = selectedCandidate.flatMap {
            CalculationInputHistory.value(
                input: inputBuffer,
                selectedCandidate: $0,
                generatedCandidates: cachedJavaScriptCalculationCandidates
            )
        }
        let unselectedInputLearningEntry = UnselectedInputLearningPolicy.entry(
            originalInput: inputBuffer,
            hasSelectedCandidate: selectedCandidateValue != nil
        )
        let punctuation = selectedCandidateValue == nil
            ? ""
            : compositionSuffix
        recordSelectedCandidate()
        commit(
            value,
            to: sender,
            historyValue: historyValue,
            preferredNextInputCandidates: calculatorNextInputCandidates
        )
        learnUnselectedInput(unselectedInputLearningEntry)
        continueWithTrailingPunctuation(punctuation, client: sender)
        return true
    }

    private func learnUnselectedInput(
        _ entry: UnselectedInputLearningEntry?
    ) {
        guard Self.diagnosticConfiguration.enables(.learning),
              let entry else {
            return
        }
        guard !userDictionaryStore.contains(
            reading: entry.reading,
            candidate: entry.candidate
        ) else {
            unselectedInputLearningStore.remove(candidate: entry.candidate)
            return
        }
        guard let registration = unselectedInputLearningStore.registration(
            after: entry
        ) else {
            return
        }
        do {
            try saveUserDictionaryEntry(
                reading: registration.reading,
                candidate: registration.candidate
            )
        } catch {
            NSLog(
                "未選択確定文字列のユーザー辞書登録に失敗: %@",
                error.localizedDescription
            )
        }
    }

    private func recordSelectedCandidate() {
        guard
            let selectedCandidateIndex,
            currentCandidateModels.indices.contains(selectedCandidateIndex)
        else {
            return
        }
        recordCandidateSelectionForCurrentInput(
            currentCandidateModels[selectedCandidateIndex]
        )
    }

    private func recordCandidateSelectionForCurrentInput(
        _ candidate: Candidate
    ) {
        guard !candidate.hasSource(.translation),
              !translationCandidateSession.contains(
                candidate.storageText,
                in: .standard
              )
        else {
            return
        }
        if let expression = CalculationInputHistory.value(
            input: inputBuffer,
            selectedCandidate: candidate.storageText,
            generatedCandidates: cachedJavaScriptCalculationCandidates
        ) {
            recordCandidateSelection(expression, reading: expression)
        } else {
            recordCandidateSelection(
                candidate.storageText,
                isLearnable: candidate.isLearnable
            )
        }
    }

    private func recordCandidateSelection(
        _ candidate: String,
        reading: String? = nil,
        isLearnable: Bool = false
    ) {
        guard Self.diagnosticConfiguration.enables(.learning) else { return }
        let learnedReading = reading ?? candidateSelectionReading
        if isLearnable, !learnedReading.isEmpty,
           UnselectedInputLearningPolicy.requiresRepeatedSelection(candidate) {
            learnUnselectedInput(UnselectedInputLearningEntry(
                reading: learnedReading,
                candidate: candidate
            ))
        } else if isLearnable, !learnedReading.isEmpty {
            do {
                try saveUserDictionaryEntry(
                    reading: learnedReading,
                    candidate: candidate
                )
            } catch {
                NSLog(
                    "選択候補のユーザー辞書登録に失敗: %@",
                    error.localizedDescription
                )
            }
        }
        candidateSelectionHistoryStore.record(
            candidate,
            readings: CandidateSelectionReading.historyReadings(
                for: learnedReading
            )
        )
    }

    private func candidatesOrderedByRecency(
        _ candidates: [String]
    ) -> [String] {
        CandidateRecencyOrderer.ordered(
            candidates,
            ranks: candidateSelectionRanks(for: candidateSelectionReading)
        )
    }

    private var candidateSelectionReading: String {
        CandidateSelectionReading.resolve(
            conversionReading: conversionReading,
            originalInput: conversionInput
        )
    }

    private func candidateSelectionRanks(for reading: String) -> [String: Int] {
        guard Self.diagnosticConfiguration.enables(.learning) else {
            return [:]
        }
        return candidateSelectionHistoryStore.ranks(
            for: CandidateSelectionReading.historyReadings(for: reading)
        )
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
        logPanelSnapshot(event: "delete.before", sender: sender)
        guard !inputBuffer.isEmpty else {
            return false
        }

        resetCandidateFilters()
        clearSessionTranslationCandidates()

        if inputSession.deleteBackward(unit: unit) {
            cancelCandidateLocationRetry()
        }
        selectedCandidateIndex = nil
        previewWindow.hide()
        setMarkedText(
            compositionPrefix + inputBuffer,
            in: sender,
            selectionOffset: compositionPrefix.utf16.count + inputCursor
        )
        refreshCandidates(client: sender)
        logPanelSnapshot(event: "delete.after", sender: sender)
        return true
    }

    private func cancelInput(in sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            guard nextInputCandidateCoordinator.hasCandidates else {
                return false
            }
            dismissNextInputCandidates(clearMarkedTextIn: sender)
            return true
        }

        if reconversionOriginal != nil {
            restoreReconversionOriginal(client: sender)
            return true
        }

        guard selectedCandidateIndex != nil else {
            discardComposition(in: sender)
            return true
        }
        selectedCandidateIndex = nil
        primaryCandidatePanel.clearSelection()
        updateMarkedText(in: sender)
        showPrimaryCandidatePanel(client: sender)
        return true
    }

    private func discardComposition(in sender: Any) {
        clearCompositionForSystemPaste(in: sender)
        cancelCandidateTranslation()
        resetTransientInteractionState()
    }

    private func commitNextInputCandidate(
        _ value: String,
        appending suffix: String = "",
        replacingMarkedText: Bool = true,
        to sender: Any
    ) {
        let selectedCandidateModel = nextInputCandidateCoordinator
            .selectedCandidateModel
        let sourceTokens = nextInputCandidateCoordinator.selectedSourceTokens
        let sourceReadings = nextInputCandidateCoordinator
            .selectedSourceReadings
        if Self.diagnosticConfiguration.enables(.learning),
           let selectedCandidateModel,
           let entry = LearnedCompoundRegistration.entry(
            from: selectedCandidateModel
           ) {
            do {
                try saveUserDictionaryEntry(
                    reading: entry.reading,
                    candidate: entry.candidate
                )
            } catch {
                NSLog(
                    "学習済み連結候補の辞書登録に失敗: %@",
                    error.localizedDescription
                )
            }
        }
        let committedValue = value + suffix
        let committedTokens = sourceTokens.map {
            NextInputLearningToken.texts($0, followedBy: suffix)
        }
        recordNextInputCandidateSelection(value)
        clearNextInputCandidateState()
        commit(
            committedValue,
            to: sender,
            replacingMarkedText: replacingMarkedText,
            historyValue: committedValue,
            historyTokens: committedTokens,
            historyReadings: sourceReadings,
            historyLearningSource: .acceptedCandidate
        )
    }

    private func recordNextInputCandidateSelection(_ candidate: String) {
        guard Self.diagnosticConfiguration.enables(.learning),
              closingBracketTracker.shouldRecordAsNextInput(candidate),
              !isGeneratedParticleCandidate(candidate) else {
            return
        }
        let userEngine = dictionaryRuntime.userEngine
        let basicEngine = dictionaryRuntime.basicEngine
        let indexedEngine = dictionaryRuntime.systemEngine
        Task { @MainActor [weak self] in
            let readings = await CandidateReadingLookup.resolve(
                candidate: candidate,
                userEngine: userEngine,
                basicEngine: basicEngine,
                indexedEngine: indexedEngine
            )
            guard let self else { return }
            candidateSelectionHistoryStore.record(
                candidate,
                readings: readings
            )
        }
    }

    private func removeSelectedNextInputCandidate(client sender: Any) {
        guard let candidate = nextInputCandidateCoordinator.selectedCandidate
        else {
            NSSound.beep()
            return
        }
        guard !closingBracketTracker.shouldBypassCandidateSuppression(
            candidate
        ) else {
            NSSound.beep()
            return
        }
        do {
            try nextInputCandidateCoordinator.suppressSelectedCandidate()
        } catch {
            NSLog(
                "次入力候補の削除保存に失敗: %@",
                error.localizedDescription
            )
            NSSound.beep()
        }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(candidate, forType: .string)
        setMarkedText("", in: sender)
        previewWindow.hide()
        guard nextInputCandidateCoordinator.hasCandidates else {
            dismissNextInputCandidates(clearMarkedTextIn: nil)
            return
        }
        showNextInputCandidatePanel(client: sender)
        scheduleNextInputDismissal()
    }

    private func commit(
        _ value: String,
        to sender: Any,
        replacingMarkedText: Bool = false,
        historyValue: String? = nil,
        historyTokens: [String]? = nil,
        historyReadings: [String?]? = nil,
        historyReading: String? = nil,
        historyLearningSource: NextInputLearningSource = .directInput,
        preferredNextInputCandidates: [String] = []
    ) {
        guard let textClient = sender as? IMKTextInput else {
            return
        }
        trace("insertText.request", sender: sender, detail: "value=\(value)")

        let inputHistoryValue = historyValue ?? value
        let inputHistoryReading = historyReading ?? (!inputBuffer.isEmpty
            ? candidateSelectionReading
            : nil)
        let isPendingClosingBracket = !closingBracketTracker
            .shouldRecordAsNextInput(inputHistoryValue)
        if isPendingClosingBracket {
            nextInputCandidateCoordinator.forgetLearnedCandidate(
                inputHistoryValue
            )
        }
        let nextInputPolicy = NextInputCommitPolicy.resolve(
            committing: inputHistoryValue,
            closingBracketTracker: closingBracketTracker,
            isGeneratedParticle: isGeneratedParticleCandidate(
                inputHistoryValue
            ),
            selectedCandidate: candidateSession.selectedCandidate
        )

        let markedRange = textClient.markedRange()
        let beginsAfterLineBreak = inputBeginsAfterLineBreak(
            textClient,
            markedRange: markedRange
        )
        let replacementRange = CandidateCommitReplacementRange.resolve(
            markedRange: markedRange,
            hasActiveComposition: replacingMarkedText || !inputBuffer.isEmpty
        )
        isInsertingCommittedText = true
        textClient.insertText(
            value,
            replacementRange: replacementRange
        )
        isInsertingCommittedText = false
        trace("insertText.complete", sender: sender, detail: "value=\(value)")
        if beginsAfterLineBreak {
            closingBracketTracker.reset()
        }
        closingBracketTracker.consume(value)
        recentCommittedContext = String(
            (recentCommittedContext + value).suffix(256)
        )
        cancelInputCandidateSearches()
        cancelCandidateTranslation()
        clearInputBuffer()
        reconversionOriginal = nil
        dictionaryRegistrationSession = nil
        clearCandidateState(includingFuzzy: true)
        hideConversionPanels()
        emojiWindow.hide()
        symbolTipsWindow.hide()
        clearCalendarSelection()
        resetCandidateFilters()
        if inputHistoryValue.allSatisfy({ $0.isWhitespace }),
           !inputHistoryValue.isEmpty {
            nextInputCandidateCoordinator.appendSeparatorToLastInput(
                inputHistoryValue
            )
        } else if nextInputPolicy.updatesCandidates {
            let structuralCandidates = closingBracketTracker.candidate.map {
                [$0]
            } ?? []
            recordCommittedInput(
                inputHistoryValue,
                learningTokens: historyTokens,
                learningReadings: historyReadings
                    ?? historyTokens.map { tokens in
                        tokens.count == 1 ? [inputHistoryReading] : []
                    }
                    ?? [inputHistoryReading],
                learningSource: historyLearningSource,
                learnsInput: nextInputPolicy.learnsInput,
                preferredCandidates: structuralCandidates
                    + preferredNextInputCandidates,
                breakPreviousSequence: beginsAfterLineBreak,
                client: sender
            )
        }
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
        trace("candidateGeneration.cancel", sender: client(), detail: "source=all")
        clearSessionTranslationCandidates()
        candidateSearchCoordinator.cancel(.calendarFormat)
        let hidesSharedEmoji = shouldDismissSharedEmojiPanel
        panelCoordinator.dismissAll(hidesSharedEmoji: hidesSharedEmoji)
        if hidesSharedEmoji {
            Self.emojiPanelController = nil
        }
        tracePanelDismissal(
            source: "all",
            preserved: [],
            ignoresSharedEmoji: !hidesSharedEmoji
        )
        fuzzyCandidateSession.reset()
        selectedFuzzyCandidateIndex = nil
        clearNextInputCandidateState()
        cancelInputCandidateSearches()
        candidateSearchCoordinator.cancel(.dictionaryDefinition)
        clearCalendarSelection()
        resetCandidateFilters()
    }

    private func cancelFuzzyCandidateSearch() {
        candidateSearchCoordinator.cancel(.fuzzy)
    }

    private func dismissFuzzyCandidates() {
        candidateSearchCoordinator.cancel(.fuzzy)
        cancelCandidateTranslation()
        fuzzyCandidateSession.reset()
        selectedFuzzyCandidateIndex = nil
        secondaryCandidatePanel.hide()
    }

    private func dismissInputSessionPanels(
        using policy: InputPanelDismissalPolicy
    ) {
        trace("candidateGeneration.cancel", sender: client(), detail: "source=panels")
        cancelInputCandidateSearches()
        candidateSearchCoordinator.cancel(.dictionaryDefinition)
        cancelCandidateTranslation()
        if policy.cancelsCalendarWork {
            candidateSearchCoordinator.cancel(.calendarFormat)
        }
        candidateSearchCoordinator.cancel(.fuzzy)
        fuzzyCandidateSession.reset()
        selectedFuzzyCandidateIndex = nil
        let hidesSharedEmoji = shouldDismissSharedEmojiPanel
            && policy.panelsToDismiss.contains(.emoji)
        panelCoordinator.dismiss(
            using: policy,
            hidesSharedEmoji: hidesSharedEmoji
        )
        // A panel left open keeps its owner, so clearing the search again
        // still returns to the initial emojis
        if hidesSharedEmoji {
            Self.emojiPanelController = nil
        }
        tracePanelDismissal(
            source: "policy",
            preserved: Set(InputPanelKind.allCases)
                .subtracting(policy.panelsToDismiss),
            ignoresSharedEmoji: !hidesSharedEmoji
        )
        resetCandidateFilters()
        if !policy.preservesCalendar {
            clearCalendarSelection()
        }
        clearNextInputCandidateState()
    }

    private func cancelAuxiliaryCandidateSearches() {
        candidateSearchCoordinator.cancel(.fuzzy)
    }

    private func cancelInputCandidateSearches() {
        candidateSearchCoordinator.cancel(.external)
        candidateSearchCoordinator.cancel(.fuzzy)
        candidateSearchCoordinator.cancel(.javaScriptExtensions)
        candidateSearchCoordinator.cancel(.postalAddress)
    }

    private func flushPendingHistoryWrites() {
        candidateSelectionHistoryStore.flush()
        unselectedInputLearningStore.flush()
        nextInputCandidateCoordinator.flush()
    }

    private func moveNextInputCandidate(
        _ direction: CandidateNavigationDirection,
        client sender: Any
    ) -> Bool {
        guard nextInputCandidateCoordinator.hasCandidates else {
            return false
        }
        let offset = switch direction {
        case .left, .up: -1
        case .right, .down: 1
        }
        guard let nextIndex = nextInputCandidateCoordinator
            .linearSelectionIndex(
            offset: offset
        ) else { return true }
        return selectNextInputCandidate(index: nextIndex, client: sender)
    }

    private func selectNextInputCandidate(
        offset: Int,
        client sender: Any
    ) -> Bool {
        guard let nextIndex = nextInputCandidateCoordinator
            .wrappedSelectionIndex(
            offset: offset
        ) else { return true }
        return selectNextInputCandidate(index: nextIndex, client: sender)
    }

    private func selectNextInputCandidate(
        index: Int,
        client sender: Any
    ) -> Bool {
        guard nextInputCandidateCoordinator.candidates.indices.contains(index)
        else {
            return true
        }
        let previousPage = nextInputCandidateCoordinator.pageRange(
            pageSize: Self.maximumCandidateCount
        )
        guard let candidate = nextInputCandidateCoordinator.select(
            index: index
        ) else {
            return true
        }
        let currentPage = nextInputCandidateCoordinator.pageRange(
            pageSize: Self.maximumCandidateCount
        )
        if currentPage == previousPage {
            primaryCandidatePanel.select(index: index - currentPage.lowerBound)
        } else {
            showNextInputCandidatePanel(client: sender)
        }
        setMarkedText(candidate, in: sender)
        showPreview(for: candidate)
        scheduleNextInputDismissal()
        updateCandidateDeletionShortcutCapture()
        return true
    }

    private func recordCommittedInput(
        _ value: String,
        learningTokens: [String]? = nil,
        learningReadings: [String?]? = nil,
        learningSource: NextInputLearningSource = .directInput,
        learnsInput: Bool,
        preferredCandidates: [String] = [],
        breakPreviousSequence: Bool = false,
        client sender: Any
    ) {
        guard Self.diagnosticConfiguration.enables(.nextInput) else {
            nextInputCandidateCoordinator.breakSequence()
            return
        }
        candidateSearchCoordinator.cancel(.nextInputExtension)
        let committedTokens = learningTokens ?? [value]
        let committedReadings = learningReadings?.count == committedTokens.count
            ? learningReadings ?? []
            : Array(repeating: nil, count: committedTokens.count)
        let predictionContext = committedTokens.last ?? value
        let learnedCandidates = nextInputCandidateCoordinator
            .learnedCandidateModels(
                after: value,
                committedTokens: zip(
                    committedTokens,
                    committedReadings
                ).map {
                    NextInputLearningToken(text: $0.0, reading: $0.1)
                },
                learningSource: learningSource,
                predictionEnabled: Self.featureSettings.isNextInputPredictionEnabled,
                learningEnabled: learnsInput
                    && Self.diagnosticConfiguration.enables(.learning),
                breakPreviousSequence: breakPreviousSequence,
                limit: NextInputPredictionModel.maximumFollowersPerContext
            )

        let dictionaryCandidates = dictionaryRuntime.continuationCandidates(
            after: predictionContext,
            limit: 16
        ).map { Candidate(storageText: $0, source: .nextInput) }
        // Only the structural candidate offers a closing bracket, so one is
        // not suggested where no bracket is open
        let hasCandidates = nextInputCandidateCoordinator.beginCandidates(
            context: predictionContext,
            preferredCandidates: preferredCandidates.map {
                Candidate(storageText: $0, source: .nextInput)
            },
            learnedCandidates: learnedCandidates.filter {
                !ClosingBracketTracker.startsWithClosingBracket($0.commitText)
            },
            dictionaryCandidates: dictionaryCandidates.filter {
                !ClosingBracketTracker.startsWithClosingBracket($0.commitText)
            },
            unsuppressibleCandidates: Set(preferredCandidates.filter {
                closingBracketTracker.shouldBypassCandidateSuppression($0)
            })
        )
        if !hasCandidates {
            panelCoordinator.dismissNextInputPresentation()
            trace(
                "panel.hide",
                sender: sender,
                detail: "kind=nextInput reason=noCandidates"
            )
        } else {
            showNextInputCandidatePanel(client: sender)
            startNextInputOutsideClickMonitoring()
            scheduleNextInputDismissal()
        }
        guard Self.diagnosticConfiguration.enables(.jsExtensions),
              let asyncSnapshot = currentInputSessionSnapshot() else {
            return
        }
        candidateSearchCoordinator.start(
            .nextInputExtension,
            query: predictionContext,
            operation: {
                await Self.javaScriptExtensionClient
                .nextInputCandidates(after: predictionContext)
            },
            validate: { [weak self] in
                guard let self else { return false }
                return self.inputBuffer.isEmpty
                    && self.acceptsAsyncResult(
                        asyncSnapshot,
                        source: "nextInputJS",
                        sender: sender
                    )
            },
            apply: { [weak self] generated in
                guard let self, !generated.isEmpty else { return }
                guard self.nextInputCandidateCoordinator
                    .appendGeneratedCandidates(
                        generated,
                        after: predictionContext
                    ) else {
                    return
                }
                self.showNextInputCandidatePanel(client: sender)
                self.startNextInputOutsideClickMonitoring()
                // A late result is not an operation, so it keeps the
                // countdown of the panel it joins
                self.panelCoordinator.startNextInputDismissalIfIdle(
                    onDismiss: self.dismissNextInputCandidatesOnTimeout
                )
            },
            retainQueryAfterCompletion: false
        )
    }

    private func showNextInputCandidatePanel(client sender: Any) {
        let pageRange = nextInputCandidateCoordinator.pageRange(
            pageSize: Self.maximumCandidateCount
        )
        guard !pageRange.isEmpty else {
            panelCoordinator.dismissNextInputPresentation()
            return
        }
        primaryCandidatePanel.show(
            candidates: Array(
                nextInputCandidateCoordinator.candidates[pageRange]
            ),
            selectedIndex: nextInputCandidateCoordinator.selectedIndex.map {
                $0 - pageRange.lowerBound
            },
            near: inputLocation(for: sender),
            isAccented: false
        )
    }

    private func scheduleNextInputDismissal() {
        panelCoordinator.restartNextInputDismissal(
            onDismiss: dismissNextInputCandidatesOnTimeout
        )
    }

    private var dismissNextInputCandidatesOnTimeout: () -> Void {
        { [weak self] in
            guard let self else { return }
            trace(
                "panel.hide",
                sender: client(),
                detail: "kind=nextInput reason=timeout"
            )
            dismissNextInputCandidates(clearMarkedTextIn: client())
        }
    }

    private func dismissNextInputCandidates(
        clearMarkedTextIn sender: Any?
    ) {
        if nextInputCandidateCoordinator.selectedIndex != nil, let sender {
            setMarkedText("", in: sender)
        }
        clearNextInputCandidateState()
        panelCoordinator.dismissNextInputPresentation()
    }

    private func clearNextInputCandidateState() {
        candidateSearchCoordinator.cancel(.nextInputExtension)
        panelCoordinator.stopNextInputLifecycle()
        nextInputCandidateCoordinator.resetCandidates()
        updateCandidateDeletionShortcutCapture()
    }

    private func startNextInputOutsideClickMonitoring() {
        panelCoordinator.startNextInputOutsideClickMonitoring {
            [weak self] in
            guard let self else { return }
            trace(
                "panel.hide",
                sender: client(),
                detail: "kind=nextInput reason=outsideClick"
            )
            dismissNextInputCandidates(clearMarkedTextIn: client())
        }
    }

    private var shouldDismissSharedEmojiPanel: Bool {
        SharedPanelDismissalPolicy.shouldDismiss(
            ownerID: Self.emojiPanelController?.controllerID,
            requestingControllerID: controllerID
        )
    }

    private func tracePanelDismissal(
        source: String,
        preserved: Set<InputPanelKind>,
        ignoresSharedEmoji: Bool
    ) {
        let remainingPanels = panelCoordinator.visiblePanelKinds
        var expectedRemaining = preserved
        if ignoresSharedEmoji {
            expectedRemaining.insert(.emoji)
        }
        let remaining = remainingPanels.map(\.rawValue).sorted()
        let unexpected = remainingPanels
            .subtracting(expectedRemaining)
            .map(\.rawValue).sorted()
        trace(
            "panelDismiss.complete",
            sender: client(),
            detail: "source=\(source) remaining=\(remaining.joined(separator: ",")) unexpected=\(unexpected.joined(separator: ","))"
        )
    }

    private func updateMarkedText(in sender: Any) {
        setMarkedText(
            CandidateSelectionProjection.unconvertedMarkedText(
                input: inputBuffer,
                prefix: compositionPrefix
            ),
            in: sender,
            selectionOffset: compositionPrefix.utf16.count + inputCursor
        )
    }

    private var compositionPrefix: String {
        if let confirmedCandidate = dictionaryRegistrationSession?
            .confirmedCandidate {
            return confirmedCandidate
        }
        return ""
    }

    /// Trailing punctuation shown after the converted text and converted
    /// once the text is committed
    private var compositionSuffix: String {
        trailingPunctuationSplit?.punctuation ?? ""
    }

    /// Input converted now; trailing punctuation waits for the next step
    private var conversionInput: String {
        trailingPunctuationSplit?.body ?? inputBuffer
    }

    private var trailingPunctuationSplit: TrailingPunctuationSplit? {
        guard dictionaryRegistrationSession == nil else { return nil }
        if inputSession.carriesTrailingPunctuation {
            return TrailingPunctuationSplit.splitCarried(
                inputBuffer,
                convertsAsGroup: !JapaneseSymbolConverter.candidates(
                    for: inputBuffer
                ).isEmpty
                    || !Self.sharedSymbolConversionEngine.candidates(
                        for: inputBuffer
                    ).isEmpty
            )
        }
        // A registered word that includes the punctuation stays whole
        guard dictionaryRuntime.userDictionaryEngine.candidates(
                for: inputBuffer
              ).isEmpty,
              dictionaryRuntime.importedEngine.candidates(
                for: inputBuffer
              ).isEmpty else {
            return nil
        }
        return TrailingPunctuationSplit.split(inputBuffer)
    }

    /// After the text before trailing punctuation is committed, the
    /// punctuation becomes the next input with its symbol candidates
    private func continueWithTrailingPunctuation(
        _ punctuation: String,
        client sender: Any
    ) {
        guard !punctuation.isEmpty else { return }
        dismissNextInputCandidates(clearMarkedTextIn: nil)
        inputSession.carryTrailingPunctuation(punctuation)
        selectedCandidateIndex = nil
        updateMarkedText(in: sender)
        refreshCandidates(client: sender)
    }

    private func setMarkedText(
        _ value: String,
        in sender: Any,
        selectionOffset: Int? = nil
    ) {
        guard let textClient = sender as? IMKTextInput else {
            return
        }
        noteNavigation(
            "setMarkedText length=\(value.utf16.count) selection=\(selectionOffset ?? value.utf16.count)"
        )
        trace("setMarkedText.request", sender: sender, detail: "value=\(value)")

        let markedRange = textClient.markedRange()
        let replacementRange = markedRange.location != NSNotFound
            && markedRange.length > 0
            ? markedRange
            : NSRange(location: NSNotFound, length: NSNotFound)
        textClient.setMarkedText(
            markedTextValue(value),
            selectionRange: NSRange(
                location: selectionOffset ?? value.utf16.count,
                length: 0
            ),
            replacementRange: replacementRange
        )
        trace("setMarkedText.complete", sender: sender, detail: "value=\(value)")
    }

    /// The text being converted and the trailing punctuation waiting
    /// for the next conversion are marked as separate clauses with the
    /// standard input method styles, so their underlines are drawn apart
    private func markedTextValue(_ value: String) -> Any {
        guard let segments = MarkedTextSegments(
            text: value,
            pendingSuffix: compositionSuffix
        ) else {
            return value
        }
        let text = NSMutableAttributedString(string: value)
        for (style, segment) in [
            (kTSMHiliteSelectedConvertedText, segments.target),
            (kTSMHiliteRawText, segments.pending)
        ] {
            let range = NSRange(
                location: segment.lowerBound,
                length: segment.count
            )
            let attributes = mark(forStyle: Int(style), at: range) ?? [:]
            text.setAttributes(
                Dictionary(uniqueKeysWithValues: attributes.compactMap {
                    key, value in
                    (key as? String).map {
                        (NSAttributedString.Key($0), value)
                    }
                }),
                range: range
            )
        }
        return text
    }

    private var inputRevision: UInt {
        inputSession.inputRevision
    }

    private func currentInputSessionSnapshot() -> InputSessionSnapshot? {
        return inputSession.snapshot(controllerID: controllerID)
    }

    private func acceptsAsyncResult(
        _ snapshot: InputSessionSnapshot,
        source: String,
        sender: Any? = nil
    ) -> Bool {
        let accepted = inputSession.accepts(
            snapshot,
            controllerID: controllerID,
            isActive: lifecycleCoordinator.isActive
        )
        trace(
            accepted ? "asyncResult.accepted" : "asyncResult.rejectedAsStale",
            sender: sender,
            detail: "source=\(source) startS=\(snapshot.sessionGeneration) startR=\(snapshot.inputRevision)"
        )
        return accepted
    }

    private func trace(
        _ event: String,
        sender: Any?,
        detail: String = ""
    ) {
        guard Self.diagnosticConfiguration.traceEnabled else { return }
        let textClient = sender as? IMKTextInput
        if InputTraceClientRangePolicy.shouldCapture(for: event),
           let textClient {
            lastTracedMarkedRange = textClient.markedRange()
            lastTracedSelectedRange = textClient.selectedRange()
        }
        let markedRange = lastTracedMarkedRange
        let selectedRange = lastTracedSelectedRange
        let session = lifecycleCoordinator.globalGeneration ?? 0
        let application = lifecycleCoordinator.clientBundleIdentifier
            ?? textClient?.bundleIdentifier()
            ?? "unknown"
        let escapedComposition = inputBuffer
            .replacingOccurrences(of: "\n", with: "\\n")
        let message = "[S\(session) R\(inputRevision) C\(controllerID)] \(event) app=\(application) composition=\(escapedComposition) marked=\(NSStringFromRange(markedRange)) selected=\(NSStringFromRange(selectedRange)) \(detail)"
        Self.lifecycleLogger.notice("\(message, privacy: .public)")
    }

    private static func milliseconds(_ duration: Duration) -> Int64 {
        microseconds(duration) / 1_000
    }

    private static func microseconds(_ duration: Duration) -> Int64 {
        duration.components.seconds * 1_000_000
            + duration.components.attoseconds / 1_000_000_000_000
    }

    private func schedulePanelSnapshots(afterCandidateShowFor sender: Any) {
        guard Self.diagnosticConfiguration.traceEnabled else { return }
        DispatchQueue.main.async { [weak self, weak senderObject = sender as AnyObject] in
            guard let self else { return }
            self.logPanelSnapshot(
                event: "candidatePanel.nextRunLoop",
                sender: senderObject
            )
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            [weak self, weak senderObject = sender as AnyObject] in
            guard let self else { return }
            self.logPanelSnapshot(
                event: "candidatePanel.after100ms",
                sender: senderObject
            )
        }
    }

    private func logPanelSnapshot(event: String, sender: Any?) {
        guard Self.diagnosticConfiguration.traceEnabled else { return }
        let textClient = sender as? IMKTextInput
        let markedRange = textClient?.markedRange()
            ?? NSRange(location: NSNotFound, length: 0)
        let selectedRange = textClient?.selectedRange()
            ?? NSRange(location: NSNotFound, length: 0)
        let application = lifecycleCoordinator.clientBundleIdentifier
            ?? textClient?.bundleIdentifier()
            ?? "unknown"
        let anchor = locationCoordinator.compositionAnchorDescription
        let lastLocation = locationCoordinator.lastValidLocationDescription
        let windows = NSApp.windows.compactMap { window -> String? in
            guard window is NSPanel else { return nil }
            return "number=\(window.windowNumber) type=\(String(describing: type(of: window))) visible=\(window.isVisible) onScreen=\(window.isOnActiveSpace) frame=\(NSStringFromRect(window.frame)) level=\(window.level.rawValue)"
        }.joined(separator: " | ")
        Self.lifecycleLogger.notice(
            "[S\(self.lifecycleCoordinator.globalGeneration ?? 0) R\(self.inputRevision) C\(self.controllerID)] panelSnapshot event=\(event, privacy: .public) app=\(application, privacy: .public) compositionLength=\(self.inputBuffer.count, privacy: .public) marked=\(NSStringFromRange(markedRange), privacy: .public) selected=\(NSStringFromRange(selectedRange), privacy: .public) anchor=\(anchor, privacy: .public) lastLocation=\(lastLocation, privacy: .public) windows=\(windows, privacy: .public)"
        )
    }

    private func clearInputBuffer() {
        cancelCandidateLocationRetry()
        inputSession.clear()
        locationCoordinator.clearCompositionAnchor()
    }

    private func clearCandidateState(includingFuzzy: Bool = false) {
        candidateSession.reset()
        if includingFuzzy {
            clearSessionTranslationCandidates()
            fuzzyCandidateSession.reset()
        }
        updateCandidateDeletionShortcutCapture()
    }

    private func hideConversionPanels() {
        cancelCandidateLocationRetry()
        panelCoordinator.hideConversionPanels()
    }

    private func insertIntoInputBuffer(_ text: String) {
        clearSessionTranslationCandidates()
        resetCandidateFilters()
        if inputSession.insert(text) {
            cancelCandidateLocationRetry()
        }
    }

    private func replaceInputBuffer(
        _ value: String,
        cursorPosition: Int
    ) {
        if inputSession.setInput(value, cursorPosition: cursorPosition) {
            cancelCandidateLocationRetry()
        }
    }

    private func moveInputCursor(by offset: Int, client sender: Any) -> Bool {
        let cursorBefore = inputCursor
        defer {
            noteNavigation(
                "moveInputCursor offset=\(offset) before=\(cursorBefore) after=\(inputCursor)"
            )
        }
        guard !inputBuffer.isEmpty else {
            dismissPanelsForCursorMovement(client: sender)
            return false
        }
        dismissPanelsForCursorMovement(client: sender)
        guard inputSession.moveCursor(by: offset) else { return true }
        if !compositionPrefix.isEmpty {
            setMarkedText(
                CandidateSelectionProjection.unconvertedMarkedText(
                input: inputBuffer,
                prefix: compositionPrefix
            ),
                in: sender,
                selectionOffset: compositionPrefix.utf16.count + inputCursor
            )
        } else {
            updateMarkedText(in: sender)
        }
        return true
    }

    private func dismissPanelsForCursorMovement(client sender: Any) {
        symbolTipsWindow.hide()
        if nextInputCandidateCoordinator.hasCandidates {
            dismissNextInputCandidates(clearMarkedTextIn: sender)
        }
    }

    private func showInputPreview(client sender: Any) {
        let selectedCandidate = selectedCandidateIndex.flatMap { index in
            currentCandidates.indices.contains(index)
                ? candidateDisplayValue(currentCandidates[index])
                : nil
        }
        let inputFrame = inputLocation(for: sender)
        var baseAnchorFrame = currentCandidates.isEmpty
            ? inputFrame
            : inputFrame.union(
                primaryCandidatePanel.visibleFrame ?? primaryCandidatePanel.frame
            )
        let tipsText = selectedCandidate ?? inputBuffer
        if let tips = SymbolTips.make(for: tipsText) {
            symbolTipsWindow.show(tips, beside: baseAnchorFrame)
            if let tipsFrame = symbolTipsWindow.visibleFrame {
                baseAnchorFrame = baseAnchorFrame.union(tipsFrame)
            }
        } else {
            symbolTipsWindow.hide()
        }
        guard let pageTitle = PreviewPageTitleResolver.pageTitle(
            input: conversionReading,
            selectedCandidate: selectedCandidate
        ) else {
            candidateSearchCoordinator.cancel(.dictionaryDefinition)
            previewWindow.hide()
            return
        }
        showPreview(
            for: pageTitle,
            beside: previewAnchorFrame(base: baseAnchorFrame),
            includeDefinitions: true
        )
    }

    private func showSymbolTipsForCurrentInput(client sender: Any) {
        guard let tips = SymbolTips.make(for: inputBuffer) else {
            symbolTipsWindow.hide()
            return
        }
        let inputFrame = inputLocation(for: sender)
        let anchorFrame = primaryCandidatePanel.visibleFrame.map {
            inputFrame.union($0)
        } ?? inputFrame
        symbolTipsWindow.show(tips, beside: anchorFrame)
    }

    private func showPreview(for candidate: String) {
        var anchorFrame = primaryCandidatePanel.visibleFrame
            ?? primaryCandidatePanel.frame
        if let inputClient = client() {
            anchorFrame = anchorFrame.union(
                inputLocation(for: inputClient)
            )
        }
        if let tips = SymbolTips.make(for: candidateDisplayValue(candidate)) {
            symbolTipsWindow.show(tips, beside: anchorFrame)
            if let tipsFrame = symbolTipsWindow.visibleFrame {
                anchorFrame = anchorFrame.union(tipsFrame)
            }
        } else {
            symbolTipsWindow.hide()
        }
        showPreview(
            for: candidateDisplayValue(candidate),
            beside: previewAnchorFrame(base: anchorFrame),
            includeDefinitions: true
        )
    }

    private func previewAnchorFrame(base anchorFrame: NSRect) -> NSRect {
        var result = anchorFrame
        if let fuzzyFrame = secondaryCandidatePanel.visibleFrame {
            result = result.union(fuzzyFrame)
        }
        for translationFrame in panelCoordinator
            .visibleTranslationCandidateFrames {
            result = result.union(translationFrame)
        }
        if let emojiFrame = emojiWindow.visibleFrame {
            result = result.union(emojiFrame)
        }
        if let symbolTipsFrame = symbolTipsWindow.visibleFrame {
            result = result.union(symbolTipsFrame)
        }
        return result
    }

    private func showPreview(
        for candidate: String,
        beside anchorFrame: NSRect,
        includeDefinitions: Bool
    ) {
        let externalLookupEnabled = Self.featureSettings.isExternalInformationPanelEnabled
            && Self.diagnosticConfiguration.enables(
                .externalInformationPanel
            )
        let dictionaryLookupEnabled = Self.featureSettings.isSystemDictionaryPreviewEnabled
            && Self.diagnosticConfiguration.enables(.dictionaryPanel)
        guard externalLookupEnabled || dictionaryLookupEnabled
        else {
            candidateSearchCoordinator.cancel(.dictionaryDefinition)
            previewWindow.hide()
            return
        }
        let url = externalLookupEnabled
            ? try? SearchURLTemplate(externalInformationURLTemplate)
                .url(for: candidate)
            : nil

        candidateSearchCoordinator.cancel(.dictionaryDefinition)
        let presentsDictionary = Self.diagnosticConfiguration
            .presentsPanel(.dictionaryPanel)
        let presentsExternal = Self.diagnosticConfiguration
            .presentsPanel(.externalInformationPanel)
        trace("externalLookup.start", sender: client(), detail: "candidate=\(candidate)")
        let previewRequestID = previewWindow.show(
            url: url,
            panelTitle: url?.host ?? "外部情報",
            definitions: [],
            definitionsPending: includeDefinitions
                && dictionaryLookupEnabled,
            showExternalInformation: externalLookupEnabled,
            presentsDefinitionPanel: presentsDictionary,
            presentsExternalInformationPanel: presentsExternal,
            beside: anchorFrame
        )
        if presentsExternal {
            trace("externalPanel.show", sender: client())
        }
        guard includeDefinitions, dictionaryLookupEnabled else {
            return
        }
        guard let asyncSnapshot = currentInputSessionSnapshot() else {
            return
        }
        trace("dictionaryLookup.start", sender: client(), detail: "candidate=\(candidate)")
        let provider = definitionProvider
        let dictionaryNames = systemDictionaryNames
        candidateSearchCoordinator.start(
            .dictionaryDefinition,
            query: candidate,
            operation: {
                try await Task.sleep(for: .milliseconds(500))
                return await Task.detached(priority: .utility) {
                    provider.definitions(
                        for: candidate,
                        dictionaryNames: dictionaryNames
                    )
                }.value
            },
            validate: { [weak self] in
                guard let self else { return false }
                return self.acceptsAsyncResult(
                    asyncSnapshot,
                    source: "dictionaryLookup",
                    sender: self.client()
                )
            },
            apply: { [weak self] definitions in
                guard let self else { return }
                self.trace(
                    "dictionaryLookup.complete",
                    sender: self.client(),
                    detail: "candidate=\(candidate) count=\(definitions.count)"
                )
                self.previewWindow.showDefinitions(
                    definitions,
                    beside: anchorFrame,
                    requestID: previewRequestID,
                    presentsPanel: presentsDictionary
                )
                if presentsDictionary, !definitions.isEmpty {
                    self.trace(
                        "dictionaryPanel.show",
                        sender: self.client()
                    )
                }
            },
            retainQueryAfterCompletion: false
        )
    }

    private func rebuildConversionEngine() {
        dictionaryRuntime.rebuildUserLayers(
            userEntries: userDictionaryStore.entries,
            disabledImportedFilenames: Self.featureSettings
                .disabledImportedDictionaryFilenames
        )
        rebuildFuzzyConversionEngine()
    }

    private func reloadUserDictionaryFromDiskIfNeeded() {
        let storedEntries = Self.loadUserEntries()
        guard userDictionaryStore.replaceEntriesIfChanged(storedEntries) else {
            return
        }
        rebuildConversionEngine()
    }

    private func rebuildFuzzyConversionEngine() {
        cancelFuzzyCandidateSearch()
        candidateSearchCoordinator.cancel(.fuzzyIndexBuild)
        let userEntries = userDictionaryStore.entries
        let refreshSnapshot = currentInputSessionSnapshot()
        candidateSearchCoordinator.start(
            .fuzzyIndexBuild,
            query: "\(Self.sharedBasicFuzzyKey):\(userEntries.count)",
            operation: {
                await Task.detached(priority: .utility) {
                    Self.fuzzyEngineRepository.prepare(
                        baseEntries: Self.sharedBasicFuzzyEntries,
                        baseKey: Self.sharedBasicFuzzyKey,
                        userEntries: userEntries
                    )
                }.value
            },
            validate: { [weak self] in
                guard let self, let refreshSnapshot else { return false }
                return self.acceptsAsyncResult(
                    refreshSnapshot,
                    source: "fuzzyEngineBuild",
                    sender: self.client()
                ) && !self.inputBuffer.isEmpty && self.client() != nil
            },
            apply: { [weak self] _ in
                guard let self, let inputClient = self.client() else {
                    return
                }
                self.refreshCandidates(client: inputClient)
            },
            retainQueryAfterCompletion: false
        )
    }

    private var conversionReading: String {
        ConversionReadingResolver.resolve(conversionInput)
    }

    private var interactionState: InputInteractionState {
        InputInteractionState.resolve(
            hasInput: !inputBuffer.isEmpty,
            isRegisteringDictionary: dictionaryRegistrationSession != nil,
            hasSelectedCandidate: selectedCandidateIndex != nil,
            hasSelectedFuzzyCandidate: selectedFuzzyCandidateIndex != nil,
            hasSelectedNextInput:
                nextInputCandidateCoordinator.selectedIndex != nil
        )
    }

    private var conversionSuffix: String {
        let input = conversionInput
        if isCalculationExpressionDraft
            || !UnitConversionCandidateGenerator.candidates(
                for: input
            ).isEmpty
            || !NumberGroupingCandidateGenerator.candidates(
                for: input
            ).isEmpty
            || !JapaneseNumericUnitCandidateGenerator.candidates(
                for: input
            ).isEmpty
            || PostalCodeNormalizer.normalize(input) != nil
            || !JapaneseNumberConverter.candidates(for: input).isEmpty
            || !JapaneseSymbolConverter.candidates(for: input).isEmpty {
            return ""
        }
        return ConversionReadingSuffix.resolve(
            conversionReading: conversionReading,
            originalInput: input
        )
    }

    private var isCalculationExpressionDraft: Bool {
        inputBuffer.trimmingCharacters(in: .whitespaces).hasSuffix("=")
    }

    private var cachedJavaScriptCalculationCandidates: [String] {
        guard isCalculationExpressionDraft,
              candidateSearchCoordinator.query(for: .javaScriptExtensions)
                == inputBuffer else {
            return []
        }
        return javaScriptExtensionCandidates
    }

    private var selectedCandidateValue: String? {
        candidateSession.selectedCandidate
            .map {
                $0.commitText + conversionSuffix
            }
    }

    private var currentCandidates: [String] {
        candidateSession.candidateTexts
    }

    private var currentCandidateModels: [Candidate] {
        get { candidateSession.candidates }
        set { candidateSession.candidates = newValue }
    }

    private func isGeneratedParticleCandidate(_ value: String) -> Bool {
        currentCandidateModels.contains {
            ($0.storageText == value || $0.commitText == value)
                && $0.hasSource(.particleComposition)
                && $0.hasAttribute(.generated)
        }
    }

    private var selectedCandidateIndex: Int? {
        get { candidateSession.selectedIndex }
        set {
            candidateSession.selectedIndex = newValue
            trace(
                "candidateSelection.changed",
                sender: client(),
                detail: "standard=\(newValue.map(String.init) ?? "none")"
            )
            updateCandidateDeletionShortcutCapture()
        }
    }

    private var selectedFuzzyCandidateIndex: Int? {
        get { fuzzyCandidateSession.selectedIndex }
        set {
            _ = fuzzyCandidateSession.select(index: newValue)
            trace(
                "candidateSelection.changed",
                sender: client(),
                detail: "fuzzy=\(selectedFuzzyCandidateIndex.map(String.init) ?? "none")"
            )
            updateCandidateDeletionShortcutCapture()
        }
    }

    private var externalInformationURLTemplate: String {
        JavaScriptExtensionConfiguration.externalInformationURL(
            project: ""
        ) ?? defaultExternalInformationURLTemplate
    }

    private var defaultExternalInformationURLTemplate: String {
        "https://ja.wikipedia.org/w/index.php?search=%s"
    }

    private var webSearchTemplate: String {
        JavaScriptExtensionConfiguration.webSearchURL()
    }

    private var systemDictionaryNames: [String] {
        Self.featureSettings.systemDictionaryNames {
            let available = Set(definitionProvider.availableDictionaryNames())
            return SystemDictionaryDefinitionProvider.defaultDictionaryNames
                .filter { available.contains($0) }
        }
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
            return addingBundledRequiredEntries(
                to: cachedEntries,
                bundledEntries: entries
            )
        }
        return entries
    }

    private static func loadBundledEntries(resource: String) -> [DictionaryEntry] {
        guard let text = loadBundledText(resource: resource),
              let entries = try? DictionaryParser().parse(text) else {
            return []
        }
        return entries
    }

    private static func addingBundledRequiredEntries(
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
            "eject", "yajirushi", "migiyajirushi", "hidariyajirushi",
            "ueyajirushi", "shitayajirushi", "maru", "sankaku",
            "migisankaku", "hidarisankaku", "uesankaku",
            "shitasankaku", "shikaku", "hoshi", "puramain", "kakeru",
            "waru", "nottoikooru", "yakunari", "shounari", "dainari",
            "mugen", "ruuto", "shiguma", "sekibun", "komejirushi",
            "asutarisuku", "dagaa", "daburudagaa", "onpu", "furatto",
            "shaapu", "supe-do", "kurabu", "haato", "daiya", "en",
            "doru", "yuuro", "pondo", "sento", "won", "yuubin",
            "sesshi", "kashi", "nambaa", "tore-domaaku",
            "kopiiraito", "touroku", "nakaguro"
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

    private static var importedDictionaryStore: ImportedDictionaryStore {
        ImportedDictionaryStore(
            directoryURL: userDataURL(fileName: "imported-dictionaries")
        )
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

    private static func loadUnselectedInputLearningHistory()
        -> UnselectedInputLearningHistory {
        guard
            let data = try? Data(
                contentsOf: unselectedInputLearningHistoryURL()
            ),
            !data.isEmpty,
            let history = try? JSONDecoder().decode(
                UnselectedInputLearningHistory.self,
                from: data
            )
        else {
            return UnselectedInputLearningHistory()
        }
        return history
    }

    private static func unselectedInputLearningHistoryURL() -> URL {
        userDataURL(fileName: "unselected-input-learning.json")
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

    var containsJapaneseText: Bool {
        unicodeScalars.contains {
            switch $0.value {
            case 0x3040...0x30ff, 0x3400...0x4dbf, 0x4e00...0x9fff,
                 0xf900...0xfaff:
                true
            default:
                false
            }
        }
    }
}
