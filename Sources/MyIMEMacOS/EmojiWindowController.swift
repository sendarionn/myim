@preconcurrency import AppKit

final class EmojiWindowController: NSObject {
    static let columnCount = 8
    private static let cellSize: CGFloat = 34
    private static let spacing: CGFloat = 2
    private static let emojis = Array(
        "😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 ☹️ 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🫡 🤭 🫢 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪"
            .split(separator: " ").map(String.init)
    )

    private let panel: NSPanel
    private let comparisonPanel: NSPanel
    private let grid: NSGridView
    private let comparisonStack: NSStackView
    private var buttons: [NSButton] = []
    private var selectedIndex: Int?
    private var imageTasks: [Task<Void, Never>] = []
    private var imageCache: [URL: NSImage] = [:]

    override init() {
        grid = NSGridView()
        comparisonStack = NSStackView()
        panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        comparisonPanel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()
        configurePanels()
        buildGrid()
    }

    var isVisible: Bool { panel.isVisible }
    var selectedEmoji: String? {
        selectedIndex.map { Self.emojis[$0] }
    }

    func show(near anchor: NSRect) {
        selectedIndex = nil
        updateSelection()
        comparisonPanel.orderOut(nil)
        let size = panel.frame.size
        let resolvedAnchor = anchor == .zero
            ? NSRect(origin: NSEvent.mouseLocation, size: .zero)
            : anchor
        let screen = NSScreen.screens.first {
            $0.frame.contains(resolvedAnchor.origin)
        } ?? NSScreen.main
        let visible = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let belowY = resolvedAnchor.minY - size.height - 8
        let aboveY = resolvedAnchor.maxY + 8
        let preferredY = belowY >= visible.minY ? belowY : aboveY
        let origin = NSPoint(
            x: min(
                max(resolvedAnchor.minX, visible.minX),
                visible.maxX - size.width
            ),
            y: min(
                max(preferredY, visible.minY),
                visible.maxY - size.height
            )
        )
        panel.setFrameOrigin(origin)
        panel.orderFrontRegardless()
        EmojiDiagnostics.logger.notice(
            "panel ordered size=\(String(describing: size), privacy: .public) origin=\(String(describing: origin), privacy: .public) visible=\(self.panel.isVisible, privacy: .public)"
        )
    }

    func hide() {
        imageTasks.forEach { $0.cancel() }
        imageTasks = []
        panel.orderOut(nil)
        comparisonPanel.orderOut(nil)
        selectedIndex = nil
    }

    func moveSelection(by offset: Int) {
        guard !Self.emojis.isEmpty else { return }
        selectedIndex = ((selectedIndex ?? (offset > 0 ? -1 : 0))
            + offset + Self.emojis.count) % Self.emojis.count
        updateSelection()
        showComparison(for: Self.emojis[selectedIndex!])
    }

    private func configurePanels() {
        for value in [panel, comparisonPanel] {
            value.backgroundColor = .windowBackgroundColor
            value.hasShadow = true
            value.hidesOnDeactivate = false
            value.level = .popUpMenu
            value.isOpaque = true
            value.isReleasedWhenClosed = false
        }
        comparisonStack.orientation = .horizontal
        comparisonStack.alignment = .top
        comparisonStack.spacing = 8
        comparisonStack.edgeInsets = NSEdgeInsets(top: 9, left: 9, bottom: 9, right: 9)
        comparisonPanel.contentView = comparisonStack
    }

