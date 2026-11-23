@preconcurrency import AppKit
import CoreText
import MyIMECore

private final class EmojiCellButton: NSButton {
    /// Only the variations follow the pointer
    var onHover: (() -> Void)? {
        didSet { updateTrackingAreas() }
    }
    private var hoverArea: NSTrackingArea?

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let hoverArea { removeTrackingArea(hoverArea) }
        hoverArea = nil
        guard onHover != nil else { return }
        let area = NSTrackingArea(
            rect: .zero,
            options: [.mouseEnteredAndExited, .activeAlways, .inVisibleRect],
            owner: self
        )
        addTrackingArea(area)
        hoverArea = area
    }

    override func mouseEntered(with event: NSEvent) {
        onHover?()
    }

    override func draw(_ dirtyRect: NSRect) {
        guard !title.isEmpty,
              let context = NSGraphicsContext.current?.cgContext else {
            return
        }

        context.saveGState()
        defer { context.restoreGState() }
        if isFlipped {
            context.translateBy(x: 0, y: bounds.height)
            context.scaleBy(x: 1, y: -1)
        }

        let font = font ?? NSFont(name: "Apple Color Emoji", size: 22)
            ?? NSFont.systemFont(ofSize: 22)
        let line = CTLineCreateWithAttributedString(NSAttributedString(
            string: title,
            attributes: [.font: font]
        ))
        var imageBounds = CTLineGetImageBounds(line, context)
        if imageBounds.isNull || imageBounds.isEmpty {
            var ascent: CGFloat = 0
            var descent: CGFloat = 0
            var leading: CGFloat = 0
            let width = CGFloat(CTLineGetTypographicBounds(
                line,
                &ascent,
                &descent,
                &leading
            ))
            imageBounds = NSRect(
                x: 0,
                y: -descent,
                width: width,
                height: ascent + descent
            )
        }

        context.textMatrix = .identity
        context.textPosition = CGPoint(
            x: bounds.midX - imageBounds.midX,
            y: bounds.midY - imageBounds.midY
        )
        CTLineDraw(line, context)
    }
}

