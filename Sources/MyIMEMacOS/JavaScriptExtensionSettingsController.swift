@preconcurrency import AppKit
import MyIMECore

private final class TopAlignedExtensionStackView: NSStackView {
    override var isFlipped: Bool { true }
}

final class JavaScriptExtensionSettingsController: NSObject {
    private let client: JavaScriptExtensionClient
    private var panel: NSPanel?
    private var contentStack: NSStackView?
    private var scrollView: NSScrollView?
    private var selectedUpdateFileNames = Set<String>()
    private var updateError: String?
    private var shouldOfferUpdateConfirmation = false
    private var isPresentingUpdateConfirmation = false

    init(client: JavaScriptExtensionClient) {
        self.client = client
    }

    func show() {
        let isNewPresentation = panel?.isVisible != true
        let panel = panel ?? makePanel()
        self.panel = panel
        if isNewPresentation {
            shouldOfferUpdateConfirmation = true
        }
        refresh()
        NSApp.activate(ignoringOtherApps: true)
        panel.center()
        panel.makeKeyAndOrderFront(nil)
    }

    @objc
    private func toggleExtension(_ sender: NSButton) {
        guard let fileName = sender.identifier?.rawValue else { return }
        JavaScriptExtensionClient.setEnabled(
            sender.state == .on,
            fileName: fileName
        )
        refresh()
    }

    @objc
    private func reloadExtensions(_ sender: Any?) {
        Task { [weak self] in
            guard let self else { return }
            await client.reload()
            await MainActor.run { self.refresh() }
        }
    }

    @objc
    private func openExtensionDirectory(_ sender: Any?) {
        guard let directory = JavaScriptExtensionClient
            .prepareUserExtensionDirectory() else { return }
        JavaScriptExtensionDirectoryPresenter.open(directory)
    }

    @objc
    private func toggleUpdateSelection(_ sender: NSButton) {
        guard let fileName = sender.identifier?.rawValue else { return }
        if sender.state == .on {
            selectedUpdateFileNames.insert(fileName)
        } else {
            selectedUpdateFileNames.remove(fileName)
        }
    }

    @objc
    private func updateSelectedExtensions(_ sender: Any?) {
        resolveSelectedExtensions(as: .update)
    }

    @objc
    private func keepSelectedExtensions(_ sender: Any?) {
        resolveSelectedExtensions(as: .keep)
    }

    @objc
    private func updateKeptExtension(_ sender: NSButton) {
        guard let fileName = sender.identifier?.rawValue else { return }
        resolveExtensions([fileName], as: .update)
    }

    private func resolveSelectedExtensions(
        as resolution: DefaultExtensionConflictResolution
    ) {
        let fileNames = selectedUpdateFileNames
        guard !fileNames.isEmpty else { return }
        resolveExtensions(fileNames, as: resolution)
    }

    private func resolveExtensions(
        _ fileNames: Set<String>,
        as resolution: DefaultExtensionConflictResolution
    ) {
        Task { [weak self] in
            guard let self else { return }
            let error = await client.resolveExtensionUpdates(
                fileNames: fileNames,
                resolution: resolution
            )
            await MainActor.run {
                self.updateError = error
                self.selectedUpdateFileNames.removeAll()
                self.refresh()
            }
        }
    }

    private func refresh() {
        Task { [weak self] in
            guard let self else { return }
            await client.validateExtensions()
            let result = await client.extensionInfos()
            await MainActor.run {
                self.render(
                    items: result.items,
                    runtimeError: result.runtimeError
                )
            }
        }
    }

