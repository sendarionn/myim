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
    private let conversionEngine: ConversionEngine
    private let candidatePanel: IMKCandidates
    private let candidateWindow = CandidateWindowController()
    private let previewWindow = CosensePreviewWindowController()

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

        switch event.keyCode {
        case 49:
            return handleSpace()
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
        currentCandidates = []
        selectedCandidateIndex = nil
        candidatePanel.hide()
        candidateWindow.hide()
        previewWindow.hide()
        updateMarkedText(in: sender)
        return true
    }

    override func candidates(_ sender: Any!) -> [Any]! {
        currentCandidates
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

    private func beginConversion() -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }

        currentCandidates = conversionEngine.candidates(for: inputBuffer)
        guard let firstCandidate = currentCandidates.first else {
            return true
        }

        selectedCandidateIndex = 0
        candidatePanel.update()
        candidatePanel.show(kIMKLocateCandidatesBelowHint)
        let anchorFrame = candidatePanel.candidateFrame()
        candidatePanel.hide()
        candidateWindow.show(
            candidates: currentCandidates,
            selectedIndex: 0,
            near: anchorFrame
        )
        showPreview(for: firstCandidate)
        return true
    }

    private func handleSpace() -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }

        if currentCandidates.isEmpty {
            return beginConversion()
        }

        let nextIndex = ((selectedCandidateIndex ?? -1) + 1)
            % currentCandidates.count
        selectedCandidateIndex = nextIndex
        candidateWindow.select(index: nextIndex)
        showPreview(for: currentCandidates[nextIndex])
        return true
    }

    private func commitFirstCandidateOrInput(to sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }

        let value = selectedCandidateIndex
            .flatMap { currentCandidates.indices.contains($0) ? currentCandidates[$0] : nil }
            ?? currentCandidates.first
            ?? inputBuffer
        commit(value, to: sender)
        return true
    }

    private func deleteBackward(from sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }

        inputBuffer.removeLast()
        currentCandidates = []
        selectedCandidateIndex = nil
        candidatePanel.hide()
        candidateWindow.hide()
        previewWindow.hide()
        updateMarkedText(in: sender)
        return true
    }

    private func cancelInput(in sender: Any) -> Bool {
        guard !inputBuffer.isEmpty else {
            return false
        }

        inputBuffer = ""
        currentCandidates = []
        selectedCandidateIndex = nil
        candidatePanel.hide()
        candidateWindow.hide()
        previewWindow.hide()
        setMarkedText("", in: sender)
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