private final class EmojiCollectionItem: NSCollectionViewItem {
    override func loadView() {
        // The button takes the click itself, as the recent emojis do; the
        // collection view tracks a mouse-down to its mouse-up for selection
        // and dragging, which a click gesture on it does not receive
        let button = EmojiCellButton(
            title: "",
            target: nil,
            action: nil
        )
        button.font = NSFont(name: "Apple Color Emoji", size: 22)
        button.alignment = .center
        button.isBordered = false
        button.focusRingType = .none
        view = button
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

    /// `index` is the item's position in the visible entries, set again
    /// whenever a reused item shows another emoji
    func configure(
        emoji: String,
        index: Int,
        target: AnyObject,
        action: Selector
    ) {
        guard let button = view as? NSButton else { return }
        button.title = emoji
        button.tag = index
        button.target = target
        button.action = action
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
        let normalizedSearchText: String
    }

    static let shared = EmojiWindowController()
    static let columnCount = 6
    private static let recentColumnCount = columnCount
    private static let recentDefaultsKey = "EmojiRecentHistory"
    private static let spacing: CGFloat = 2
    private static let outerPadding = InputPanelPositioning.outerPadding
    private static let panelWidth = InputPanelPositioning.panelSize.width
    private static let cellSize = (
        panelWidth - outerPadding * 2
            - spacing * CGFloat(columnCount - 1)
    ) / CGFloat(columnCount)
    private static let recentCellWidth = cellSize
    private static let recentCellHeight = cellSize
    private static let recentContentHeight = recentCellHeight * 2 + spacing
    private static let recentAreaHeight = recentContentHeight
    private static let panelChromeHeight = recentAreaHeight
        + outerPadding * 3 + 1
    private static let maximumListHeight = panelWidth - panelChromeHeight
    private static let comparisonPanelSize = NSSize(width: 240, height: 88)
    private static let sidePanelSpacing: CGFloat = 8
    /// The base emoji of the variations sits about half an emoji beside the
    /// selected one
    private static let variationBaseOffset: CGFloat = 18
    private static let fallbackEmojis = Array(
        "😀 😃 😄 😁 😆 😅 😂 🤣 😊 😇 🙂 🙃 😉 😌 😍 🥰 😘 😗 😙 😚 😋 😛 😝 😜 🤪 🤨 🧐 🤓 😎 🤩 🥳 😏 😒 😞 😔 😟 😕 🙁 ☹️ 😣 😖 😫 😩 🥺 😢 😭 😤 😠 😡 🤬 🤯 😳 🥵 🥶 😱 😨 😰 😥 😓 🤗 🤔 🫡 🤭 🫢 🤫 🤥 😶 😐 😑 😬 🙄 😯 😦 😧 😮 😲 🥱 😴 🤤 😪"
            .split(separator: " ").map(String.init)
    )
    private static let entries = loadEntries()
    /// The main entries as the shared search reads them
    private static let searchEntries: [EmojiCandidateSearch.Entry] = mainEntries.map {
        EmojiCandidateSearch.Entry(
            emoji: $0.emoji,
            terms: $0.normalizedSearchText
                .split(separator: "\t")
                .map(String.init)
        )
    }

    private static let searchIndex = EmojiCandidateSearch.Index(
        entries: searchEntries
    )

    /// Emoji offered among the conversion candidates for the typed input
    /// and the words it converts to, such as 猫 for `neko`
    static func conversionCandidates(
        input: String,
        words: [String],
        excluding existing: Set<String>,
        limit: Int
    ) -> [String] {
        let queries = EmojiCandidateSearch.queries(for: input)
            + words.map(EmojiSearchMatcher.normalized).filter { !$0.isEmpty }
        return EmojiCandidateSearch.candidates(
            in: searchIndex,
            queries: queries,
            excluding: existing,
            limit: limit
        )
    }
    private static let entriesByCode = Dictionary(
        uniqueKeysWithValues: entries.map { ($0.code, $0) }
    )
    private static let variationGrouping = EmojiVariationGrouping(
        codes: entries.map(\.code)
    )
    private static let mainEntries: [Entry] = variationGrouping.mainCodes
        .compactMap { baseCode in
            guard let base = entriesByCode[baseCode] else { return nil }
            let searchText = variationGrouping
                .memberCodes(forBaseCode: baseCode)
                .compactMap { entriesByCode[$0]?.normalizedSearchText }
                .joined(separator: "\t")
            return Entry(
                code: base.code,
                emoji: base.emoji,
                normalizedSearchText: searchText
            )
        }

    private let panel: NSPanel
    private let comparisonPanel: NSPanel
    private let variationPanel: NSPanel
    private let collectionView: NSCollectionView
    private let layout: BottomUpEmojiFlowLayout
    private let scrollView: NSScrollView
    private let comparisonStack: NSStackView
    private let variationStack = NSStackView()
    private var selectedIndex: Int?
    private var selectedRecentIndex: Int?
    private var selectedVariationIndex: Int?
    /// The emoji the variations belong to, on screen
    private var variationAnchor: NSRect?
    /// The side and direction the shown variations were laid out for
    private var variationLayout: (expandsLeft: Bool, expandsDown: Bool)?
    private var variationEntries: [Entry] = []
    private var variationButtons: [NSButton] = []
    private var variationSelectionState = EmojiVariationSelectionState()
    private var variationPresentationWorkItem: DispatchWorkItem?
    private var recentHistory: RecentEmojiHistory
    private let recentStack = NSStackView()
    private let recentSeparator = NSView()
    private var recentButtons: [NSButton] = []
    private var visibleEntries: [Entry]
    private var searchQuery = ""
    private var presentationAnchor: NSRect?
    /// Only the runtime verification gives the screens; otherwise the
    /// connected ones
    private var presentationScreens: [InputPanelScreenGeometry]?
    private var lastPlacement: InputPanelPlacement?
    private var avoidedFrames: [NSRect] = []
    private(set) var isSearchConfirmed = false
    private var isClickCommitInProgress = false
    private var onEmojiClicked: ((String) -> Void)?
    private var outsideLocalMonitor: Any?
    private var outsideGlobalMonitor: Any?
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
        visibleEntries = Self.mainEntries
        panel = PassiveInputPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        comparisonPanel = PassiveInputPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        variationPanel = PassiveInputPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        super.init()
        panel.animationBehavior = .none
        comparisonPanel.animationBehavior = .none
        variationPanel.animationBehavior = .none
        panel.becomesKeyOnlyIfNeeded = true
        comparisonPanel.becomesKeyOnlyIfNeeded = true
        variationPanel.becomesKeyOnlyIfNeeded = true
        configurePanels()
        buildCollection()
    }

    var isVisible: Bool { panel.isVisible }
    var visibleFrame: NSRect? { panel.isVisible ? panel.frame : nil }
    var searchText: String { searchQuery }
    var canSelectEmoji: Bool {
        EmojiSearchActivationPolicy.tabNavigatesEmoji(
            searchText: searchQuery,
            isSearchConfirmed: isSearchConfirmed
        )
    }
    private var showsRecentArea: Bool {
        EmojiSearchActivationPolicy.showsRecentEmojis(
            searchText: searchQuery
        )
    }
    private var visibleRecentCount: Int {
        showsRecentArea ? recentHistory.emojis.count : 0
    }
    var selectedEmoji: String? {
        if let selectedRecentIndex,
           recentHistory.emojis.indices.contains(selectedRecentIndex) {
            return recentHistory.emojis[selectedRecentIndex]
        }
        return selectedIndex.map { visibleEntries[$0].emoji }
    }

    func runtimePanelMeasurements(
        keepsPanelVisible: Bool = false,
        placementCases: [InputPanelPlacementCase] = []
    ) -> [InputPanelRuntimeSnapshot] {
        let originalHistory = recentHistory
        if recentHistory.emojis.isEmpty {
            recentHistory = RecentEmojiHistory(emojis: ["😀"])
        }
        var results = [panel.inputPanelRuntimeSnapshot(label: "emoji-created")]
        panel.orderFrontRegardless()
        panel.contentView?.layoutSubtreeIfNeeded()
        panel.displayIfNeeded()
        results.append(panel.inputPanelRuntimeSnapshot(label: "emoji-visible"))

        for placementCase in placementCases {
            results.append(place(placementCase, label: "emoji-placement-\(placementCase.label)"))
        }

        setSearchQuery("")
        panel.contentView?.layoutSubtreeIfNeeded()
        results.append(panel.inputPanelRuntimeSnapshot(label: "emoji-positioned-recent"))

        setSearchQuery("ねこ")
        panel.contentView?.layoutSubtreeIfNeeded()
        results.append(panel.inputPanelRuntimeSnapshot(label: "emoji-searching"))

        panel.orderOut(nil)
        setSearchQuery("")
        panel.orderFrontRegardless()
        panel.contentView?.layoutSubtreeIfNeeded()
        results.append(panel.inputPanelRuntimeSnapshot(label: "emoji-redisplayed"))
        // Closed and shown again at the first place
        if let placementCase = placementCases.first {
            results.append(place(placementCase, label: "emoji-placement-redisplayed"))
        }
        if !keepsPanelVisible {
            panel.orderOut(nil)
        }

        recentHistory = originalHistory
        presentationAnchor = nil
        presentationScreens = nil
        return results
    }

