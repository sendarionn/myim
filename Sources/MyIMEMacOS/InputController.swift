@preconcurrency import AppKit
@preconcurrency import InputMethodKit
import MyIMECore

@objc(MyIMEInputController)
final class InputController: IMKInputController {
    private static let defaultDictionarySource = CosenseDictionarySource(
        project: "sendarionn-public",
        pageTitle: "dictionary"
    )
    private static let projectDefaultsKey = "CosenseExtensionProject"
    private static let maximumCandidateCount = 7

    private var inputBuffer = ""
    private var currentCandidates: [String] = []
    private var selectedCandidateIndex: Int?
    private var dictionarySource: CosenseDictionarySource
    private var basicEntries: [DictionaryEntry]
    private var extensionEntries: [DictionaryEntry]
    private var conversionEngine: ConversionEngine
    private var cosenseSyncStatus = "未実行"
    private var basicDictionaryStatus = "未確認"
    private let candidatePanel: IMKCandidates
    private let candidateWindow = CandidateWindowController()
    private let previewWindow = CosensePreviewWindowController()
    private let definitionProvider = SystemDictionaryDefinitionProvider()
    private let romajiConverter = RomajiConverter()

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        let source = Self.loadDictionarySource()
        let bundledEntries = Self.loadBasicEntries()
        let cachedExtensionEntries = Self.loadExtensionEntries(for: source)

        dictionarySource = source
        basicEntries = bundledEntries
        extensionEntries = cachedExtensionEntries
        conversionEngine = ConversionEngine(
            layers: [cachedExtensionEntries, bundledEntries]
        )
        candidatePanel = IMKCandidates(
            server: server,
            panelType: kIMKSingleColumnScrollingCandidatePanel
        )

        super.init(server: server, delegate: delegate, client: inputClient)

