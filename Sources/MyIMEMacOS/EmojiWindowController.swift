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

private final class BottomUpEmojiFlowLayout: NSCollectionViewFlowLayout {
    var displaysBottomUp = true {
        didSet {
            if oldValue != displaysBottomUp { invalidateLayout() }
        }
    }

    override func layoutAttributesForElements(
        in rect: NSRect
    ) -> [NSCollectionViewLayoutAttributes] {
        guard displaysBottomUp else {
            return super.layoutAttributesForElements(in: rect)
        }
        let height = layoutHeight
        let sourceRect = NSRect(
            x: rect.minX,
            y: height - rect.maxY,
            width: rect.width,
            height: rect.height
        )
        return super.layoutAttributesForElements(in: sourceRect)
            .compactMap(flipped)
    }

    override func layoutAttributesForItem(
        at indexPath: IndexPath
    ) -> NSCollectionViewLayoutAttributes? {
        guard displaysBottomUp else {
            return super.layoutAttributesForItem(at: indexPath)
        }
        return super.layoutAttributesForItem(at: indexPath).flatMap(flipped)
    }

    private func flipped(
        _ attributes: NSCollectionViewLayoutAttributes
    ) -> NSCollectionViewLayoutAttributes? {
        guard let copy = attributes.copy() as? NSCollectionViewLayoutAttributes else {
            return nil
        }
        copy.frame.origin.y = layoutHeight - copy.frame.maxY
        return copy
    }

    private var layoutHeight: CGFloat {
        max(collectionViewContentSize.height, collectionView?.bounds.height ?? 0)
    }
}

final class EmojiWindowController: NSObject {
    private struct Entry {
        let code: String
        let emoji: String
        let searchTerms: [String]
    }

    static let shared = EmojiWindowController()
    static let columnCount = 8
    private static let recentColumnCount = 10
    private static let recentCellSize: CGFloat = 26
    private static let recentDefaultsKey = "EmojiRecentHistory"
    private static let cellSize: CGFloat = 34
    private static let spacing: CGFloat = 2
    private static let maximumListHeight: CGFloat = 362
    private static let panelChromeHeight: CGFloat = 84
    private static let fallbackEmojis = Array(
        "😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 ☹️ 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🫡 🤭 🫢 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪"
            .split(separator: " ").map(String.init)
    )
    private static let entries = loadEntries()

    private let panel: NSPanel
    private let comparisonPanel: NSPanel
    private let collectionView: NSCollectionView
    private let layout: BottomUpEmojiFlowLayout
    private let scrollView: NSScrollView
    private let comparisonStack: NSStackView
    private let guideLabel = NSTextField(
        labelWithString: "Tab / 矢印 選択　Return 確定　Esc 閉じる"
    )
    private let recentTitle = NSTextField(labelWithString: "最近使った絵文字")
    private var selectedIndex: Int?
    private var selectedRecentIndex: Int?
    private var recentHistory: RecentEmojiHistory
    private let recentStack = NSStackView()
    private var recentButtons: [NSButton] = []
    private var visibleEntries: [Entry]
    private var searchQuery = ""
    private var presentationAnchor: NSRect?
    private var presentationVisibleFrame: NSRect?
    private var avoidedFrames: [NSRect] = []
    private(set) var isSearchConfirmed = false
    private let romajiConverter = RomajiConverter()
    private let comparisonImageCache: NSCache<NSString, NSImage> = {
        let cache = NSCache<NSString, NSImage>()
        cache.countLimit = 120
        return cache
    }()

    override init() {
        collectionView = NSCollectionView()
        layout = BottomUpEmojiFlowLayout()
        scrollView = NSScrollView()
        comparisonStack = NSStackView()
        recentHistory = RecentEmojiHistory(
            emojis: UserDefaults.standard.stringArray(
                forKey: Self.recentDefaultsKey
            ) ?? []
        )
        visibleEntries = Self.entries
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
    var visibleFrame: NSRect? { panel.isVisible ? panel.frame : nil }
    var searchText: String { searchQuery }
    var canSelectEmoji: Bool { isSearchConfirmed || searchQuery.isEmpty }
    var selectedEmoji: String? {
        if let selectedRecentIndex,
           recentHistory.emojis.indices.contains(selectedRecentIndex) {
            return recentHistory.emojis[selectedRecentIndex]
        }
        return selectedIndex.map { visibleEntries[$0].emoji }
    }

    func show(near anchor: NSRect) {
        selectedIndex = nil
        selectedRecentIndex = nil
        collectionView.selectionIndexPaths = []
        updateRecentSelection()
        let resolvedAnchor = anchor == .zero
            ? NSRect(origin: NSEvent.mouseLocation, size: .zero)
            : anchor
        let screen = NSScreen.screens.first {
            $0.frame.contains(resolvedAnchor.origin)
        } ?? NSScreen.main
        let visible = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        presentationAnchor = resolvedAnchor
        presentationVisibleFrame = visible
        updateSearchText("")
        comparisonPanel.orderOut(nil)
        panel.orderFrontRegardless()
        scrollToPreferredEdge()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.scrollToPreferredEdge()
        }
        EmojiGlobalHotKey.shared.beginPanelCapture()
        EmojiDiagnostics.logger.notice(
            "panel ordered size=\(String(describing: self.panel.frame.size), privacy: .public) origin=\(String(describing: self.panel.frame.origin), privacy: .public) visible=\(self.panel.isVisible, privacy: .public)"
        )
    }