    /// Places the panel through its own presentation, as `show` does
    private func place(
        _ placementCase: InputPanelPlacementCase,
        label: String
    ) -> InputPanelRuntimeSnapshot {
        presentationAnchor = InputPanelPositioning.resolvedAnchor(
            placementCase.anchorFrame,
            fallbackPoint: placementCase.fallbackPoint
        )
        presentationScreens = placementCase.screens
        avoidedFrames = placementCase.avoidedFrames
        updatePanelPresentation()
        panel.contentView?.layoutSubtreeIfNeeded()
        return panel.inputPanelRuntimeSnapshot(label: label, placement: lastPlacement)
    }

    func show(
        near anchor: NSRect,
        onEmojiClicked: @escaping (String) -> Void
    ) {
        self.onEmojiClicked = onEmojiClicked
        isClickCommitInProgress = false
        selectedIndex = nil
        selectedRecentIndex = nil
        resetVariationPresentation()
        collectionView.selectionIndexPaths = []
        updateRecentSelection()
        // Resolved once, so later layouts do not follow the mouse
        presentationAnchor = InputPanelPositioning.resolvedAnchor(
            anchor,
            fallbackPoint: NSEvent.mouseLocation
        )
        presentationScreens = nil
        setSearchQuery("")
        comparisonPanel.orderOut(nil)
        panel.orderFrontRegardless()
        scrollToPreferredEdge()
        DispatchQueue.main.async { [weak self] in
            guard let self, self.panel.isVisible else { return }
            self.scrollToPreferredEdge()
        }
        EmojiGlobalHotKey.shared.beginPanelCapture(
            capturesTab: canSelectEmoji
        )
        startOutsideClickMonitoring()
        EmojiDiagnostics.logger.notice(
            "panel ordered size=\(String(describing: self.panel.frame.size), privacy: .public) origin=\(String(describing: self.panel.frame.origin), privacy: .public) visible=\(self.panel.isVisible, privacy: .public)"
        )
    }

