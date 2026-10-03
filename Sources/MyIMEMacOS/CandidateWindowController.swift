@preconcurrency import AppKit
import MyIMECore

enum CandidateNavigationDirection: Equatable {
    case left
    case right
    case up
    case down
}

enum PanelShortcutGuideStyle {
    static let font = NSFont.systemFont(ofSize: 11)
    static let color = NSColor.secondaryLabelColor
    static let horizontalPadding: CGFloat = 10
    static let verticalPadding: CGFloat = 4

    static var isEnabled: Bool { false }
}

enum CandidatePanelItemStyle {
    static let font = NSFont.systemFont(ofSize: NSFont.systemFontSize)
    static let minimumWidth: CGFloat = 32
    static let maximumWidth: CGFloat = 240
    static let maximumPanelWidth: CGFloat = 360
    static let spacing: CGFloat = 2
    static let maximumVisibleCount = 4
    static let horizontalPadding: CGFloat = 9
    static let verticalPadding: CGFloat = 9
    static let accessorySpacing: CGFloat = 8
    static let accessoryFont = NSFont.systemFont(ofSize: 8)
    static let height = ceil(
        font.ascender - font.descender + font.leading
    ) + verticalPadding * 2
}

final class CandidatePanelRowView: NSView {
    private let label = NSTextField(labelWithString: "")
    private let accessoryLabel = NSTextField(labelWithString: "●")
    private let contentStack = NSStackView()
    private var text = ""
    private var showsAlternateCommitIndicator = false
    private var fixedWidthConstraint: NSLayoutConstraint?
    private var fixedHeightConstraint: NSLayoutConstraint?

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        wantsLayer = true
        layer?.cornerRadius = 0
        label.translatesAutoresizingMaskIntoConstraints = false
        label.font = CandidatePanelItemStyle.font
        label.lineBreakMode = .byTruncatingTail
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        accessoryLabel.font = CandidatePanelItemStyle.accessoryFont
        accessoryLabel.alignment = .center
        accessoryLabel.setContentHuggingPriority(.required, for: .horizontal)
        accessoryLabel.setContentCompressionResistancePriority(
            .required,
            for: .horizontal
        )
        contentStack.translatesAutoresizingMaskIntoConstraints = false
        contentStack.orientation = .horizontal
        contentStack.alignment = .centerY
        contentStack.distribution = .fill
        contentStack.spacing = CandidatePanelItemStyle.accessorySpacing
        contentStack.detachesHiddenViews = true
        contentStack.addArrangedSubview(label)
        contentStack.addArrangedSubview(accessoryLabel)
        addSubview(contentStack)
        NSLayoutConstraint.activate([
            contentStack.leadingAnchor.constraint(
                equalTo: leadingAnchor,
                constant: CandidatePanelItemStyle.horizontalPadding
            ),
            contentStack.trailingAnchor.constraint(
                equalTo: trailingAnchor,
                constant: -CandidatePanelItemStyle.horizontalPadding
            ),
            contentStack.centerYAnchor.constraint(equalTo: centerYAnchor)
        ])
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func configure(
        text: String,
        isSelected: Bool,
        showsAlternateCommitIndicator: Bool = false
    ) {
        self.text = text
        self.showsAlternateCommitIndicator = showsAlternateCommitIndicator
        label.stringValue = text
        accessoryLabel.isHidden = !showsAlternateCommitIndicator
        layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.cgColor
            : NSColor.clear.cgColor
        label.textColor = isSelected
            ? .alternateSelectedControlTextColor
            : .labelColor
        accessoryLabel.textColor = isSelected
            ? .alternateSelectedControlTextColor
            : .secondaryLabelColor
    }

    func updateSelection(_ isSelected: Bool) {
        configure(
            text: text,
            isSelected: isSelected,
            showsAlternateCommitIndicator: showsAlternateCommitIndicator
        )
    }

    func setFixedSize(width: CGFloat, height: CGFloat) {
        if fixedWidthConstraint == nil {
            fixedWidthConstraint = widthAnchor.constraint(equalToConstant: width)
            fixedHeightConstraint = heightAnchor.constraint(equalToConstant: height)
            fixedWidthConstraint?.isActive = true
            fixedHeightConstraint?.isActive = true
        } else {
            fixedWidthConstraint?.constant = width
            fixedHeightConstraint?.constant = height
        }
    }
}

