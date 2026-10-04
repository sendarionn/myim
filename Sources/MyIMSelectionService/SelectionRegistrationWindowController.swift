import AppKit
import MyIMECore
import os

final class SelectionRegistrationWindowController: NSObject,
    NSTextFieldDelegate,
    NSTextViewDelegate,
    NSWindowDelegate
{
    private static let logger = Logger(
        subsystem: "io.github.sendarionn.inputmethod.myime",
        category: "selection-service"
    )
    private let readingField = NSTextField()
    private let displayField = NSTextField()
    private let insertedTextView = NSTextView()
    private let registerButton = NSButton()
    private lazy var window = makeWindow()

    func show(prefilledInsertedText: String) {
        readingField.stringValue = ""
        displayField.stringValue = ""
        insertedTextView.string = prefilledInsertedText
        updateRegisterButton()

        NSApp.activate(ignoringOtherApps: true)
        window.center()
        window.makeKeyAndOrderFront(nil)
        window.makeFirstResponder(readingField)
    }

    func controlTextDidChange(_ notification: Notification) {
        updateRegisterButton()
    }

    func textDidChange(_ notification: Notification) {
        updateRegisterButton()
    }

    func windowWillClose(_ notification: Notification) {
        clearFields()
    }

    @objc
    private func register(_ sender: Any?) {
        guard let completion = registrationCompletion() else {
            NSSound.beep()
            return
        }

        do {
            let cache = try Self.userDictionaryCache()
            let entries = try Self.loadEntries(from: cache)
            let store = UserDictionaryStore(entries: entries) { updated in
                try cache.save(
                    dictionaryText: DictionarySerializer.text(from: updated),
                    metadata: DictionaryCacheMetadata(
                        syncedAt: Date(),
                        entryCount: updated.count
                    )
                )
            }
            try store.add(
                reading: completion.reading,
                candidate: completion.output,
                display: completion.display
            )
            Self.logger.notice("dictionary registration succeeded")
            window.close()
        } catch {
            Self.logger.error(
                "dictionary registration failed reason=\(error.localizedDescription, privacy: .public)"
            )
            presentSaveError(error)
        }
    }

    @objc
    private func cancel(_ sender: Any?) {
        window.close()
    }

    private func registrationCompletion() -> DictionaryRegistrationCompletion? {
        guard let reading = UserDictionaryRegistrationReading.resolve(
            conversionReading: readingField.stringValue,
            originalInput: readingField.stringValue
        ) else {
            return nil
        }
        let display = displayField.stringValue
        let insertedText = insertedTextView.string
        guard !display.isEmpty, !insertedText.isEmpty else {
            return nil
        }

        var session = DictionaryRegistrationSession(
            originalInput: readingField.stringValue,
            reading: reading,
            prefilledInsertedText: insertedText
        )
        session.appendConfirmed(display)
        return session.completionWhenInputIsEmpty()
    }

    private func updateRegisterButton() {
        registerButton.isEnabled = registrationCompletion() != nil
    }

    private func clearFields() {
        readingField.stringValue = ""
        displayField.stringValue = ""
        insertedTextView.string = ""
        updateRegisterButton()
    }

    private func makeWindow() -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 330),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "ユーザー辞書登録"
        window.isReleasedWhenClosed = false
        window.delegate = self
        window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]

        readingField.delegate = self
        displayField.delegate = self
        readingField.placeholderString = "読み"
        displayField.placeholderString = "候補表示"

        insertedTextView.delegate = self
        insertedTextView.isRichText = false
        insertedTextView.isAutomaticQuoteSubstitutionEnabled = false
        insertedTextView.isAutomaticDashSubstitutionEnabled = false
        insertedTextView.isAutomaticTextReplacementEnabled = false
        insertedTextView.isAutomaticSpellingCorrectionEnabled = false
        insertedTextView.font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
        insertedTextView.textContainerInset = NSSize(width: 5, height: 5)

        let insertedScrollView = NSScrollView()
        insertedScrollView.borderType = .bezelBorder
        insertedScrollView.hasVerticalScroller = true
        insertedScrollView.documentView = insertedTextView
        insertedScrollView.translatesAutoresizingMaskIntoConstraints = false
        insertedScrollView.heightAnchor.constraint(equalToConstant: 130).isActive = true

        registerButton.title = "登録"
        registerButton.bezelStyle = .rounded
        registerButton.keyEquivalent = "\r"
        registerButton.target = self
        registerButton.action = #selector(register(_:))

        let cancelButton = NSButton(
            title: "キャンセル",
            target: self,
            action: #selector(cancel(_:))
        )
        cancelButton.bezelStyle = .rounded
        cancelButton.keyEquivalent = "\u{1b}"

        let buttons = NSStackView(views: [cancelButton, registerButton])
        buttons.orientation = .horizontal
        buttons.alignment = .centerY
        buttons.spacing = 8

        let root = NSStackView(views: [
            labeledRow("読み", control: readingField),
            labeledRow("候補表示", control: displayField),
            labeledColumn("挿入文字列", control: insertedScrollView),
            buttons
        ])
        root.orientation = .vertical
        root.alignment = .trailing
        root.spacing = 14
        root.translatesAutoresizingMaskIntoConstraints = false

        let contentView = NSView()
        contentView.addSubview(root)
        window.contentView = contentView
        NSLayoutConstraint.activate([
            root.leadingAnchor.constraint(
                equalTo: contentView.leadingAnchor,
                constant: 20
            ),
            root.trailingAnchor.constraint(
                equalTo: contentView.trailingAnchor,
                constant: -20
            ),
            root.topAnchor.constraint(
                equalTo: contentView.topAnchor,
                constant: 20
            ),
            root.bottomAnchor.constraint(
                equalTo: contentView.bottomAnchor,
                constant: -20
            ),
            insertedScrollView.widthAnchor.constraint(equalTo: root.widthAnchor)
        ])
        return window
    }

    private func labeledRow(_ title: String, control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.alignment = .right
        label.setContentHuggingPriority(.required, for: .horizontal)
        control.translatesAutoresizingMaskIntoConstraints = false
        control.widthAnchor.constraint(
            greaterThanOrEqualToConstant: 380
        ).isActive = true
        let row = NSStackView(views: [label, control])
        row.orientation = .horizontal
        row.alignment = .centerY
        row.spacing = 12
        return row
    }

    private func labeledColumn(_ title: String, control: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        let stack = NSStackView(views: [label, control])
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 6
        return stack
    }

    private func presentSaveError(_ error: Error) {
        let alert = NSAlert()
        alert.messageText = "ユーザー辞書へ登録できませんでした"
        alert.informativeText = error.localizedDescription
        alert.alertStyle = .warning
        alert.beginSheetModal(for: window)
    }

    private static func userDictionaryCache() throws -> DictionaryCache {
        let applicationCache = try DictionaryCache.applicationSupport()
        return DictionaryCache(
            directoryURL: applicationCache.directoryURL
                .appendingPathComponent("user", isDirectory: true)
        )
    }

    private static func loadEntries(
        from cache: DictionaryCache
    ) throws -> [DictionaryEntry] {
        guard let readableURL = cache.readableDictionaryURL() else {
            return []
        }
        let text = try String(contentsOf: readableURL, encoding: .utf8)
        return try DictionaryParser().parse(text)
    }
}