        candidatePanel.setDismissesAutomatically(true)
        candidatePanel.setAttributes([
            IMKCandidatesSendServerKeyEventFirst: true
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

        if event.keyCode == 15,
           event.modifierFlags.contains([.command, .option, .control]) {
            syncCosenseDictionary(nil)
            return true
        }

        switch event.keyCode {
        case 49:
            return handleSpace(client: sender)
        case 123, 126:
            return moveCandidate(by: -1, client: sender)
        case 124, 125:
            return moveCandidate(by: 1, client: sender)
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

        let isASCIIInput = characters.unicodeScalars.allSatisfy {
            (0x21...0x7e).contains($0.value)
        }
        guard isASCIIInput else {
            if !inputBuffer.isEmpty {
                commit(inputBuffer, to: sender)
            }
            return false
        }

        if let selectedValue = selectedCandidateValue {
            commit(selectedValue, to: sender)
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

        let updateBasicItem = NSMenuItem(
            title: "TKGJE基本辞書を更新",
            action: #selector(updateBasicDictionaryIfNeeded(_:)),
            keyEquivalent: ""
        )
        updateBasicItem.target = self
        menu.addItem(updateBasicItem)

        let projectItem = NSMenuItem(
            title: "拡張辞書: \(dictionarySource.projectURLDescription)",
            action: nil,
            keyEquivalent: ""
        )
        projectItem.isEnabled = false
        menu.addItem(projectItem)

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

        commit(
            candidateValueForCommit(candidate) + conversionSuffix,
            to: client() as Any
        )
    }

    override func commitComposition(_ sender: Any!) {
        guard let sender, !inputBuffer.isEmpty else {
            return
        }

        commit(inputBuffer, to: sender)
    }

    override func deactivateServer(_ sender: Any!) {
        if !inputBuffer.isEmpty {
            commit(inputBuffer, to: sender as Any)
        }
        candidatePanel.hide()
        candidateWindow.hide()
        previewWindow.hide()
        super.deactivateServer(sender)
    }

    override func inputControllerWillClose() {
        candidatePanel.hide()
        candidateWindow.hide()
        previewWindow.hide()
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

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else {
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
    private func syncCosenseDictionary(_ sender: Any?) {
        guard cosenseSyncStatus != "更新中" else {
            return
        }

        cosenseSyncStatus = "更新中"
        let source = dictionarySource

        Task { @MainActor [weak self] in
            do {
                let dictionaryText = try await CosenseDictionaryClient().fetch(
                    from: source
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
                self?.cosenseSyncStatus = "失敗"
                NSLog("Cosense辞書の更新に失敗: %@", error.localizedDescription)
            }
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
        moveCandidate(by: 1, client: sender)
    }

    private func moveCandidate(by offset: Int, client sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }

        guard !currentCandidates.isEmpty else {
            return true
        }

        let startingIndex = selectedCandidateIndex
            ?? (offset > 0 ? -1 : 0)
        let nextIndex = (
            startingIndex + offset + currentCandidates.count
        ) % currentCandidates.count
        selectedCandidateIndex = nextIndex
        showCandidateWindow(client: sender)
        setMarkedText(
            currentCandidates[nextIndex] + conversionSuffix,
            in: sender
        )
        showPreview(for: currentCandidates[nextIndex])
        return true
    }

    private func refreshCandidates(client sender: Any) {
        let symbolCandidates = JapaneseSymbolConverter.candidates(
            for: inputBuffer
        )
        if !symbolCandidates.isEmpty {
            currentCandidates = symbolCandidates
            showCandidateWindow(client: sender)
            return
        }

        let normalizedReading = RomanizedReadingNormalizer.dictionaryReading(
            from: conversionReading
        )
        var candidates = conversionEngine.candidates(
            matching: normalizedReading,
            limit: .max
        )
        if let hiragana = romajiConverter.hiragana(
            from: conversionReading
        ) {
            let katakana = romajiConverter.katakana(
                from: conversionReading
            )
            let kanaCandidates = [hiragana, katakana]
                .compactMap { $0 }
                .filter { !candidates.contains($0) }
            let exactCandidateCount = conversionEngine.candidates(
                for: normalizedReading
            ).count
            let insertionIndex = hiragana.count == 1
                ? 0
                : min(
                    exactCandidateCount,
                    Self.maximumCandidateCount - kanaCandidates.count
                )
            candidates.insert(
                contentsOf: kanaCandidates,
                at: insertionIndex
            )
        }
        currentCandidates = candidates

        guard !currentCandidates.isEmpty else {
            selectedCandidateIndex = nil
            candidateWindow.hide()
            previewWindow.hide()
            return
        }

        showCandidateWindow(client: sender)
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
            return false
        }

        let value = selectedCandidateValue ?? inputBuffer
        commit(value, to: sender)
        return true
    }

    private func deleteBackward(from sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }

        inputBuffer.removeLast()
        selectedCandidateIndex = nil
        candidatePanel.hide()
        previewWindow.hide()
        updateMarkedText(in: sender)
        refreshCandidates(client: sender)
        return true
    }

    private func cancelInput(in sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }

        selectedCandidateIndex = nil
        candidateWindow.clearSelection()
        previewWindow.hide()
        updateMarkedText(in: sender)
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
        currentCandidates = []
        selectedCandidateIndex = nil
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

    private func showPreview(for candidate: String) {
        guard let url = CosensePageURL.make(
            project: dictionarySource.project,
            pageTitle: candidate
        ) else {
            previewWindow.hide()
            return
        }

        previewWindow.showIfPageExists(
            project: dictionarySource.project,
            pageTitle: candidate,
            url: url,
            definitions: definitionProvider.definitions(for: candidate),
            beside: candidateWindow.frame
        )
    }

    private func rebuildConversionEngine() {
        conversionEngine = ConversionEngine(
            layers: [extensionEntries, basicEntries]
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

private extension CosenseDictionarySource {
    var projectURLDescription: String {
        "https://scrapbox.io/\(project)"
    }
}