    func hide() {
        EmojiGlobalHotKey.shared.endPanelCapture()
        panel.orderOut(nil)
        comparisonPanel.orderOut(nil)
        selectedIndex = nil
        selectedRecentIndex = nil
        isSearchConfirmed = false
        avoidedFrames = []
    }

    func avoid(frames: [NSRect]) {
        avoidedFrames = frames.filter { !$0.isEmpty }
        guard panel.isVisible else { return }
        updatePanelPresentation()
        scrollToPreferredEdge()
    }

    func recordUsage(_ emoji: String) {
        recentHistory.record(emoji)
        UserDefaults.standard.set(
            recentHistory.emojis,
            forKey: Self.recentDefaultsKey
        )
        rebuildRecentArea()
    }

    func updateSearchText(_ text: String) {
        isSearchConfirmed = false
        setSearchQuery(text)
    }

    func confirmSearch() {
        isSearchConfirmed = true
        selectedIndex = nil
        selectedRecentIndex = nil
        collectionView.selectionIndexPaths = []
        updateRecentSelection()
        comparisonPanel.orderOut(nil)
    }

    func advanceSelection(backward: Bool) {
        guard !visibleEntries.isEmpty || !recentHistory.emojis.isEmpty else {
            return
        }
        let offset = backward ? -1 : 1
        let recentCount = recentHistory.emojis.count
        let totalCount = recentCount + visibleEntries.count
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
        guard !visibleEntries.isEmpty || !recentHistory.emojis.isEmpty else {
            return
        }
        if let selectedRecentIndex {
            moveRecentSelection(from: selectedRecentIndex, direction: direction)
            return
        }
        guard let selectedIndex else {
            if !searchQuery.isEmpty || recentHistory.emojis.isEmpty {
                select(index: 0)
            } else {
                selectRecent(index: 0)
            }
            return
        }
        let entersRecentArea = layout.displaysBottomUp
            ? direction == .down && selectedIndex < Self.columnCount
            : direction == .up && selectedIndex < Self.columnCount
        if searchQuery.isEmpty,
           entersRecentArea,
           !recentHistory.emojis.isEmpty {
            selectRecent(index: min(
                selectedIndex % Self.columnCount,
                recentHistory.emojis.count - 1
            ))
            return
        }
        let gridDirection: EmojiGridDirection = if layout.displaysBottomUp {
            switch direction {
            case .up: .down
            case .down: .up
            default: direction
            }
        } else {
            direction
        }
        let nextIndex = EmojiGridNavigator.nextIndex(
            from: selectedIndex,
            direction: gridDirection,
            itemCount: visibleEntries.count,
            columnCount: Self.columnCount
        )
        select(index: nextIndex)
    }