private final class CandidateCollectionItem: NSCollectionViewItem {
    private let rowView = CandidatePanelRowView(frame: .zero)

    override func loadView() {
        view = rowView
        updateSelectionAppearance()
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
        }
    }

    func configure(text: String, showsAlternateCommitIndicator: Bool) {
        rowView.configure(
            text: text,
            isSelected: isSelected,
            showsAlternateCommitIndicator: showsAlternateCommitIndicator
        )
    }

    private func updateSelectionAppearance() {
        guard isViewLoaded else {
            return
        }

        rowView.updateSelection(isSelected)
    }
}

final class CandidateWindowController: NSObject {
    private static let itemIdentifier = NSUserInterfaceItemIdentifier(
        "candidateItem"
    )
    private static let itemHeight = CandidatePanelItemStyle.height
    private static let maximumRows = 4
    private static let anchorSpacing: CGFloat = 8
    private static let guideSpacing: CGFloat = 4
    private static let minimumGuideWidth: CGFloat = 180
    private static let maximumGuideWidth: CGFloat = 300

    private let panel: NSPanel
    private let guidePanel: NSPanel
    private let collectionView: NSCollectionView
    private let layout: NSCollectionViewFlowLayout
    private let scrollView: NSScrollView
    private let guideLabel: NSTextView
    private var candidates: [String] = []
    private var alternateCommitIndicators: [Bool] = []
    private var itemSizes: [NSSize] = []

    override init() {
        collectionView = NSCollectionView()
        layout = NSCollectionViewFlowLayout()
        scrollView = NSScrollView()
        guideLabel = NSTextView(frame: .zero)
        panel = PassiveInputPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        guidePanel = PassiveInputPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 24),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        super.init()

        panel.applyInputPanelStyle()
        guidePanel.applyInputPanelStyle()
        panel.becomesKeyOnlyIfNeeded = true
        guidePanel.becomesKeyOnlyIfNeeded = true
        layout.minimumInteritemSpacing = CandidatePanelItemStyle.spacing
        layout.minimumLineSpacing = CandidatePanelItemStyle.spacing
        layout.scrollDirection = .vertical
        collectionView.collectionViewLayout = layout
        collectionView.dataSource = self
        collectionView.delegate = self
        collectionView.isSelectable = true
        collectionView.allowsEmptySelection = true
        collectionView.backgroundColors = [.clear]
        collectionView.register(
            CandidateCollectionItem.self,
            forItemWithIdentifier: Self.itemIdentifier
        )

        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = false
        scrollView.hasHorizontalScroller = false
        scrollView.verticalScroller = nil
        scrollView.horizontalScroller = nil
        scrollView.drawsBackground = false

        guideLabel.font = PanelShortcutGuideStyle.font
        guideLabel.textColor = PanelShortcutGuideStyle.color
        guideLabel.isEditable = false
        guideLabel.isSelectable = false
        guideLabel.drawsBackground = false
        guideLabel.textContainerInset = .zero
        guideLabel.textContainer?.lineFragmentPadding = 0
        guideLabel.textContainer?.widthTracksTextView = true
        guideLabel.isHorizontallyResizable = false
        guideLabel.isVerticallyResizable = true
        guideLabel.isHidden = true

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.addSubview(scrollView)
        panel.contentView = contentView