    func hide() {
        if panel.isVisible {
            EmojiDiagnostics.logger.notice("panel hidden")
        }
        // ⌘X captured for the selected recent emoji goes back to the app
        if selectedRecentIndex != nil {
            CandidateDeletionGlobalHotKey.shared.deactivate()
        }
        stopOutsideClickMonitoring()
        EmojiGlobalHotKey.shared.endPanelCapture()
        panel.orderOut(nil)
        comparisonPanel.orderOut(nil)
        variationPanel.orderOut(nil)
        onEmojiClicked = nil
        isClickCommitInProgress = false
        selectedIndex = nil
        selectedRecentIndex = nil
        selectedVariationIndex = nil
        variationEntries = []
        variationButtons = []
        variationSelectionState.reset()
        cancelVariationPresentation()
        isSearchConfirmed = false
        avoidedFrames = []
        presentationAnchor = nil
        presentationScreens = nil
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

    var selectedRecentEmoji: String? {
        guard showsRecentArea,
              let selectedRecentIndex,
              recentHistory.emojis.indices.contains(selectedRecentIndex)
        else { return nil }
        return recentHistory.emojis[selectedRecentIndex]
    }

    /// Removes the selected recent emoji from the history and selects the
    /// one taking its place
    @discardableResult
    func removeSelectedRecentEmoji() -> String? {
        guard let selectedRecentIndex,
              let emoji = selectedRecentEmoji,
              recentHistory.remove(emoji) else { return nil }
        UserDefaults.standard.set(
            recentHistory.emojis,
            forKey: Self.recentDefaultsKey
        )
        self.selectedRecentIndex = nil
        rebuildRecentArea()
        if let next = RecentEmojiHistory.selectionAfterRemoving(
            at: selectedRecentIndex,
            remainingCount: recentHistory.emojis.count
        ) {
            selectRecent(index: next)
        } else {
            resetVariationPresentation()
            comparisonPanel.orderOut(nil)
        }
        return emoji
    }

    func updateSearchText(_ text: String) {
        isSearchConfirmed = false
        setSearchQuery(text)
        updateTabCapture()
    }

    func confirmSearch() {
        resetVariationPresentation()
        isSearchConfirmed = true
        selectedIndex = nil
        selectedRecentIndex = nil
        collectionView.selectionIndexPaths = []
        updateRecentSelection()
        comparisonPanel.orderOut(nil)
        updateTabCapture()
    }

    func advanceSelection(backward: Bool) {
        guard !visibleEntries.isEmpty || visibleRecentCount > 0 else {
            return
        }
        let offset = backward ? -1 : 1
        let recentCount = visibleRecentCount
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
        guard !visibleEntries.isEmpty || visibleRecentCount > 0 else {
            return
        }
        if let selectedRecentIndex {
            moveRecentSelection(from: selectedRecentIndex, direction: direction)
            return
        }
        guard let selectedIndex else {
            if !showsRecentArea || recentHistory.emojis.isEmpty {
                select(index: 0)
            } else {
                selectRecent(index: 0)
            }
            return
        }
        let entersRecentArea = layout.displaysBottomUp
            ? direction == .down && selectedIndex < Self.columnCount
            : direction == .up && selectedIndex < Self.columnCount
        if showsRecentArea,
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

    @discardableResult
    func closeVariationsIfShown() -> Bool {
        guard variationPanel.isVisible else { return false }
        dismissVariationPresentation()
        return true
    }

    private func selectVariation(index: Int) {
        guard variationEntries.indices.contains(index) else { return }
        selectedVariationIndex = index
        for button in variationButtons {
            button.layer?.backgroundColor = button.tag == index
                ? NSColor.controlAccentColor.cgColor
                : NSColor.clear.cgColor
        }
        showComparison(for: variationEntries[index])
    }

    private func select(
        index: Int,
        presentsVariationsImmediately: Bool = false
    ) {
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
        updateVariationPresentation(
            for: visibleEntries[index],
            near: screenFrameForCollectionItem(at: index)
                ?? fallbackVariationAnchor(),
            presentsImmediately: presentsVariationsImmediately
        )
    }

    private func selectRecent(
        index: Int,
        presentsVariationsImmediately: Bool = false
    ) {
        guard recentHistory.emojis.indices.contains(index),
              let entry = Self.entries.first(where: {
                  $0.emoji == recentHistory.emojis[index]
              }) else { return }
        selectedIndex = nil
        collectionView.selectionIndexPaths = []
        selectedRecentIndex = index
        updateRecentSelection()
        updateVariationPresentation(
            for: entry,
            near: screenFrameForRecentEmoji(at: index)
                ?? fallbackVariationAnchor(),
            presentsImmediately: presentsVariationsImmediately
        )
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
            if layout.displaysBottomUp {
                let next = index + Self.recentColumnCount
                if next < count {
                    selectRecent(index: next)
                } else {
                    select(index: min(
                        index % Self.recentColumnCount,
                        visibleEntries.count - 1
                    ))
                }
            } else {
                let previous = index - Self.recentColumnCount
                if previous >= 0 {
                    selectRecent(index: previous)
                }
            }
        case .down:
            if layout.displaysBottomUp {
                let previous = index - Self.recentColumnCount
                if previous >= 0 {
                    selectRecent(index: previous)
                }
            } else {
                let next = index + Self.recentColumnCount
                if next < count {
                    selectRecent(index: next)
                } else {
                    select(index: min(
                        index % Self.recentColumnCount,
                        visibleEntries.count - 1
                    ))
                }
            }
        }
    }

    private func configurePanels() {
        for value in [panel, comparisonPanel, variationPanel] {
            value.applyInputPanelStyle()
        }
        // The variations lie over the emoji panel
        variationPanel.level = NSWindow.Level(rawValue: panel.level.rawValue + 1)
        comparisonStack.orientation = .horizontal
        comparisonStack.alignment = .top
        comparisonStack.distribution = .fillEqually
        comparisonStack.spacing = 8
        comparisonStack.edgeInsets = NSEdgeInsets(top: 8, left: 8, bottom: 8, right: 8)
        comparisonPanel.contentView = comparisonStack
        variationStack.orientation = .vertical
        variationStack.alignment = .leading
        variationStack.spacing = Self.spacing
        variationStack.edgeInsets = NSEdgeInsets(
            top: Self.outerPadding,
            left: Self.outerPadding,
            bottom: Self.outerPadding,
            right: Self.outerPadding
        )
        variationPanel.contentView = variationStack
        recentStack.orientation = .vertical
        recentStack.alignment = .leading
        recentStack.spacing = Self.spacing
        recentStack.edgeInsets = NSEdgeInsets(
            top: 0,
            left: 0,
            bottom: 0,
            right: 0
        )
        recentSeparator.wantsLayer = true
        recentSeparator.layer?.backgroundColor = NSColor.separatorColor.cgColor
    }

    private func buildCollection() {
        layout.itemSize = NSSize(width: Self.cellSize, height: Self.cellSize)
        layout.minimumInteritemSpacing = Self.spacing
        layout.minimumLineSpacing = Self.spacing
        layout.sectionInset = NSEdgeInsets(
            top: Self.outerPadding,
            left: Self.outerPadding,
            bottom: Self.outerPadding,
            right: Self.outerPadding
        )
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
        scrollView.contentView.postsBoundsChangedNotifications = true
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(collectionBoundsDidChange(_:)),
            name: NSView.boundsDidChangeNotification,
            object: scrollView.contentView
        )
        let width = Self.panelWidth
        let height = Self.maximumListHeight + Self.panelChromeHeight
        let contentSize = NSSize(width: width, height: height)
        let root = NSView(
            frame: NSRect(origin: .zero, size: contentSize)
        )
        let rowCount = ceil(
            CGFloat(Self.mainEntries.count) / CGFloat(Self.columnCount)
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
        positionSections(listHeight: Self.maximumListHeight, width: width)
        root.addSubview(scrollView)
        root.addSubview(recentSeparator)
        root.addSubview(recentStack)
        panel.contentView = root
        panel.setContentSize(contentSize)
        root.frame = NSRect(origin: .zero, size: contentSize)
        panel.applyInputPanelStyle()
        rebuildRecentArea()
    }

    private func setSearchQuery(_ query: String) {
        resetVariationPresentation()
        searchQuery = query
        // The same search the conversion candidates use, matching any part
        // of a term here
        let normalizedQueries = EmojiCandidateSearch.queries(
            for: query,
            converter: romajiConverter
        )
        let matches = normalizedQueries.isEmpty
            ? Self.mainEntries
            : zip(Self.mainEntries, Self.searchEntries).filter { _, entry in
                EmojiCandidateSearch.relevance(
                    of: entry,
                    queries: normalizedQueries
                ) != nil
            }.map(\.0)
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

    private func updateTabCapture() {
        guard panel.isVisible else { return }
        EmojiGlobalHotKey.shared.setPanelTabCaptureEnabled(canSelectEmoji)
    }

    private func updatePanelPresentation() {
        let previousDirection = layout.displaysBottomUp
        let rowCount = max(
            ceil(CGFloat(visibleEntries.count) / CGFloat(Self.columnCount)),
            1
        )
        let documentHeight = layout.sectionInset.top
            + rowCount * Self.cellSize
            + max(rowCount - 1, 0) * Self.spacing
            + layout.sectionInset.bottom
        let listHeight = panel.frame.width
            - (showsRecentArea ? Self.panelChromeHeight : 0)
        let size = InputPanelPositioning.panelSize
        panel.setContentSize(size)
        panel.contentView?.frame = NSRect(origin: .zero, size: size)
        scrollView.frame.size.height = listHeight
        collectionView.setFrameSize(NSSize(
            width: scrollView.contentSize.width,
            height: max(documentHeight, scrollView.contentSize.height)
        ))

        guard let anchor = presentationAnchor else { return }
        let screens = presentationScreens
            ?? NSScreen.screens.map(InputPanelPositioning.screenGeometry)
        let placement = InputPanelPositioning.placement(
            anchorFrame: anchor,
            screens: screens,
            avoidedFrames: avoidedFrames,
            fallbackPoint: NSEvent.mouseLocation,
            panelSize: size
        )
        lastPlacement = placement
        layout.displaysBottomUp = placement.direction == .above
        positionSections(listHeight: listHeight, width: size.width)
        if previousDirection != layout.displaysBottomUp {
            rebuildRecentArea()
        }
        panel.setFrame(placement.frame, display: panel.isVisible)
        layout.invalidateLayout()
    }

    private func positionSections(listHeight: CGFloat, width: CGFloat) {
        recentStack.isHidden = !showsRecentArea
        recentSeparator.isHidden = !showsRecentArea
        guard showsRecentArea else {
            scrollView.frame = NSRect(
                x: 0,
                y: 0,
                width: width,
                height: listHeight
            )
            return
        }
        if layout.displaysBottomUp {
            recentStack.frame = NSRect(
                x: 8, y: 8, width: width - 16,
                height: Self.recentAreaHeight
            )
            recentSeparator.frame = NSRect(
                x: 8,
                y: Self.outerPadding + Self.recentAreaHeight
                    + Self.outerPadding,
                width: width - 16,
                height: 1
            )
            scrollView.frame = NSRect(
                x: 0,
                y: Self.panelChromeHeight,
                width: width,
                height: listHeight
            )
        } else {
            scrollView.frame = NSRect(
                x: 0, y: 0, width: width, height: listHeight
            )
            recentSeparator.frame = NSRect(
                x: 8, y: listHeight + 8,
                width: width - 16, height: 1
            )
            recentStack.frame = NSRect(
                x: 8,
                y: listHeight + 17,
                width: width - 16,
                height: Self.recentAreaHeight
            )
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
        let rowStarts = Array(stride(
            from: 0,
            to: recentHistory.emojis.count,
            by: Self.recentColumnCount
        ))
        let displayedRowStarts = layout.displaysBottomUp
            ? Array(rowStarts.reversed())
            : rowStarts
        for rowStart in displayedRowStarts {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = Self.spacing
            let rowEnd = min(
                rowStart + Self.recentColumnCount,
                recentHistory.emojis.count
            )
            for index in rowStart..<rowEnd {
                let button = EmojiCellButton(
                    title: recentHistory.emojis[index],
                    target: self,
                    action: #selector(selectRecentEmoji(_:))
                )
                button.tag = index
                button.font = NSFont(name: "Apple Color Emoji", size: 22)
                button.alignment = .center
                button.isBordered = false
                button.focusRingType = .none
                button.wantsLayer = true
                button.layer?.cornerRadius = 0
                button.widthAnchor.constraint(
                    equalToConstant: Self.recentCellWidth
                ).isActive = true
                button.heightAnchor.constraint(
                    equalToConstant: Self.recentCellHeight
                ).isActive = true
                row.addArrangedSubview(button)
                recentButtons.append(button)
            }
            recentStack.addArrangedSubview(row)
        }
        updateRecentSelection()
    }

    @objc private func selectRecentEmoji(_ sender: NSButton) {
        guard recentHistory.emojis.indices.contains(sender.tag),
              let entry = Self.entries.first(where: {
                  $0.emoji == recentHistory.emojis[sender.tag]
              }) else { return }
        selectRecent(
            index: sender.tag,
            presentsVariationsImmediately: true
        )
        if variationEntries(for: entry).count > 1 {
            return
        }
        activateClickedEmoji(
            recentHistory.emojis[sender.tag],
            index: sender.tag,
            itemCount: recentHistory.emojis.count
        )
    }

    @objc private func commitClickedCollectionEmoji(_ sender: NSButton) {
        let index = sender.tag
        EmojiDiagnostics.logger.notice(
            "grid emoji clicked index=\(index, privacy: .public) count=\(self.visibleEntries.count, privacy: .public)"
        )
        guard visibleEntries.indices.contains(index),
              visibleEntries[index].emoji == sender.title else { return }
        let entry = visibleEntries[index]
        select(
            index: index,
            presentsVariationsImmediately: true
        )
        if variationEntries(for: entry).count > 1 {
            return
        }
        activateClickedEmoji(
            entry.emoji,
            index: index,
            itemCount: visibleEntries.count
        )
    }

    @objc private func commitClickedVariation(_ sender: NSButton) {
        guard variationEntries.indices.contains(sender.tag) else { return }
        selectVariation(index: sender.tag)
        activateClickedEmoji(
            variationEntries[sender.tag].emoji,
            index: sender.tag,
            itemCount: variationEntries.count
        )
    }

    private func variationEntries(for entry: Entry) -> [Entry] {
        Self.variationGrouping
            .memberCodes(forBaseCode: entry.code)
            .compactMap { Self.entriesByCode[$0] }
    }

    private func updateVariationPresentation(
        for entry: Entry,
        near anchor: NSRect,
        presentsImmediately: Bool
    ) {
        let variations = variationEntries(for: entry)
        let baseCode = variations.count > 1 ? entry.code : nil
        switch variationSelectionState.selectionChanged(
            to: baseCode,
            presentsImmediately: presentsImmediately
        ) {
        case let .schedule(baseCode, generation):
            clearVariationPanel()
            showComparison(for: entry)
            scheduleVariationPresentation(
                for: baseCode,
                generation: generation
            )
        case .show:
            cancelVariationPresentation()
            showVariations(variations, near: anchor)
        case .keep:
            positionVariationPanel(near: anchor)
        case .hide:
            cancelVariationPresentation()
            clearVariationPanel()
            showComparison(for: entry)
        }
    }

    private func scheduleVariationPresentation(
        for baseCode: String,
        generation: Int
    ) {
        cancelVariationPresentationWorkItem()
        let workItem = DispatchWorkItem { [weak self] in
            guard let self,
                  self.variationSelectionState.pendingGeneration == generation
            else { return }
            self.variationPresentationWorkItem = nil
            guard self.panel.isVisible,
                  let entry = self.selectedEntry,
                  entry.code == baseCode,
                  let anchor = self.selectedEntryAnchor
            else {
                self.variationSelectionState.cancelPendingPresentation()
                return
            }
            guard self.variationSelectionState.scheduledPresentationFired(
                for: baseCode,
                generation: generation
            ) else { return }
            let variations = self.variationEntries(for: entry)
            guard variations.count > 1 else { return }
            self.showVariations(variations, near: anchor)
        }
        variationPresentationWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now()
                + EmojiVariationSelectionState.automaticPresentationDelay,
            execute: workItem
        )
    }

    private func cancelVariationPresentation() {
        cancelVariationPresentationWorkItem()
        variationSelectionState.cancelPendingPresentation()
    }

    private func cancelVariationPresentationWorkItem() {
        variationPresentationWorkItem?.cancel()
        variationPresentationWorkItem = nil
    }

    private var selectedEntry: Entry? {
        if let selectedRecentIndex,
           recentHistory.emojis.indices.contains(selectedRecentIndex) {
            return Self.entries.first {
                $0.emoji == recentHistory.emojis[selectedRecentIndex]
            }
        }
        guard let selectedIndex,
              visibleEntries.indices.contains(selectedIndex) else { return nil }
        return visibleEntries[selectedIndex]
    }

    private var selectedEntryAnchor: NSRect? {
        if let selectedRecentIndex {
            return screenFrameForRecentEmoji(at: selectedRecentIndex)
                ?? fallbackVariationAnchor()
        }
        guard let selectedIndex else { return nil }
        let indexPath = IndexPath(item: selectedIndex, section: 0)
        collectionView.layoutSubtreeIfNeeded()
        guard let attributes = collectionView.collectionViewLayout?
            .layoutAttributesForItem(at: indexPath),
              collectionView.visibleRect.intersects(attributes.frame)
        else { return nil }
        return screenFrameForCollectionItem(at: selectedIndex)
    }

    private func showVariations(_ entries: [Entry], near anchor: NSRect) {
        variationEntries = entries
        selectedVariationIndex = 0
        variationStack.arrangedSubviews.forEach {
            variationStack.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }
        variationButtons = []
        // The variations open diagonally away from the comparison, in the
        // direction the emoji panel itself opened, with the base emoji at
        // the end nearest the selected emoji; only the order shown changes,
        // and each button keeps its entry's index as its tag
        let expandsLeft = variationExpandsLeft
        let expandsDown = !layout.displaysBottomUp
        variationLayout = (expandsLeft, expandsDown)
        variationStack.alignment = expandsLeft ? .trailing : .leading
        var rowViews: [NSStackView] = []

        for rowStart in stride(
            from: 0,
            to: entries.count,
            by: Self.columnCount
        ) {
            let row = NSStackView()
            row.orientation = .horizontal
            row.spacing = Self.spacing
            let rowEnd = min(rowStart + Self.columnCount, entries.count)
            let indices = Array(rowStart..<rowEnd)
            for index in expandsLeft ? indices.reversed() : indices {
                let button = EmojiCellButton(
                    title: entries[index].emoji,
                    target: self,
                    action: #selector(commitClickedVariation(_:))
                )
                button.tag = index
                button.onHover = { [weak self] in
                    self?.selectVariation(index: index)
                }
                button.font = NSFont(name: "Apple Color Emoji", size: 22)
                button.alignment = .center
                button.isBordered = false
                button.focusRingType = .none
                button.wantsLayer = true
                button.layer?.cornerRadius = 0
                button.widthAnchor.constraint(
                    equalToConstant: Self.cellSize
                ).isActive = true
                button.heightAnchor.constraint(
                    equalToConstant: Self.cellSize
                ).isActive = true
                row.addArrangedSubview(button)
                variationButtons.append(button)
            }
            rowViews.append(row)
        }
        // The row of the base emoji is the one nearest the selected emoji
        for row in expandsDown ? rowViews : rowViews.reversed() {
            variationStack.addArrangedSubview(row)
        }
        selectVariation(index: 0)

        let columns = min(entries.count, Self.columnCount)
        let rows = Int(ceil(
            Double(entries.count) / Double(Self.columnCount)
        ))
        let size = NSSize(
            width: Self.outerPadding * 2
                + Self.cellSize * CGFloat(columns)
                + Self.spacing * CGFloat(max(columns - 1, 0)),
            height: Self.outerPadding * 2
                + Self.cellSize * CGFloat(rows)
                + Self.spacing * CGFloat(max(rows - 1, 0))
        )
        variationPanel.setContentSize(size)
        variationStack.frame = NSRect(origin: .zero, size: size)
        positionVariationPanel(near: anchor)
        variationPanel.orderFrontRegardless()
        comparisonPanel.orderFrontRegardless()
        updateTabCapture()
    }

    private func positionVariationPanel(near anchor: NSRect) {
        guard variationPanel.isVisible || !variationEntries.isEmpty else {
            return
        }
        variationAnchor = anchor
        layoutSidePanels(includingComparison: comparisonPanel.isVisible)
    }

    /// The variations over the panel at their emoji, and the comparison
    /// beside the panel, each from its own anchor
    private func layoutSidePanels(includingComparison: Bool) {
        let visible = sidePanelVisibleFrame
        let comparison = comparisonFrame
        if includingComparison {
            comparisonPanel.setFrameOrigin(comparison.origin)
        }
        guard !variationEntries.isEmpty, let variationAnchor else { return }
        // The emoji panel moved to where the side or direction changes
        if let built = variationLayout,
           built != (variationExpandsLeft, !layout.displaysBottomUp) {
            let selected = selectedVariationIndex
            showVariations(variationEntries, near: variationAnchor)
            if let selected { selectVariation(index: selected) }
            return
        }
        let size = variationPanel.frame.size
        variationPanel.setFrameOrigin(EmojiSidePanelLayout.variationFrame(
            cell: variationAnchor,
            size: size,
            baseCenterX: variationExpandsLeft
                ? size.width - Self.outerPadding - Self.cellSize / 2
                : Self.outerPadding + Self.cellSize / 2,
            expandsLeft: variationExpandsLeft,
            expandsDown: !layout.displaysBottomUp,
            baseOffset: Self.variationBaseOffset,
            gap: Self.spacing,
            avoiding: includingComparison ? comparison : nil,
            visibleFrame: visible,
            spacing: Self.sidePanelSpacing
        ).origin)
    }

    private var sidePanelVisibleFrame: NSRect {
        panel.screen?.visibleFrame
            ?? NSScreen.inputScreen(containing: panel.frame)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
    }

    /// Beside the emoji panel as it was placed, which the side panels
    /// follow and never move
    private var comparisonFrame: NSRect {
        EmojiSidePanelLayout.comparisonFrame(
            panel: panel.frame,
            size: Self.comparisonPanelSize,
            visibleFrame: sidePanelVisibleFrame,
            spacing: Self.sidePanelSpacing
        )
    }

    /// The variations open on the side away from the comparison
    private var variationExpandsLeft: Bool {
        EmojiSidePanelLayout.comparisonIsOnRight(
            comparison: comparisonFrame,
            panel: panel.frame
        )
    }

    private func dismissVariationPresentation() {
        cancelVariationPresentation()
        variationSelectionState.dismissCurrent()
        clearVariationPanel()
        // The comparison goes back to the emoji the variations belonged to
        if comparisonPanel.isVisible, let entry = selectedEntry {
            showComparison(for: entry)
        }
    }

    private func resetVariationPresentation() {
        cancelVariationPresentation()
        variationSelectionState.reset()
        clearVariationPanel()
    }

    private func clearVariationPanel() {
        variationPanel.orderOut(nil)
        selectedVariationIndex = nil
        variationEntries = []
        variationButtons = []
        variationAnchor = nil
        variationLayout = nil
        if comparisonPanel.isVisible {
            layoutSidePanels(includingComparison: true)
        }
        updateTabCapture()
    }

    private func screenFrameForCollectionItem(at index: Int) -> NSRect? {
        let indexPath = IndexPath(item: index, section: 0)
        collectionView.layoutSubtreeIfNeeded()
        guard let attributes = collectionView.collectionViewLayout?
            .layoutAttributesForItem(at: indexPath) else { return nil }
        let windowFrame = collectionView.convert(attributes.frame, to: nil)
        return panel.convertToScreen(windowFrame)
    }

    @objc private func collectionBoundsDidChange(_ notification: Notification) {
        guard variationPanel.isVisible,
              selectedRecentIndex == nil,
              let selectedIndex else { return }
        let indexPath = IndexPath(item: selectedIndex, section: 0)
        collectionView.layoutSubtreeIfNeeded()
        guard let attributes = collectionView.collectionViewLayout?
            .layoutAttributesForItem(at: indexPath),
              collectionView.visibleRect.intersects(attributes.frame),
              let anchor = screenFrameForCollectionItem(at: selectedIndex)
        else {
            dismissVariationPresentation()
            return
        }
        positionVariationPanel(near: anchor)
    }

    private func screenFrameForRecentEmoji(at index: Int) -> NSRect? {
        guard let button = recentButtons.first(where: { $0.tag == index }) else {
            return nil
        }
        return panel.convertToScreen(button.convert(button.bounds, to: nil))
    }

    private func fallbackVariationAnchor() -> NSRect {
        NSRect(
            x: panel.frame.midX,
            y: panel.frame.midY,
            width: 0,
            height: 0
        )
    }

    private func activateClickedEmoji(
        _ emoji: String,
        index: Int,
        itemCount: Int
    ) {
        guard case .commit = EmojiSearchActivationPolicy.clickAction(
            index: index,
            itemCount: itemCount,
            isPanelVisible: panel.isVisible,
            isCommitInProgress: isClickCommitInProgress
        ), let onEmojiClicked else { return }
        isClickCommitInProgress = true
        onEmojiClicked(emoji)
    }

    private func updateRecentSelection() {
        for button in recentButtons {
            button.layer?.backgroundColor = button.tag == selectedRecentIndex
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
        comparisonPanel.setContentSize(Self.comparisonPanelSize)
        layoutSidePanels(includingComparison: true)
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
        stack.alignment = .centerX
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
                    normalizedSearchText: ([columns[1]]
                        + (searchTerms[columns[0]] ?? []))
                        .map(EmojiSearchMatcher.normalized)
                        .joined(separator: "\t")
                )
            }
            if !values.isEmpty { return values }
        }
        return fallbackEmojis.map { emoji in
            Entry(
                code: emoji.unicodeScalars.filter { $0.value != 0xFE0F }
                    .map { String($0.value, radix: 16) }.joined(separator: "-"),
                emoji: emoji,
                normalizedSearchText: EmojiSearchMatcher.normalized(emoji)
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

    private func startOutsideClickMonitoring() {
        stopOutsideClickMonitoring()
        let events: NSEvent.EventTypeMask = [
            .leftMouseDown, .rightMouseDown, .otherMouseDown
        ]
        outsideLocalMonitor = NSEvent.addLocalMonitorForEvents(
            matching: events
        ) { [weak self] event in
            self?.cancelIfClickIsOutside(at: NSEvent.mouseLocation)
            return event
        }
        outsideGlobalMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: events
        ) { [weak self] _ in
            let point = NSEvent.mouseLocation
            DispatchQueue.main.async {
                self?.cancelIfClickIsOutside(at: point)
            }
        }
    }

    private func stopOutsideClickMonitoring() {
        if let monitor = outsideLocalMonitor {
            NSEvent.removeMonitor(monitor)
            outsideLocalMonitor = nil
        }
        if let monitor = outsideGlobalMonitor {
            NSEvent.removeMonitor(monitor)
            outsideGlobalMonitor = nil
        }
    }

    private func cancelIfClickIsOutside(at point: NSPoint) {
        guard panel.isVisible else { return }
        if variationPanel.isVisible {
            guard !variationPanel.frame.contains(point),
                  !comparisonPanel.frame.contains(point) else { return }
            dismissVariationPresentation()
            return
        }
        guard !panel.frame.contains(point),
              !comparisonPanel.frame.contains(point) else { return }
        hide()
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
        item.configure(
            emoji: visibleEntries[indexPath.item].emoji,
            index: indexPath.item,
            target: self,
            action: #selector(commitClickedCollectionEmoji(_:))
        )
        return item
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        didSelectItemsAt indexPaths: Set<IndexPath>
    ) {
        guard let index = indexPaths.first?.item,
              visibleEntries.indices.contains(index) else { return }
        selectedRecentIndex = nil
        updateRecentSelection()
        selectedIndex = index
        updateVariationPresentation(
            for: visibleEntries[index],
            near: screenFrameForCollectionItem(at: index)
                ?? fallbackVariationAnchor(),
            presentsImmediately: false
        )
    }
}