    private func makePanel() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 420),
            styleMask: [.titled, .closable, .resizable],
            backing: .buffered,
            defer: false
        )
        panel.animationBehavior = .none
        panel.title = "JavaScript拡張"
        panel.isReleasedWhenClosed = false
        panel.hidesOnDeactivate = false
        panel.level = .normal
        panel.minSize = NSSize(width: 640, height: 300)

        let root = NSStackView()
        root.orientation = .vertical
        root.alignment = .leading
        root.spacing = 10
        root.edgeInsets = NSEdgeInsets(top: 16, left: 18, bottom: 16, right: 18)

        let toolbar = NSStackView()
        toolbar.orientation = .horizontal
        toolbar.spacing = 8
        toolbar.addArrangedSubview(
            NSButton(
                title: "再読み込み",
                target: self,
                action: #selector(reloadExtensions(_:))
            )
        )
        toolbar.addArrangedSubview(
            NSButton(
                title: "Finderで表示",
                target: self,
                action: #selector(openExtensionDirectory(_:))
            )
        )
        root.addArrangedSubview(toolbar)

        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.borderType = .bezelBorder
        scrollView.translatesAutoresizingMaskIntoConstraints = false

        let contentStack = TopAlignedExtensionStackView()
        contentStack.orientation = .vertical
        contentStack.alignment = .leading
        contentStack.spacing = 8
        contentStack.edgeInsets = NSEdgeInsets(
            top: 12,
            left: 12,
            bottom: 12,
            right: 12
        )
        scrollView.documentView = contentStack
        contentStack.frame = NSRect(x: 0, y: 0, width: 540, height: 280)
        self.contentStack = contentStack
        self.scrollView = scrollView
        root.addArrangedSubview(scrollView)

        panel.contentView = root
        NSLayoutConstraint.activate([
            scrollView.widthAnchor.constraint(equalTo: root.widthAnchor, constant: -36),
            scrollView.heightAnchor.constraint(greaterThanOrEqualToConstant: 280)
        ])
        return panel
    }

    private func render(
        items: [JavaScriptExtensionClient.ExtensionInfo],
        runtimeError: String?
    ) {
        guard let stack = contentStack else { return }
        for view in stack.arrangedSubviews {
            stack.removeArrangedSubview(view)
            view.removeFromSuperview()
        }

        if let runtimeError {
            let label = NSTextField(labelWithString: runtimeError)
            label.textColor = .systemRed
            label.maximumNumberOfLines = 2
            stack.addArrangedSubview(label)
        }
        if let updateError {
            let label = NSTextField(labelWithString: updateError)
            label.textColor = .systemRed
            label.maximumNumberOfLines = 2
            stack.addArrangedSubview(label)
        }
        guard !items.isEmpty else {
            stack.addArrangedSubview(
                NSTextField(labelWithString: ".jsファイルがありません")
            )
            updateContentFrame(stack)
            return
        }

        let conflicts = items.filter { $0.updateState == .updateAvailable }
        if !conflicts.isEmpty {
            if selectedUpdateFileNames.isEmpty {
                selectedUpdateFileNames = Set(conflicts.map(\.fileName))
            } else {
                selectedUpdateFileNames.formIntersection(
                    conflicts.map(\.fileName)
                )
            }
            let actions = NSStackView()
            actions.orientation = .horizontal
            actions.spacing = 8
            actions.addArrangedSubview(NSButton(
                title: "選択したものを更新",
                target: self,
                action: #selector(updateSelectedExtensions(_:))
            ))
            actions.addArrangedSubview(NSButton(
                title: "選択したものを維持",
                target: self,
                action: #selector(keepSelectedExtensions(_:))
            ))
            stack.addArrangedSubview(actions)
        } else {
            selectedUpdateFileNames.removeAll()
        }

        for item in items {
            let row = NSStackView()
            row.orientation = .horizontal
            row.alignment = .centerY
            row.spacing = 12

            let toggle = NSButton(
                checkboxWithTitle: item.fileName,
                target: self,
                action: #selector(toggleExtension(_:))
            )
            toggle.identifier = NSUserInterfaceItemIdentifier(item.fileName)
            toggle.state = item.isEnabled ? .on : .off
            toggle.widthAnchor.constraint(equalToConstant: 200).isActive = true
            row.addArrangedSubview(toggle)

            let prefix = NSTextField(
                labelWithString: item.prefix.map { "prefix: \($0)" } ?? "prefix: すべて"
            )
            prefix.textColor = .secondaryLabelColor
            prefix.widthAnchor.constraint(equalToConstant: 130).isActive = true
            row.addArrangedSubview(prefix)

            let status = NSTextField(labelWithString: statusText(for: item))
            status.textColor = statusColor(for: item)
            status.lineBreakMode = .byTruncatingTail
            row.addArrangedSubview(status)
            if item.updateState == .updateAvailable {
                let selection = NSButton(
                    checkboxWithTitle: "更新",
                    target: self,
                    action: #selector(toggleUpdateSelection(_:))
                )
                selection.identifier = NSUserInterfaceItemIdentifier(
                    item.fileName
                )
                selection.state = selectedUpdateFileNames.contains(
                    item.fileName
                ) ? .on : .off
                row.addArrangedSubview(selection)
            } else if item.updateState == .updateKept {
                let update = NSButton(
                    title: "更新する",
                    target: self,
                    action: #selector(updateKeptExtension(_:))
                )
                update.identifier = NSUserInterfaceItemIdentifier(
                    item.fileName
                )
                row.addArrangedSubview(update)
            }
            stack.addArrangedSubview(row)
        }
        updateContentFrame(stack)
        offerUpdateConfirmationIfNeeded(for: conflicts)
    }

    private func offerUpdateConfirmationIfNeeded(
        for conflicts: [JavaScriptExtensionClient.ExtensionInfo]
    ) {
        guard shouldOfferUpdateConfirmation else { return }
        shouldOfferUpdateConfirmation = false
        guard !conflicts.isEmpty,
              !isPresentingUpdateConfirmation,
              let panel else { return }
        isPresentingUpdateConfirmation = true
        let fileNames = Set(conflicts.map(\.fileName))
        let alert = NSAlert()
        alert.messageText = "標準JavaScript拡張を更新しますか"
        alert.informativeText = """
        ローカルで変更された標準拡張に更新があります

        \(fileNames.sorted().joined(separator: "\n"))

        更新すると同梱の新しい内容に置き換え、現在のファイルをバックアップします
        更新しない場合は現在の内容を維持します
        """
        alert.addButton(withTitle: "更新する")
        alert.addButton(withTitle: "更新しない")
        alert.beginSheetModal(for: panel) { [weak self] response in
            guard let self else { return }
            self.isPresentingUpdateConfirmation = false
            let resolution: DefaultExtensionConflictResolution =
                response == .alertFirstButtonReturn ? .update : .keep
            self.resolveExtensions(fileNames, as: resolution)
        }
    }

    private func updateContentFrame(_ stack: NSStackView) {
        guard let scrollView else { return }
        stack.layoutSubtreeIfNeeded()
        let contentSize = scrollView.contentSize
        let fittingHeight = stack.fittingSize.height
        stack.frame = NSRect(
            x: 0,
            y: 0,
            width: max(contentSize.width, 1),
            height: max(fittingHeight, contentSize.height)
        )
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func statusText(
        for item: JavaScriptExtensionClient.ExtensionInfo
    ) -> String {
        let updateStatus = switch item.updateState {
        case .bundledCurrent:
            "同梱拡張 · 最新"
        case .bundledModified:
            "同梱拡張 · ローカル変更あり"
        case .updateAvailable:
            "同梱拡張 · 更新あり · ローカル変更あり"
        case .updateKept:
            "同梱拡張 · 古いバージョンを維持中"
        case .userExtension:
            "ユーザー拡張"
        }
        guard item.isEnabled else { return updateStatus + " · 無効" }
        switch item.status?.state {
        case .ready:
            return updateStatus
        case .error:
            return updateStatus + " · " + (item.status?.message ?? "エラー")
        case .disabled:
            return updateStatus + " · 無効"
        case nil:
            return updateStatus
        }
    }

    private func statusColor(
        for item: JavaScriptExtensionClient.ExtensionInfo
    ) -> NSColor {
        guard item.isEnabled else { return .secondaryLabelColor }
        if item.status?.state == .error { return .systemRed }
        if item.updateState == .updateAvailable { return .systemOrange }
        return .secondaryLabelColor
    }
}