        let guideContentView = NSView()
        guideContentView.addSubview(guideLabel)
        guidePanel.contentView = guideContentView
    }

    var frame: NSRect {
        panel.frame
    }

    var isVisible: Bool {
        panel.isVisible
    }

    var auxiliaryFrames: [NSRect] {
        guidePanel.isVisible ? [guidePanel.frame] : []
    }

    var visibleFrame: NSRect? {
        guard panel.isVisible else { return nil }
        return guidePanel.isVisible
            ? panel.frame.union(guidePanel.frame)
            : panel.frame
    }

    func rowFrame(at index: Int) -> NSRect? {
        guard candidates.indices.contains(index) else { return nil }
        collectionView.layoutSubtreeIfNeeded()
        guard let item = collectionView.item(
            at: IndexPath(item: index, section: 0)
        ) else { return nil }
        let windowFrame = item.view.convert(item.view.bounds, to: nil)
        return panel.convertToScreen(windowFrame)
    }

    /// 右隣のパネルが画面内へ収まるよう、候補パネル一式を左へ移動する
    func makeRoomOnRight(width: CGFloat, spacing: CGFloat) {
        guard panel.isVisible,
              let visibleFrame = screenContaining(panel.frame)?.visibleFrame else {
            return
        }
        let groupFrame = guidePanel.isVisible
            ? panel.frame.union(guidePanel.frame)
            : panel.frame
        let requestedShift = min(
            visibleFrame.maxX - width - spacing - panel.frame.maxX,
            0
        )
        let availableShift = visibleFrame.minX - groupFrame.minX
        let shift = max(requestedShift, availableShift)
        guard shift < 0 else { return }
        panel.setFrameOrigin(NSPoint(
            x: panel.frame.minX + shift,
            y: panel.frame.minY
        ))
        if guidePanel.isVisible {
            guidePanel.setFrameOrigin(NSPoint(
                x: guidePanel.frame.minX + shift,
                y: guidePanel.frame.minY
            ))
        }
    }

    func contains(screenPoint: NSPoint) -> Bool {
        (panel.isVisible && panel.frame.contains(screenPoint))
            || (guidePanel.isVisible && guidePanel.frame.contains(screenPoint))
    }

    func placeBeside(_ anchorFrame: NSRect, spacing: CGFloat = 8) {
        let visibleFrame = screenContaining(anchorFrame)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let origin = CandidateFilterPanelPlacement.origin(
            beside: CandidateFilterPanelRect(
                x: anchorFrame.minX,
                y: anchorFrame.minY,
                width: anchorFrame.width,
                height: anchorFrame.height
            ),
            panelWidth: panel.frame.width,
            panelHeight: panel.frame.height,
            visibleFrame: CandidateFilterPanelRect(
                x: visibleFrame.minX,
                y: visibleFrame.minY,
                width: visibleFrame.width,
                height: visibleFrame.height
            ),
            spacing: spacing
        )
        let panelOrigin = NSPoint(x: origin.x, y: origin.y)
        let deltaX = panelOrigin.x - panel.frame.minX
        let deltaY = panelOrigin.y - panel.frame.minY
        panel.setFrameOrigin(panelOrigin)
        if guidePanel.isVisible {
            guidePanel.setFrameOrigin(NSPoint(
                x: guidePanel.frame.minX + deltaX,
                y: guidePanel.frame.minY + deltaY
            ))
        }
    }

    func placeLeft(
        of anchorFrame: NSRect,
        spacing: CGFloat = 8
    ) {
        placeOutside(anchorFrame, onLeft: true, spacing: spacing)
    }

    func placeRight(
        of anchorFrame: NSRect,
        spacing: CGFloat = 8
    ) {
        placeOutside(anchorFrame, onLeft: false, spacing: spacing)
    }

    private func placeOutside(
        _ anchorFrame: NSRect,
        onLeft: Bool,
        spacing: CGFloat
    ) {
        let visibleFrame = screenContaining(anchorFrame)?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)
        let x = onLeft
            ? anchorFrame.minX - spacing - panel.frame.width
            : anchorFrame.maxX + spacing
        let y = min(
            max(anchorFrame.maxY - panel.frame.height, visibleFrame.minY),
            visibleFrame.maxY - panel.frame.height
        )
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        guidePanel.orderOut(nil)
    }

    func offsetHorizontally(by offset: CGFloat) {
        guard offset != 0 else { return }
        panel.setFrameOrigin(NSPoint(
            x: panel.frame.minX + offset,
            y: panel.frame.minY
        ))
        if guidePanel.isVisible {
            guidePanel.setFrameOrigin(NSPoint(
                x: guidePanel.frame.minX + offset,
                y: guidePanel.frame.minY
            ))
        }
    }

    func show(
        candidates: [String],
        alternateCommitIndicators: [Bool] = [],
        selectedIndex: Int?,
        near anchorFrame: NSRect,
        guide: String? = nil,
        isAccented: Bool = false,
        reservedRightWidth: CGFloat = 0,
        reservesEmptyRow: Bool = false,
        minimumPanelText: String? = nil
    ) {
        panel.contentView?.layer?.borderWidth = isAccented ? 2 : 0
        panel.contentView?.layer?.borderColor = isAccented
            ? NSColor.controlAccentColor.cgColor
            : NSColor.clear.cgColor
        self.candidates = candidates
        self.alternateCommitIndicators = candidates.indices.map {
            alternateCommitIndicators.indices.contains($0)
                ? alternateCommitIndicators[$0]
                : false
        }
        let measuredItemSizes = candidates.indices.map {
            itemSize(
                for: candidates[$0],
                showsAlternateCommitIndicator: self.alternateCommitIndicators[$0]
            )
        }

        let screen = NSScreen.inputScreen(containing: anchorFrame)
        let visibleFrame = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        let guideText = guide?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasGuide = PanelShortcutGuideStyle.isEnabled && !guideText.isEmpty
        let guideParagraphStyle = NSMutableParagraphStyle()
        guideParagraphStyle.lineBreakMode = .byCharWrapping
        guideLabel.textStorage?.setAttributedString(NSAttributedString(
            string: guideText,
            attributes: [
                .font: PanelShortcutGuideStyle.font,
                .foregroundColor: PanelShortcutGuideStyle.color,
                .paragraphStyle: guideParagraphStyle
            ]
        ))
        guideLabel.isHidden = !hasGuide
        let maximumPanelWidth = min(
            CandidatePanelItemStyle.maximumPanelWidth,
            visibleFrame.width
        )
        let measuredGuideWidth = hasGuide
            ? guideText
                .components(separatedBy: .newlines)
                .map {
                    ceil(($0 as NSString).size(
                        withAttributes: [.font: PanelShortcutGuideStyle.font]
                    ).width)
                }
                .max() ?? 0
            : 0
        let guideWidth = hasGuide
            ? min(
                max(
                    measuredGuideWidth
                        + PanelShortcutGuideStyle.horizontalPadding * 2,
                    Self.minimumGuideWidth
                ),
                min(Self.maximumGuideWidth, maximumPanelWidth)
            )
            : 0
        let panelWidth = min(
            max(
                measuredItemSizes.map(\.width).max()
                    ?? CandidatePanelItemStyle.minimumWidth,
                minimumPanelText.map {
                    itemSize(
                        for: $0,
                        showsAlternateCommitIndicator: false
                    ).width
                }
                    ?? CandidatePanelItemStyle.minimumWidth
            ),
            maximumPanelWidth
        )
        itemSizes = candidates.map { _ in
            NSSize(width: panelWidth, height: Self.itemHeight)
        }
        let visibleItemCount = candidates.isEmpty && reservesEmptyRow
            ? 1
            : min(candidates.count, Self.maximumRows)
        let panelHeight = CGFloat(visibleItemCount) * Self.itemHeight
            + CGFloat(max(visibleItemCount - 1, 0))
                * CandidatePanelItemStyle.spacing
        let reservedPanelHeight = CGFloat(Self.maximumRows) * Self.itemHeight
            + CGFloat(Self.maximumRows - 1) * CandidatePanelItemStyle.spacing
        let guideContentWidth = max(
            guideWidth - PanelShortcutGuideStyle.horizontalPadding * 2,
            1
        )
        guideLabel.frame = NSRect(
            x: 0,
            y: 0,
            width: guideContentWidth,
            height: 10_000
        )
        guideLabel.textContainer?.containerSize = NSSize(
            width: guideContentWidth,
            height: CGFloat.greatestFiniteMagnitude
        )
        let guideTextHeight: CGFloat
        if hasGuide,
           let textContainer = guideLabel.textContainer,
           let layoutManager = guideLabel.layoutManager {
            layoutManager.ensureLayout(for: textContainer)
            guideTextHeight = ceil(
                layoutManager.usedRect(for: textContainer).height
            ) + 2
        } else {
            guideTextHeight = 0
        }
        let guideHeight = hasGuide
            ? guideTextHeight + PanelShortcutGuideStyle.verticalPadding * 2
            : 0
        let panelSize = NSSize(
            width: panelWidth,
            height: panelHeight
        )
        scrollView.frame = NSRect(
            x: 0,
            y: 0,
            width: panelWidth,
            height: panelHeight
        )
        let guideSize = NSSize(width: guideWidth, height: guideHeight)
        guideLabel.frame = NSRect(
            x: PanelShortcutGuideStyle.horizontalPadding,
            y: PanelShortcutGuideStyle.verticalPadding,
            width: max(
                guideWidth - PanelShortcutGuideStyle.horizontalPadding * 2,
                0
            ),
            height: max(
                guideHeight - PanelShortcutGuideStyle.verticalPadding * 2,
                0
            )
        )
        panel.contentView?.wantsLayer = isAccented
        panel.contentView?.layer?.borderWidth = isAccented
            ? 2
            : 0
        panel.contentView?.layer?.borderColor = isAccented
            ? NSColor.controlAccentColor.cgColor
            : NSColor.clear.cgColor
        positionPanels(
            near: anchorFrame,
            visibleFrame: visibleFrame,
            hasGuide: hasGuide,
            panelSize: panelSize,
            guideSize: guideSize,
            reservedPanelHeight: reservedPanelHeight,
            reservedRightWidth: reservedRightWidth
        )

        collectionView.reloadData()
        if let selectedIndex {
            select(index: selectedIndex)
        } else {
            clearSelection()
        }
        panel.orderFrontRegardless()
        if hasGuide {
            guidePanel.orderFrontRegardless()
        } else {
            guidePanel.orderOut(nil)
        }
    }

    func select(index: Int) {
        guard candidates.indices.contains(index) else {
            return
        }

        let indexPath = IndexPath(item: index, section: 0)
        collectionView.selectionIndexPaths = [indexPath]
        collectionView.scrollToItems(
            at: [indexPath],
            scrollPosition: [.nearestHorizontalEdge, .nearestVerticalEdge]
        )
    }

    func adjacentIndex(
        from index: Int,
        direction: CandidateNavigationDirection
    ) -> Int? {
        guard candidates.indices.contains(index) else {
            return nil
        }

        collectionView.layoutSubtreeIfNeeded()
        let currentPath = IndexPath(item: index, section: 0)
        guard let currentFrame = layout.layoutAttributesForItem(
            at: currentPath
        )?.frame else {
            return nil
        }

        let currentCenter = NSPoint(
            x: currentFrame.midX,
            y: currentFrame.midY
        )
        let rowTolerance = Self.itemHeight / 2
        var best: (index: Int, primary: CGFloat, secondary: CGFloat)?

        for candidateIndex in candidates.indices where candidateIndex != index {
            let path = IndexPath(item: candidateIndex, section: 0)
            guard let frame = layout.layoutAttributesForItem(at: path)?.frame else {
                continue
            }

            let deltaX = frame.midX - currentCenter.x
            let deltaY = frame.midY - currentCenter.y
            let isFlipped = collectionView.isFlipped
            let score: (CGFloat, CGFloat)?

            switch direction {
            case .left where deltaX < 0 && abs(deltaY) < rowTolerance:
                score = (abs(deltaX), abs(deltaY))
            case .right where deltaX > 0 && abs(deltaY) < rowTolerance:
                score = (abs(deltaX), abs(deltaY))
            case .up where (isFlipped ? deltaY < 0 : deltaY > 0):
                score = (abs(deltaY), abs(deltaX))
            case .down where (isFlipped ? deltaY > 0 : deltaY < 0):
                score = (abs(deltaY), abs(deltaX))
            default:
                score = nil
            }

            guard let score else {
                continue
            }
            if best == nil
                || score.0 < best!.primary
                || (score.0 == best!.primary && score.1 < best!.secondary) {
                best = (candidateIndex, score.0, score.1)
            }
        }

        return best?.index
    }

    func clearSelection() {
        collectionView.selectionIndexPaths = []
    }

    func hide() {
        panel.orderOut(nil)
        guidePanel.orderOut(nil)
    }

    private func itemSize(
        for candidate: String,
        showsAlternateCommitIndicator: Bool
    ) -> NSSize {
        let textWidth = ceil(
                (candidate as NSString).size(
                withAttributes: [.font: CandidatePanelItemStyle.font]
            ).width
        )
        let accessoryWidth = showsAlternateCommitIndicator
            ? ceil(("●" as NSString).size(
                withAttributes: [.font: CandidatePanelItemStyle.accessoryFont]
            ).width) + CandidatePanelItemStyle.accessorySpacing
            : 0
        return NSSize(
            width: min(
                max(
                    textWidth + accessoryWidth
                        + CandidatePanelItemStyle.horizontalPadding * 2,
                    CandidatePanelItemStyle.minimumWidth
                ),
                CandidatePanelItemStyle.maximumWidth
            ),
            height: Self.itemHeight
        )
    }

    private func positionPanels(
        near anchorFrame: NSRect,
        visibleFrame: NSRect,
        hasGuide: Bool,
        panelSize: NSSize,
        guideSize: NSSize,
        reservedPanelHeight: CGFloat,
        reservedRightWidth: CGFloat
    ) {
        let guideExtent = hasGuide
            ? Self.guideSpacing + guideSize.height
            : 0
        let groupHeight = panelSize.height + guideExtent
        let reservedGroupHeight = reservedPanelHeight + guideExtent
        let fitsBelow = anchorFrame.minY - Self.anchorSpacing
            - reservedGroupHeight
            >= visibleFrame.minY
        let panelY = fitsBelow
            ? anchorFrame.minY - Self.anchorSpacing - panelSize.height
            : anchorFrame.maxY + Self.anchorSpacing
        let maximumPanelX = max(
            visibleFrame.minX,
            visibleFrame.maxX - panelSize.width - max(reservedRightWidth, 0)
        )
        let panelX = min(
            max(anchorFrame.minX, visibleFrame.minX),
            maximumPanelX
        )
        let panelOrigin = NSPoint(
            x: panelX,
            y: min(max(panelY, visibleFrame.minY), visibleFrame.maxY - groupHeight)
        )
        panel.setFrame(
            NSRect(origin: panelOrigin, size: panelSize),
            display: panel.isVisible
        )
        guard hasGuide else { return }
        let guideX = min(
            max(panelOrigin.x, visibleFrame.minX),
            visibleFrame.maxX - guideSize.width
        )
        let guideY = fitsBelow
            ? panelOrigin.y - Self.guideSpacing - guideSize.height
            : panelOrigin.y + panelSize.height + Self.guideSpacing
        guidePanel.setFrame(
            NSRect(
                origin: NSPoint(x: guideX, y: guideY),
                size: guideSize
            ),
            display: guidePanel.isVisible
        )
    }

    private func screenContaining(_ frame: NSRect) -> NSScreen? {
        NSScreen.inputScreen(containing: frame)
    }
}

