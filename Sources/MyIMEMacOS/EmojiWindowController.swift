@preconcurrency import AppKit
import MyIMECore

private final class EmojiCollectionItem: NSCollectionViewItem {
    override func loadView() {
        let label = NSTextField(labelWithString: "")
        label.font = NSFont(name: "Apple Color Emoji", size: 22)
        label.alignment = .center
        label.isBezeled = false
        label.drawsBackground = false
        label.isEditable = false
        label.isSelectable = false
        view = label
    }

    override var isSelected: Bool {
        didSet {
            view.wantsLayer = true
            view.layer?.cornerRadius = 0
            view.layer?.backgroundColor = isSelected
                ? NSColor.controlAccentColor.cgColor
                : NSColor.clear.cgColor
        }
    }

    func configure(emoji: String) {
        (view as? NSTextField)?.stringValue = emoji
    }
}

final class EmojiWindowController: NSObject {
    private struct Entry {
        let code: String
        let emoji: String
    }

    static let shared = EmojiWindowController()
    static let columnCount = 8
    private static let recentColumnCount = 10
    private static let recentCellSize: CGFloat = 26
    private static let recentDefaultsKey = "EmojiRecentHistory"
    private static let cellSize: CGFloat = 34
    private static let spacing: CGFloat = 2
    private static let fallbackEmojis = Array(
        "😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 ☹️ 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🫡 🤭 🫢 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪"
            .split(separator: " ").map(String.init)
    )
    private static let entries = loadEntries()

