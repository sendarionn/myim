@preconcurrency import AppKit
@preconcurrency import InputMethodKit
import MyIMECore

@objc(MyIMEInputController)
final class InputController: IMKInputController {
    private static let dictionarySource = CosenseDictionarySource(
        project: "sendarionn-public",
        pageTitle: "dictionary"
    )

    private var inputBuffer = ""
    private var currentCandidates: [String] = []
    private var selectedCandidateIndex: Int?
    private var conversionEngine: ConversionEngine
    private var dictionarySyncStatus = "未実行"
    private let candidatePanel: IMKCandidates
    private let candidateWindow = CandidateWindowController()
    private let previewWindow = CosensePreviewWindowController()
    private let definitionProvider = SystemDictionaryDefinitionProvider()

    override init!(server: IMKServer!, delegate: Any!, client inputClient: Any!) {
        conversionEngine = Self.loadConversionEngine()
        candidatePanel = IMKCandidates(
            server: server,
            panelType: kIMKSingleColumnScrollingCandidatePanel
        )

        super.init(server: server, delegate: delegate, client: inputClient)

        candidatePanel.setDismissesAutomatically(true)
        candidatePanel.setAttributes([
            IMKCandidatesSendServerKeyEventFirst: true
        ])
    }

    override func handle(_ event: NSEvent!, client sender: Any!) -> Bool {
        guard let event, let sender else {
            return false
        }

        guard event.type == .keyDown else {
            return false
        }

        if event.keyCode == 15,
           event.modifierFlags.contains([.command, .shift]) {
            syncCosenseDictionary(nil)
            return true
        }

        switch event.keyCode {
        case 49:
            return handleSpace(client: sender)
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
            !characters.isEmpty,
            characters.unicodeScalars.allSatisfy({ scalar in
                CharacterSet.letters.contains(scalar)
                    && scalar.isASCII
            })
        else {
            if !inputBuffer.isEmpty {
                commit(inputBuffer, to: sender)
            }
            return false
        }

        inputBuffer += characters.lowercased()
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
        syncItem.keyEquivalentModifierMask = [.command, .shift]
        syncItem.target = self
        menu.addItem(syncItem)

        let statusItem = NSMenuItem(
            title: "辞書更新: \(dictionarySyncStatus)",
            action: nil,
            keyEquivalent: ""
        )
        statusItem.isEnabled = false
        menu.addItem(statusItem)
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

        commit(candidate, to: client() as Any)
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
    private func syncCosenseDictionary(_ sender: Any?) {
        guard dictionarySyncStatus != "更新中" else {
            return
        }

        dictionarySyncStatus = "更新中"

        Task { @MainActor [weak self] in
            do {
                let dictionaryText = try await CosenseDictionaryClient().fetch(
                    from: Self.dictionarySource
                )
                let entries = try DictionaryParser().parse(dictionaryText)
                guard !entries.isEmpty else {
                    throw CosenseDictionaryError.emptyDictionary
                }

                let cache = try DictionaryCache.applicationSupport()
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
                conversionEngine = ConversionEngine(entries: entries)
                dictionarySyncStatus = "完了（\(entries.count)読み）"

                if !inputBuffer.isEmpty, let inputClient = client() {
                    selectedCandidateIndex = nil
                    previewWindow.hide()
                    refreshCandidates(client: inputClient)
                }
            } catch {
                self?.dictionarySyncStatus = "失敗"
                NSLog("Cosense辞書の更新に失敗: %@", error.localizedDescription)
            }
        }
    }

    private func handleSpace(client sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }

        guard !currentCandidates.isEmpty else {
            return true
        }

        let nextIndex = ((selectedCandidateIndex ?? -1) + 1)
            % currentCandidates.count
        selectedCandidateIndex = nextIndex
        candidateWindow.select(index: nextIndex)
        setMarkedText(currentCandidates[nextIndex], in: sender)
        showPreview(for: currentCandidates[nextIndex])
        return true
    }

    private func refreshCandidates(client sender: Any) {
        currentCandidates = conversionEngine.candidates(matching: inputBuffer)

        guard !currentCandidates.isEmpty else {
            selectedCandidateIndex = nil
            candidateWindow.hide()
            previewWindow.hide()
            return
        }

        candidateWindow.show(
            candidates: currentCandidates,
            selectedIndex: selectedCandidateIndex,
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

        let value = selectedCandidateIndex
            .flatMap { currentCandidates.indices.contains($0) ? currentCandidates[$0] : nil }
            ?? inputBuffer
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
            project: Self.dictionarySource.project,
            pageTitle: candidate
        ) else {
            previewWindow.hide()
            return
        }

        previewWindow.show(
            url: url,
            definitions: definitionProvider.definitions(for: candidate),
            beside: candidateWindow.frame
        )
    }

    private static func loadConversionEngine() -> ConversionEngine {
        guard
            let cache = try? DictionaryCache.applicationSupport(),
            cache.containsDictionary(),
            let dictionaryText = try? String(
                contentsOf: cache.dictionaryURL,
                encoding: .utf8
            ),
            let entries = try? DictionaryParser().parse(dictionaryText)
        else {
            return ConversionEngine(entries: [])
        }

        return ConversionEngine(entries: entries)
    }
}
