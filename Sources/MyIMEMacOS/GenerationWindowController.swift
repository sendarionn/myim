@preconcurrency import AppKit

private final class GenerationTextView: NSTextView {
    override func doCommand(by selector: Selector) {
        switch NSStringFromSelector(selector) {
        case "insertTab:":
            window?.selectNextKeyView(nil)
        case "insertBacktab:":
            window?.selectPreviousKeyView(nil)
        default:
            super.doCommand(by: selector)
        }
    }
}

final class GenerationWindowController: NSObject, NSWindowDelegate {
    private let panel: NSPanel
    private let requirementsView = GenerationTextView()
    private let purposeView = GenerationTextView()
    private let generateButton: NSButton
    private let cancelButton: NSButton
    private let statusLabel = NSTextField(labelWithString: "")
    private var generationTask: Task<Void, Never>?
    private var completion: ((String) -> Void)?

    override init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 390),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        generateButton = NSButton(title: "生成", target: nil, action: nil)
        cancelButton = NSButton(title: "キャンセル", target: nil, action: nil)
        super.init()
        panel.title = "生成モード"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.delegate = self

        let content = NSView(frame: panel.contentView?.bounds ?? .zero)
        content.autoresizingMask = [.width, .height]
        panel.contentView = content

        addLabel("要件", frame: NSRect(x: 20, y: 348, width: 480, height: 22), to: content)
        content.addSubview(makeScrollView(for: requirementsView, frame: NSRect(x: 20, y: 220, width: 480, height: 126)))
        addLabel("目的", frame: NSRect(x: 20, y: 190, width: 480, height: 22), to: content)
        content.addSubview(makeScrollView(for: purposeView, frame: NSRect(x: 20, y: 62, width: 480, height: 126)))

        statusLabel.frame = NSRect(x: 20, y: 22, width: 300, height: 24)
        statusLabel.textColor = .secondaryLabelColor
        content.addSubview(statusLabel)

        generateButton.frame = NSRect(x: 410, y: 16, width: 90, height: 32)
        generateButton.target = self
        generateButton.action = #selector(generate(_:))
        generateButton.keyEquivalent = "\r"
        generateButton.keyEquivalentModifierMask = [.command]
        content.addSubview(generateButton)

        cancelButton.frame = NSRect(x: 310, y: 16, width: 96, height: 32)
        cancelButton.target = self
        cancelButton.action = #selector(cancel(_:))
        cancelButton.keyEquivalent = "\u{1b}"
        content.addSubview(cancelButton)

        requirementsView.nextKeyView = purposeView
        purposeView.nextKeyView = requirementsView
    }

    func show(completion: @escaping (String) -> Void) {
        self.completion = completion
        statusLabel.stringValue = ""
        generateButton.isEnabled = true
        requirementsView.string = ""
        purposeView.string = ""
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
        panel.makeFirstResponder(requirementsView)
    }

    @objc private func generate(_ sender: Any?) {
        let requirements = requirementsView.string
        let purpose = purposeView.string
        guard !requirements.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                || !purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            statusLabel.stringValue = "要件か目的を入力してください"
            NSSound.beep()
            return
        }
        generationTask?.cancel()
        generateButton.isEnabled = false
        statusLabel.stringValue = "生成中…"
        generationTask = Task { @MainActor [weak self] in
            do {
                let text = try await FoundationModelsTextGenerator.generate(
                    requirements: requirements,
                    purpose: purpose
                )
                guard !Task.isCancelled, let self else { return }
                guard !text.isEmpty else {
                    statusLabel.stringValue = "文章を生成できませんでした"
                    generateButton.isEnabled = true
                    return
                }
                panel.orderOut(nil)
                completion?(text)
                completion = nil
            } catch {
                guard !Task.isCancelled, let self else { return }
                statusLabel.stringValue = error.localizedDescription
                generateButton.isEnabled = true
            }
        }
    }

    @objc private func cancel(_ sender: Any?) {
        generationTask?.cancel()
        generationTask = nil
        completion = nil
        panel.orderOut(nil)
    }

    func windowWillClose(_ notification: Notification) {
        cancel(nil)
    }

    private func addLabel(_ text: String, frame: NSRect, to content: NSView) {
        let label = NSTextField(labelWithString: text)
        label.font = .systemFont(ofSize: 14, weight: .semibold)
        label.frame = frame
        content.addSubview(label)
    }

    private func makeScrollView(for textView: NSTextView, frame: NSRect) -> NSScrollView {
        textView.frame = NSRect(origin: .zero, size: frame.size)
        textView.minSize = NSSize(width: 0, height: frame.height)
        textView.maxSize = NSSize(
            width: CGFloat.greatestFiniteMagnitude,
            height: CGFloat.greatestFiniteMagnitude
        )
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.autoresizingMask = [.width]
        textView.textContainer?.widthTracksTextView = true
        textView.font = .systemFont(ofSize: 15)
        textView.isRichText = false
        textView.isAutomaticQuoteSubstitutionEnabled = false
        textView.textContainerInset = NSSize(width: 6, height: 6)
        let scrollView = NSScrollView(frame: frame)
        scrollView.borderType = .bezelBorder
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.documentView = textView
        return scrollView
    }
}