    private let panel: NSPanel
    private let comparisonPanel: NSPanel
    private let collectionView: NSCollectionView
    private let layout: NSCollectionViewFlowLayout
    private let scrollView: NSScrollView
    private let comparisonStack: NSStackView
    private var selectedIndex: Int?
    private var selectedRecentIndex: Int?
    private var recentHistory: RecentEmojiHistory
    private let recentStack = NSStackView()
    private var recentButtons: [NSButton] = []
    private let comparisonImageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 120
        return cache
    }()

    override init() {
        collectionView = NSCollectionView()
        layout = NSCollectionViewFlowLayout()
        scrollView = NSScrollView()
        comparisonStack = NSStackView()
        recentHistory = RecentEmojiHistory(
            emojis: UserDefaults.standard.stringArray(
                forKey: Self.recentDefaultsKey
            ) ?? []
        )
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
        buildCollection()
    }

    var isVisible: Bool { panel.isVisible }
    var selectedEmoji: String? {
        if let selectedRecentIndex,
           recentHistory.emojis.indices.contains(selectedRecentIndex) {
            return recentHistory.emojis[selectedRecentIndex]
        }
        return selectedIndex.map { Self.entries[$0].emoji }
    }

    func show(near anchor: NSRect) {
        selectedIndex = nil
        selectedRecentIndex = nil
        collectionView.selectionIndexPaths = []
        updateRecentSelection()
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
        EmojiGlobalHotKey.shared.beginPanelCapture()
        EmojiDiagnostics.logger.notice(
            "panel ordered size=\(String(describing: size), privacy: .public) origin=\(String(describing: origin), privacy: .public) visible=\(self.panel.isVisible, privacy: .public)"
        )
    }

    func hide() {
        EmojiGlobalHotKey.shared.endPanelCapture()
        panel.orderOut(nil)
        comparisonPanel.orderOut(nil)
        selectedIndex = nil
        selectedRecentIndex = nil
    }

    func recordUsage(_ emoji: String) {
        recentHistory.record(emoji)
        UserDefaults.standard.set(
            recentHistory.emojis,
            forKey: Self.recentDefaultsKey
        )
        rebuildRecentArea()
    }

    func advanceSelection(backward: Bool) {
        guard !Self.entries.isEmpty else { return }
        let offset = backward ? -1 : 1
        let recentCount = recentHistory.emojis.count
        let totalCount = recentCount + Self.entries.count
        let current = selectedRecentIndex
            ?? selectedIndex.map { recentCount + $0 }
            ?? (backward ? 0 : -1)
        let next = (current + offset + totalCount) % totalCount
        if next < recentCount {
            selectRecent(index: next)
        } else {
            select(index: next - recentCount)
        }
    }

    func moveSelection(_ direction: EmojiGridDirection) {
        guard !Self.entries.isEmpty else { return }
        if let selectedRecentIndex {
            moveRecentSelection(from: selectedRecentIndex, direction: direction)
            return
        }
        guard let selectedIndex else {
            if recentHistory.emojis.isEmpty {
                select(index: 0)
            } else {
                selectRecent(index: 0)
            }
            return
        }
        if case .up = direction {
            if selectedIndex < Self.columnCount,
               !recentHistory.emojis.isEmpty {
                selectRecent(index: min(
                    selectedIndex,
                    recentHistory.emojis.count - 1
                ))
                return
            }
        }
        let nextIndex = EmojiGridNavigator.nextIndex(
            from: selectedIndex,
            direction: direction,
            itemCount: Self.entries.count,
            columnCount: Self.columnCount
        )
        select(index: nextIndex)
    }

    private func select(index: Int) {
        guard Self.entries.indices.contains(index) else { return }
        selectedRecentIndex = nil
        updateRecentSelection()
        selectedIndex = index
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.selectionIndexPaths = [indexPath]
        collectionView.layoutSubtreeIfNeeded()
        collectionView.scrollToItems(
            at: [indexPath],
            scrollPosition: [.nearestHorizontalEdge, .nearestVerticalEdge]
        )
        showComparison(for: Self.entries[index])
    }

    private func selectRecent(index: Int) {
        guard recentHistory.emojis.indices.contains(index),
              let entry = Self.entries.first(where: {
                  $0.emoji == recentHistory.emojis[index]
              }) else { return }
        selectedIndex = nil
        collectionView.selectionIndexPaths = []
        selectedRecentIndex = index
        updateRecentSelection()
        showComparison(for: entry)
    }

    private func moveRecentSelection(
        from index: Int,
        direction: EmojiGridDirection
    ) {
        let count = recentHistory.emojis.count
        switch direction {
        case .left:
            selectRecent(index: max(index - 1, index / Self.recentColumnCount * Self.recentColumnCount))
        case .right:
            let rowEnd = min(
                index / Self.recentColumnCount * Self.recentColumnCount
                    + Self.recentColumnCount - 1,
                count - 1
            )
            selectRecent(index: min(index + 1, rowEnd))
        case .up:
            selectRecent(index: max(index - Self.recentColumnCount, 0))
        case .down:
            let next = index + Self.recentColumnCount
            if next < count {
                selectRecent(index: next)
            } else {
                select(index: min(
                    index % Self.recentColumnCount,
                    Self.columnCount - 1,
                    Self.entries.count - 1
                ))
            }
        }
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
        recentStack.orientation = .vertical
        recentStack.alignment = .leading
        recentStack.spacing = Self.spacing
    }

    private func buildCollection() {
        layout.itemSize = NSSize(width: Self.cellSize, height: Self.cellSize)
        layout.minimumInteritemSpacing = Self.spacing
        layout.minimumLineSpacing = Self.spacing
        layout.sectionInset = NSEdgeInsets(top: 4, left: 0, bottom: 4, right: 0)
        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsEmptySelection = true
        collectionView.backgroundColors = [.clear]
        collectionView.register(
            EmojiCollectionItem.self,
            forItemWithIdentifier: NSUserInterfaceItemIdentifier("EmojiItem")
        )
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.scrollerStyle = .overlay
        scrollView.drawsBackground = false
        let width = Self.cellSize * CGFloat(Self.columnCount)
            + Self.spacing * CGFloat(Self.columnCount - 1) + 12
        let height: CGFloat = 446
        let contentSize = NSSize(width: width, height: height)
        let root = NSView(
            frame: NSRect(origin: .zero, size: contentSize)
        )
        let guide = NSTextField(labelWithString: "Tab / 矢印 選択　Return 確定　Esc 閉じる")
        guide.font = PanelShortcutGuideStyle.font
        guide.textColor = PanelShortcutGuideStyle.color
        scrollView.frame = NSRect(x: 4, y: 28, width: width - 8, height: 362)
        let rowCount = ceil(
            CGFloat(Self.entries.count) / CGFloat(Self.columnCount)
        )
        let documentHeight = layout.sectionInset.top
            + rowCount * Self.cellSize
            + max(rowCount - 1, 0) * Self.spacing
            + layout.sectionInset.bottom
        collectionView.frame = NSRect(
            x: 0,
            y: 0,
            width: scrollView.contentSize.width,
            height: documentHeight
        )
        guide.frame = NSRect(x: 8, y: 6, width: width - 16, height: 16)
        let recentTitle = NSTextField(labelWithString: "最近使った絵文字")
        recentTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        recentTitle.textColor = .secondaryLabelColor
        recentTitle.frame = NSRect(x: 8, y: 422, width: width - 16, height: 16)
        recentStack.frame = NSRect(x: 8, y: 394, width: width - 16, height: 26)
        root.addSubview(scrollView)
        root.addSubview(guide)
        root.addSubview(recentTitle)
        root.addSubview(recentStack)
        panel.contentView = root
        panel.setContentSize(contentSize)
        root.frame = NSRect(origin: .zero, size: contentSize)
        rebuildRecentArea()
    }

    private func rebuildRecentArea() {
        recentStack.arrangedSubviews.forEach {
            recentStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        recentButtons = []
        for rowStart in stride(
            from: 0,
            to: recentHistory.emojis.count,
            by: Self.recentColumnCount
        ) {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = Self.spacing
            let rowEnd = min(
                rowStart + Self.recentColumnCount,
                recentHistory.emojis.count
            )
            for index in rowStart..<rowEnd {
                let button = NSButton(title: recentHistory.emojis[index], target: self, action: #selector(selectRecentEmoji(_:)))
                button.tag = index
                button.isBordered = false
                button.font = NSFont(name: "Apple Color Emoji", size: 18)
                button.wantsLayer = true
                button.widthAnchor.constraint(equalToConstant: Self.recentCellSize).isActive = true
                button.heightAnchor.constraint(equalToConstant: Self.recentCellSize).isActive = true
                row.addArrangedSubview(button)
                recentButtons.append(button)
            }
            recentStack.addArrangedSubview(row)
        }
        updateRecentSelection()
    }

    @objc private func selectRecentEmoji(_ sender: NSButton) {
        selectRecent(index: sender.tag)
    }

    private func updateRecentSelection() {
        for (index, button) in recentButtons.enumerated() {
            button.layer?.backgroundColor = index == selectedRecentIndex
                ? NSColor.controlAccentColor.cgColor
                : NSColor.clear.cgColor
        }
    }

    private func showComparison(for entry: Entry) {
        comparisonStack.arrangedSubviews.forEach {
            comparisonStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        comparisonStack.addArrangedSubview(appleView(entry.emoji))
        comparisonStack.addArrangedSubview(
            bundledView(title: "Android", platform: "Android", entry: entry)
        )
        comparisonStack.addArrangedSubview(
            bundledView(title: "Windows", platform: "Windows", entry: entry)
        )
        comparisonPanel.setContentSize(NSSize(width: 260, height: 104))
        let frame = panel.frame
        let visible = panel.screen?.visibleFrame ?? frame
        let x = frame.maxX + 8 + 260 <= visible.maxX
            ? frame.maxX + 8 : frame.minX - 268
        comparisonPanel.setFrameOrigin(NSPoint(x: x, y: frame.maxY - 104))
        comparisonPanel.orderFrontRegardless()
    }

    private func appleView(_ emoji: String) -> NSView {
        let imageView = comparisonImageView()
        imageView.image = comparisonImage(
            key: "Apple/\(emoji)",
            source: Self.appleImage(for: emoji)
        )
        return platformView(title: "Apple", content: imageView)
    }

    private func bundledView(
        title: String,
        platform: String,
        entry: Entry
    ) -> NSView {
        let imageView = comparisonImageView()
        let image = Self.bundledImage(
            platform: platform,
            code: entry.code
        )
        imageView.image = comparisonImage(
            key: "\(platform)/\(entry.code)",
            source: image
        )
        return platformView(title: title, content: imageView)
    }

    private func comparisonImageView() -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        return imageView
    }

    private func comparisonImage(
        key: String,
        source: NSImage?
    ) -> NSImage? {
        if let cached = comparisonImageCache.object(forKey: key as NSString) {
            return cached
        }
        guard let source,
              let normalized = Self.normalizedImage(source) else {
            return source
        }
        comparisonImageCache.setObject(normalized, forKey: key as NSString)
        return normalized
    }

    private func platformView(title: String, content: NSView) -> NSView {
        let label = NSTextField(labelWithString: title)
        label.font = .systemFont(ofSize: 11, weight: .medium)
        label.alignment = .center
        content.widthAnchor.constraint(equalToConstant: 68).isActive = true
        content.heightAnchor.constraint(equalToConstant: 56).isActive = true
        let stack = NSStackView(views: [label, content])
        stack.orientation = .vertical
        stack.spacing = 3
        return stack
    }

    private static func appleImage(for emoji: String) -> NSImage {
        let canvas = NSSize(width: 56, height: 56)
        let image = NSImage(size: canvas)
        image.lockFocus()
        let value = NSAttributedString(
            string: emoji,
            attributes: [
                .font: NSFont(name: "Apple Color Emoji", size: 48)
                    ?? NSFont.systemFont(ofSize: 48)
            ]
        )
        let size = value.size()
        value.draw(at: NSPoint(
            x: (canvas.width - size.width) / 2,
            y: (canvas.height - size.height) / 2
        ))
        image.unlockFocus()
        return image
    }

    private static func normalizedImage(_ source: NSImage) -> NSImage? {
        let rasterSize = 256
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil,
            pixelsWide: rasterSize,
            pixelsHigh: rasterSize,
            bitsPerSample: 8,
            samplesPerPixel: 4,
            hasAlpha: true,
            isPlanar: false,
            colorSpaceName: .deviceRGB,
            bitmapFormat: [],
            bytesPerRow: 0,
            bitsPerPixel: 0
        ), let context = NSGraphicsContext(bitmapImageRep: bitmap) else {
            return nil
        }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        source.draw(
            in: NSRect(x: 0, y: 0, width: rasterSize, height: rasterSize),
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        context.flushGraphics()
        NSGraphicsContext.restoreGraphicsState()

        guard let data = bitmap.bitmapData else { return nil }
        var minX = rasterSize
        var minY = rasterSize
        var maxX = -1
        var maxY = -1
        for y in 0..<rasterSize {
            let row = data.advanced(by: y * bitmap.bytesPerRow)
            for x in 0..<rasterSize where row[x * 4 + 3] > 4 {
                minX = min(minX, x)
                minY = min(minY, y)
                maxX = max(maxX, x)
                maxY = max(maxY, y)
            }
        }
        guard maxX >= minX, maxY >= minY,
              let cropped = bitmap.cgImage?.cropping(to: CGRect(
                x: minX,
                y: minY,
                width: maxX - minX + 1,
                height: maxY - minY + 1
              )) else {
            return nil
        }

        let canvas = NSSize(width: 56, height: 56)
        let maximumExtent: CGFloat = 48
        let sourceSize = NSSize(width: cropped.width, height: cropped.height)
        let scale = min(
            maximumExtent / sourceSize.width,
            maximumExtent / sourceSize.height
        )
        let targetSize = NSSize(
            width: sourceSize.width * scale,
            height: sourceSize.height * scale
        )
        let targetRect = NSRect(
            x: (canvas.width - targetSize.width) / 2,
            y: (canvas.height - targetSize.height) / 2,
            width: targetSize.width,
            height: targetSize.height
        )
        let result = NSImage(size: canvas)
        result.lockFocus()
        NSImage(cgImage: cropped, size: sourceSize).draw(
            in: targetRect,
            from: .zero,
            operation: .copy,
            fraction: 1
        )
        result.unlockFocus()
        return result
    }

    private static func bundledImage(
        platform: String,
        code: String
    ) -> NSImage? {
        let relativePath = "Emoji/\(platform)/\(code).png"
        let resourceRoots = [
            Bundle.main.resourceURL,
            Bundle(for: EmojiWindowController.self).resourceURL,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Library/Input Methods/myim.app/Contents/Resources",
                    isDirectory: true
                )
        ].compactMap { $0 }
        for root in resourceRoots {
            let url = root.appendingPathComponent(relativePath)
            if let image = NSImage(contentsOf: url) {
                return image
            }
        }
        EmojiDiagnostics.logger.error(
            "bundled emoji asset missing path=\(relativePath, privacy: .public)"
        )
        return nil
    }

    private static func loadEntries() -> [Entry] {
        for root in resourceRoots() {
            let url = root.appendingPathComponent("Emoji/catalog.tsv")
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            let values = text.split(whereSeparator: \.isNewline).compactMap { line -> Entry? in
                let columns = line.split(separator: "\t", maxSplits: 1).map(String.init)
                guard columns.count == 2 else { return nil }
                return Entry(code: columns[0], emoji: columns[1])
            }
            if !values.isEmpty { return values }
        }
        return fallbackEmojis.map { emoji in
            Entry(
                code: emoji.unicodeScalars.filter { $0.value != 0xFE0F }
                    .map { String($0.value, radix: 16) }.joined(separator: "-"),
                emoji: emoji
            )
        }
    }

    private static func resourceRoots() -> [URL] {
        [
            Bundle.main.resourceURL,
            Bundle(for: EmojiWindowController.self).resourceURL,
            FileManager.default.homeDirectoryForCurrentUser
                .appendingPathComponent(
                    "Library/Input Methods/myim.app/Contents/Resources",
                    isDirectory: true
                )
        ].compactMap { $0 }
    }
}

extension EmojiWindowController: NSCollectionViewDataSource, NSCollectionViewDelegate {
    func collectionView(
        _ collectionView: NSCollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        Self.entries.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: NSUserInterfaceItemIdentifier("EmojiItem"),
            for: indexPath
        ) as! EmojiCollectionItem
        item.configure(emoji: Self.entries[indexPath.item].emoji)
        return item
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        didSelectItemsAt indexPaths: Set<IndexPath>
    ) {
        guard let index = indexPaths.first?.item,
              Self.entries.indices.contains(index) else { return }
        selectedRecentIndex = nil
        updateRecentSelection()
        selectedIndex = index
        showComparison(for: Self.entries[index])
    }
}
