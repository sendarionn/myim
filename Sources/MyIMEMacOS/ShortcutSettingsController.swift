import AppKit

private final class ShortcutRecorderButton: NSButton {
    let feature: MyIMFeatureShortcut
    private var isRecording = false

    init(feature: MyIMFeatureShortcut) {
        self.feature = feature
        super.init(frame: .zero)
        title = feature.shortcut.displayName
        bezelStyle = .rounded
        setButtonType(.momentaryPushIn)
    }

    required init?(coder: NSCoder) { nil }
    override var acceptsFirstResponder: Bool { true }

    override func mouseDown(with event: NSEvent) {
        isRecording = true
        title = "キーを入力"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53,
           event.modifierFlags.intersection([.command, .option, .control]).isEmpty {
            finishRecording()
            return
        }
        guard let shortcut = MyIMShortcut(event: event) else {
            NSSound.beep()
            return
        }
        feature.save(shortcut)
        finishRecording()
    }

    override func resignFirstResponder() -> Bool {
        let result = super.resignFirstResponder()
        if result { finishRecording(makeFirstResponder: false) }
        return result
    }

    func refresh() {
        guard !isRecording else { return }
        title = feature.shortcut.displayName
    }

    private func finishRecording(makeFirstResponder: Bool = true) {
        isRecording = false
        title = feature.shortcut.displayName
        if makeFirstResponder { window?.makeFirstResponder(nil) }
    }
}

final class ShortcutSettingsController: NSObject {
    private var panel: NSPanel?
    private var recorderButtons: [ShortcutRecorderButton] = []

    func show() {
        if let panel {
            recorderButtons.forEach { $0.refresh() }
            NSApp.activate(ignoringOtherApps: true)
            panel.makeKeyAndOrderFront(nil)
            return
        }
        let panel = makePanel()
        self.panel = panel
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 300),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        panel.title = "ショートカット"
        panel.isReleasedWhenClosed = false

        let stack = NSStackView()
        stack.orientation = .vertical
        stack.alignment = .leading
        stack.spacing = 10
        stack.edgeInsets = NSEdgeInsets(top: 18, left: 20, bottom: 18, right: 20)
        for feature in MyIMFeatureShortcut.allCases {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12
            let label = NSTextField(labelWithString: feature.title)
            label.widthAnchor.constraint(equalToConstant: 150).isActive = true
            let recorder = ShortcutRecorderButton(feature: feature)
            recorder.widthAnchor.constraint(equalToConstant: 150).isActive = true
            recorderButtons.append(recorder)
            row.addArrangedSubview(label)
            row.addArrangedSubview(recorder)
            stack.addArrangedSubview(row)
        }
        let reset = NSButton(
            title: "標準に戻す",
            target: self,
            action: #selector(resetShortcuts(_:))
        )
        stack.addArrangedSubview(reset)
        panel.contentView = stack
        return panel
    }

    @objc private func resetShortcuts(_ sender: Any?) {
        MyIMFeatureShortcut.allCases.forEach { $0.reset() }
        recorderButtons.forEach { $0.refresh() }
    }
}