extension CandidateWindowController: NSCollectionViewDataSource {
    func collectionView(
        _ collectionView: NSCollectionView,
        numberOfItemsInSection section: Int
    ) -> Int {
        candidates.count
    }

    func collectionView(
        _ collectionView: NSCollectionView,
        itemForRepresentedObjectAt indexPath: IndexPath
    ) -> NSCollectionViewItem {
        let item = collectionView.makeItem(
            withIdentifier: Self.itemIdentifier,
            for: indexPath
        )
        guard let candidateItem = item as? CandidateCollectionItem else {
            return item
        }

        candidateItem.configure(
            text: candidates[indexPath.item],
            showsAlternateCommitIndicator:
                alternateCommitIndicators[indexPath.item]
        )
        return candidateItem
    }
}

extension CandidateWindowController: NSCollectionViewDelegateFlowLayout {
    func collectionView(
        _ collectionView: NSCollectionView,
        layout collectionViewLayout: NSCollectionViewLayout,
        sizeForItemAt indexPath: IndexPath
    ) -> NSSize {
        guard itemSizes.indices.contains(indexPath.item) else {
            return NSSize(
                width: CandidatePanelItemStyle.minimumWidth,
                height: Self.itemHeight
            )
        }

        return itemSizes[indexPath.item]
    }
}