    private func buildGrid() {
        var rows: [[NSView]] = []
        for start in stride(from: 0, to: Self.emojis.count, by: Self.columnCount) {
            var row: [NSView] = []
            for index in start..<min(start + Self.columnCount, Self.emojis.count) {
                let button = NSButton(title: Self.emojis[index], target: self, action: #selector(selectEmoji(_:)))
                button.tag = index
                button.font = NSFont(name: "Apple Color Emoji", size: 22)
                button.isBordered = false
                button.bezelStyle = .regularSquare
                button.wantsLayer = true
                button.layer?.cornerRadius = 0
                button.widthAnchor.constraint(equalToConstant: Self.cellSize).isActive = true
                button.heightAnchor.constraint(equalToConstant: Self.cellSize).isActive = true
                buttons.append(button)
                row.append(button)
            }
            while row.count < Self.columnCount { row.append(NSView()) }
            rows.append(row)
        }
        for row in rows {
            grid.addRow(with: row)
        }
        grid.rowSpacing = Self.spacing
        grid.columnSpacing = Self.spacing
        let width = Self.cellSize * CGFloat(Self.columnCount)
            + Self.spacing * CGFloat(Self.columnCount - 1) + 12
        let height = Self.cellSize * CGFloat(rows.count)
            + Self.spacing * CGFloat(max(rows.count - 1, 0)) + 36
        let contentSize = NSSize(width: width, height: height)
        let root = NSView(
            frame: NSRect(origin: .zero, size: contentSize)
        )
        let guide = NSTextField(labelWithString: "Tab / 矢印 選択　Return 確定　Esc 閉じる")
        guide.font = PanelShortcutGuideStyle.font
        guide.textColor = PanelShortcutGuideStyle.color
        grid.frame = NSRect(x: 6, y: 28, width: width - 12, height: height - 34)
        guide.frame = NSRect(x: 8, y: 6, width: width - 16, height: 16)
        root.addSubview(grid)
        root.addSubview(guide)
        panel.contentView = root
        panel.setContentSize(contentSize)
        root.frame = NSRect(origin: .zero, size: contentSize)
    }

    @objc private func selectEmoji(_ sender: NSButton) {
        selectedIndex = sender.tag
        updateSelection()
        showComparison(for: Self.emojis[sender.tag])
    }

    private func updateSelection() {
        for (index, button) in buttons.enumerated() {
            button.layer?.backgroundColor = index == selectedIndex
                ? NSColor.controlAccentColor.cgColor
                : NSColor.clear.cgColor
        }
    }

    private func showComparison(for emoji: String) {
        imageTasks.forEach { $0.cancel() }
        imageTasks = []
        comparisonStack.arrangedSubviews.forEach {
            comparisonStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        comparisonStack.addArrangedSubview(appleView(emoji))
        let googleURL = Self.googleURL(for: emoji)
        let windowsURL = Self.windowsURL(for: emoji)
        comparisonStack.addArrangedSubview(remoteView(title: "Google", url: googleURL))
        comparisonStack.addArrangedSubview(remoteView(title: "Windows", url: windowsURL))
        comparisonPanel.setContentSize(NSSize(width: 260, height: 104))
        let frame = panel.frame
        let visible = panel.screen?.visibleFrame ?? frame
        let x = frame.maxX + 8 + 260 <= visible.maxX
            ? frame.maxX + 8 : frame.minX - 268
        comparisonPanel.setFrameOrigin(NSPoint(x: x, y: frame.maxY - 104))
        comparisonPanel.orderFrontRegardless()
    }

    private func appleView(_ emoji: String) -> NSView {
        let label = NSTextField(labelWithString: emoji)
        label.font = NSFont(name: "Apple Color Emoji", size: 42)
        label.alignment = .center
        return platformView(title: "Apple", content: label)
    }

    private func remoteView(title: String, url: URL) -> NSView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        imageView.image = imageCache[url]
        if imageView.image == nil {
            let task = Task { @MainActor [weak self, weak imageView] in
                guard let self else { return }
                if let (data, _) = try? await URLSession.shared.data(from: url),
                   !Task.isCancelled, let image = NSImage(data: data) {
                    imageCache[url] = image
                    imageView?.image = image
                }
            }
            imageTasks.append(task)
        }
        return platformView(title: title, content: imageView)
    }

    private func platformView(title: String, content: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.alignment = .center
        content.widthAnchor.constraint(equalToConstant: 68).isActive = true
        content.heightAnchor.constraint(equalToConstant: 62).isActive = true
        let stack = NSStackView(views: [label, content])
        stack.orientation = .vertical
        stack.spacing = 3
        return stack
    }

    private static func googleURL(for emoji: String) -> URL {
        let code = emoji.unicodeScalars.filter { $0.value != 0xFE0F }
            .map { String($0.value, radix: 16) }.joined(separator: "_")
        return URL(string: "https://raw.githubusercontent.com/googlefonts/noto-emoji/main/png/128/emoji_u\(code).png")!
    }

    private static func windowsURL(for emoji: String) -> URL {
        let code = emoji.unicodeScalars.filter { $0.value != 0xFE0F }
            .map { String($0.value, radix: 16) }.joined(separator: "-")
        return URL(string: "https://cdn.jsdelivr.net/gh/shuding/fluentui-emoji-unicode/assets/\(code)_3d.png")!
    }
}