    private func select(index: Int) {
        guard visibleEntries.indices.contains(index) else { return }
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
        showComparison(for: visibleEntries[index])
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
            let previous = index - Self.recentColumnCount
            if previous >= 0 {
                selectRecent(index: previous)
            } else if layout.displaysBottomUp {
                select(index: min(
                    index % Self.recentColumnCount,
                    visibleEntries.count - 1
                ))
            }
        case .down:
            let next = index + Self.recentColumnCount
            if next < count {
                selectRecent(index: next)
            } else if !layout.displaysBottomUp {
                select(index: min(
                    index % Self.recentColumnCount,
                    visibleEntries.count - 1
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
        let height = Self.maximumListHeight + Self.panelChromeHeight
        let contentSize = NSSize(width: width, height: height)
        let root = NSView(
            frame: NSRect(origin: .zero, size: contentSize)
        )
        guideLabel.font = PanelShortcutGuideStyle.font
        guideLabel.textColor = PanelShortcutGuideStyle.color
        scrollView.frame = NSRect(
            x: 4,
            y: 76,
            width: width - 8,
            height: Self.maximumListHeight
        )
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
        recentTitle.font = .systemFont(ofSize: 12, weight: .semibold)
        recentTitle.textColor = .secondaryLabelColor
        positionSections(listHeight: Self.maximumListHeight, width: width)
        root.addSubview(scrollView)
        root.addSubview(guideLabel)
        root.addSubview(recentTitle)
        root.addSubview(recentStack)
        panel.contentView = root
        panel.setContentSize(contentSize)
        root.frame = NSRect(origin: .zero, size: contentSize)
        rebuildRecentArea()
    }

    private func setSearchQuery(_ query: String) {
        searchQuery = query
        var queries = [query]
        if let hiragana = romajiConverter.hiragana(from: query) {
            queries.append(hiragana)
        }
        if let katakana = romajiConverter.katakana(from: query) {
            queries.append(katakana)
        }
        let matches = query.isEmpty ? Self.entries : Self.entries.filter { entry in
            queries.contains { query in
                EmojiSearchMatcher.matches(
                    query: query,
                    terms: [entry.emoji] + entry.searchTerms
                )
            }
        }
        visibleEntries = matches
        selectedIndex = nil
        selectedRecentIndex = nil
        isSearchConfirmed = false
        collectionView.selectionIndexPaths = []
        comparisonPanel.orderOut(nil)
        updateRecentSelection()
        collectionView.reloadData()
        updatePanelPresentation()
        scrollToPreferredEdge()
        DispatchQueue.main.async { [weak self] in
            self?.scrollToPreferredEdge()
        }
        if !visibleEntries.isEmpty {
            collectionView.scrollToItems(
                at: [IndexPath(item: 0, section: 0)],
                scrollPosition: .nearestVerticalEdge
            )
        }
    }

    private func updateCollectionDocumentHeight() {
        let rowCount = ceil(
            CGFloat(visibleEntries.count) / CGFloat(Self.columnCount)
        )
        let documentHeight = layout.sectionInset.top
            + rowCount * Self.cellSize
            + max(rowCount - 1, 0) * Self.spacing
            + layout.sectionInset.bottom
        collectionView.setFrameSize(NSSize(
            width: scrollView.contentSize.width,
            height: max(documentHeight, scrollView.contentSize.height)
        ))
    }

    private func updatePanelPresentation() {
        let rowCount = max(
            ceil(CGFloat(visibleEntries.count) / CGFloat(Self.columnCount)),
            1
        )
        let documentHeight = layout.sectionInset.top
            + rowCount * Self.cellSize
            + max(rowCount - 1, 0) * Self.spacing
            + layout.sectionInset.bottom
        let listHeight = min(documentHeight, Self.maximumListHeight)
        let size = NSSize(
            width: panel.frame.width,
            height: listHeight + Self.panelChromeHeight
        )
        panel.setContentSize(size)
        panel.contentView?.frame = NSRect(origin: .zero, size: size)
        scrollView.frame.size.height = listHeight
        collectionView.setFrameSize(NSSize(
            width: scrollView.contentSize.width,
            height: max(documentHeight, scrollView.contentSize.height)
        ))

        guard let anchor = presentationAnchor,
              let visible = presentationVisibleFrame else { return }
        let belowY = anchor.minY - size.height - 8
        let displaysAboveInput = belowY < visible.minY
        layout.displaysBottomUp = displaysAboveInput
        positionSections(listHeight: listHeight, width: size.width)
        let preferredY = displaysAboveInput
            ? anchor.maxY + 8
            : belowY
        let baseOrigin = NSPoint(
            x: min(max(anchor.minX, visible.minX), visible.maxX - size.width),
            y: min(max(preferredY, visible.minY), visible.maxY - size.height)
        )
        let occupied = avoidedFrames.reduce(anchor) { $0.union($1) }
        let origins = [
            baseOrigin,
            NSPoint(x: occupied.maxX + 8, y: baseOrigin.y),
            NSPoint(x: occupied.minX - size.width - 8, y: baseOrigin.y),
            NSPoint(x: baseOrigin.x, y: occupied.maxY + 8),
            NSPoint(x: baseOrigin.x, y: occupied.minY - size.height - 8)
        ].map { point in
            NSPoint(
                x: min(max(point.x, visible.minX), visible.maxX - size.width),
                y: min(max(point.y, visible.minY), visible.maxY - size.height)
            )
        }
        let frames = origins.map { NSRect(origin: $0, size: size) }
        let frame = frames.first { candidate in
            avoidedFrames.allSatisfy { !candidate.intersects($0) }
        } ?? frames.min { lhs, rhs in
            overlapArea(of: lhs) < overlapArea(of: rhs)
        } ?? NSRect(origin: baseOrigin, size: size)
        layout.displaysBottomUp = frame.minY >= anchor.maxY
        panel.setFrameOrigin(frame.origin)
        layout.invalidateLayout()
    }

    private func positionSections(listHeight: CGFloat, width: CGFloat) {
        guideLabel.frame = NSRect(x: 8, y: 6, width: width - 16, height: 16)
        if layout.displaysBottomUp {
            recentStack.frame = NSRect(x: 8, y: 28, width: width - 16, height: 26)
            recentTitle.frame = NSRect(x: 8, y: 56, width: width - 16, height: 16)
            scrollView.frame = NSRect(x: 4, y: 76, width: width - 8, height: listHeight)
        } else {
            scrollView.frame = NSRect(x: 4, y: 28, width: width - 8, height: listHeight)
            recentStack.frame = NSRect(
                x: 8,
                y: listHeight + 32,
                width: width - 16,
                height: 26
            )
            recentTitle.frame = NSRect(
                x: 8,
                y: listHeight + 60,
                width: width - 16,
                height: 16
            )
        }
    }

    private func overlapArea(of frame: NSRect) -> CGFloat {
        avoidedFrames.reduce(0) { result, avoided in
            let intersection = frame.intersection(avoided)
            return result + max(intersection.width, 0) * max(intersection.height, 0)
        }
    }

    private func scrollToListBottom() {
        collectionView.layoutSubtreeIfNeeded()
        let bottomY = max(
            collectionView.frame.height - scrollView.contentView.bounds.height,
            0
        )
        scrollView.contentView.scroll(to: NSPoint(x: 0, y: bottomY))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func scrollToPreferredEdge() {
        if layout.displaysBottomUp {
            scrollToListBottom()
        } else {
            collectionView.layoutSubtreeIfNeeded()
            scrollView.contentView.scroll(to: .zero)
            scrollView.reflectScrolledClipView(scrollView.contentView)
        }
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
        guard canSelectEmoji else { return }
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
        let searchTerms = loadSearchTerms()
        for root in resourceRoots() {
            let url = root.appendingPathComponent("Emoji/catalog.tsv")
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            let values = text.split(whereSeparator: \.isNewline).compactMap { line -> Entry? in
                let columns = line.split(separator: "\t", maxSplits: 1).map(String.init)
                guard columns.count == 2 else { return nil }
                return Entry(
                    code: columns[0],
                    emoji: columns[1],
                    searchTerms: searchTerms[columns[0]] ?? []
                )
            }
            if !values.isEmpty { return values }
        }
        return fallbackEmojis.map { emoji in
            Entry(
                code: emoji.unicodeScalars.filter { $0.value != 0xFE0F }
                    .map { String($0.value, radix: 16) }.joined(separator: "-"),
                emoji: emoji,
                searchTerms: []
            )
        }
    }

    private static func loadSearchTerms() -> [String: [String]] {
        for root in resourceRoots() {
            let url = root.appendingPathComponent("Emoji/search-terms.tsv")
            guard let text = try? String(contentsOf: url, encoding: .utf8) else {
                continue
            }
            return Dictionary(uniqueKeysWithValues: text
                .split(whereSeparator: \.isNewline)
                .compactMap { line -> (String, [String])? in
                    let columns = line.split(
                        separator: "\t",
                        maxSplits: 2,
                        omittingEmptySubsequences: false
                    ).map(String.init)
                    guard columns.count == 3 else { return nil }
                    let terms = (columns[1] + "|" + columns[2])
                        .split(separator: "|").map(String.init)
                    return (columns[0], terms)
                })
        }
        return [:]
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
        visibleEntries.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: NSUserInterfaceItemIdentifier("EmojiItem"),
            for: indexPath
        ) as! EmojiCollectionItem
        item.configure(emoji: visibleEntries[indexPath.item].emoji)
        return item
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        didSelectItemsAt indexPaths: Set<IndexPath>
    ) {
        guard canSelectEmoji else {
            collectionView.selectionIndexPaths = []
            return
        }
        guard let index = indexPaths.first?.item,
              visibleEntries.indices.contains(index) else { return }
        selectedRecentIndex = nil
        updateRecentSelection()
        selectedIndex = index
        showComparison(for: visibleEntries[index])
    }
}
