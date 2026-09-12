@preconcurrency import AppKit

enum CandidateNavigationDirection {
    case left
    case right
    case up
    case down
}

enum PanelShortcutGuideStyle {
    static let font = NSFont.systemFont(ofSize: 11)
    static let color = NSColor.secondaryLabelColor
}

private final class CandidateCollectionItem: NSCollectionViewItem {
    private let label = NSTextField(labelWithString: "")

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 0

        label.translatesAutoresizingMaskIntoConstraints = false
        label.lineBreakMode = .byTruncatingTail
        container.addSubview(label)
        NSLayoutConstraint.activate([
            label.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 9),
            label.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -9),
            label.centerYAnchor.constraint(equalTo: container.centerYAnchor)
        ])
        view = container
        updateSelectionAppearance()
    }

    override var isSelected: Bool {
        didSet {
            updateSelectionAppearance()
        }
    }

    func configure(text: String) {
        label.stringValue = text
    }

    private func updateSelectionAppearance() {
        guard isViewLoaded else {
            return
        }

        view.layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.cgColor
            : NSColor.clear.cgColor
        label.textColor = isSelected ? .alternateSelectedControlTextColor : .labelColor
    }
}

final class CandidateWindowController: NSObject {
    private static let itemIdentifier = NSUserInterfaceItemIdentifier(
        "candidateItem"
    )
    private static let itemHeight: CGFloat = 30
    private static let minimumItemWidth: CGFloat = 52
    private static let maximumItemWidth: CGFloat = 240
    private static let maximumPanelWidth: CGFloat = 360
    private static let maximumRows = 4
    private static let itemSpacing: CGFloat = 2
    private static let anchorSpacing: CGFloat = 8
    private static let guideSpacing: CGFloat = 4
    private static let guideHorizontalPadding: CGFloat = 10
    private static let guideVerticalPadding: CGFloat = 4
    private static let minimumGuideWidth: CGFloat = 180
    private static let maximumGuideWidth: CGFloat = 300
    private static let modeHeaderHeight: CGFloat = 28

    private let panel: NSPanel
    private let guidePanel: NSPanel
    private let collectionView: NSCollectionView
    private let layout: NSCollectionViewFlowLayout
    private let scrollView: NSScrollView
    private let guideLabel: NSTextView
    private let modeLabel: NSTextField
    private let modeSeparator: NSBox
    private var candidates: [String] = []
    private var itemSizes: [NSSize] = []

    override init() {
        collectionView = NSCollectionView()
        layout = NSCollectionViewFlowLayout()
        scrollView = NSScrollView()
        guideLabel = NSTextView(frame: .zero)
        modeLabel = NSTextField(labelWithString: "")
        modeSeparator = NSBox()
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 40),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        guidePanel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 180, height: 24),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        super.init()

        layout.minimumInteritemSpacing = Self.itemSpacing
        layout.minimumLineSpacing = Self.itemSpacing
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
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
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

        modeLabel.font = NSFont.systemFont(ofSize: 12, weight: .semibold)
        modeLabel.textColor = .controlAccentColor
        modeLabel.lineBreakMode = .byTruncatingTail
        modeLabel.isHidden = true

        modeSeparator.boxType = .separator
        modeSeparator.isHidden = true

        let contentView = NSView()
        contentView.wantsLayer = true
        contentView.addSubview(scrollView)
        contentView.addSubview(modeLabel)
        contentView.addSubview(modeSeparator)
        panel.contentView = contentView
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.isOpaque = true
        panel.isReleasedWhenClosed = false

        let guideContentView = NSView()
        guideContentView.addSubview(guideLabel)
        guidePanel.contentView = guideContentView
        guidePanel.backgroundColor = .windowBackgroundColor
        guidePanel.hasShadow = true
        guidePanel.hidesOnDeactivate = false
        guidePanel.level = .popUpMenu
        guidePanel.isOpaque = true
        guidePanel.isReleasedWhenClosed = false
    }

    var frame: NSRect {
        panel.frame
    }

    var visibleFrame: NSRect? {
        guard panel.isVisible else { return nil }
        return guidePanel.isVisible
            ? panel.frame.union(guidePanel.frame)
            : panel.frame
    }

    func contains(screenPoint: NSPoint) -> Bool {
        (panel.isVisible && panel.frame.contains(screenPoint))
            || (guidePanel.isVisible && guidePanel.frame.contains(screenPoint))
    }

    func show(
        candidates: [String],
        selectedIndex: Int?,
        near anchorFrame: NSRect,
        guide: String? = nil,
        modeTitle: String? = nil,
        isAccented: Bool = false
    ) {
        panel.contentView?.layer?.borderWidth = isAccented ? 2 : 0
        panel.contentView?.layer?.borderColor = isAccented
            ? NSColor.controlAccentColor.cgColor
            : NSColor.clear.cgColor
        self.candidates = candidates
        let measuredItemSizes = candidates.map { itemSize(for: $0) }

        let screen = NSScreen.screens.first {
            $0.frame.intersects(anchorFrame)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        let guideText = guide?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasGuide = !guideText.isEmpty
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
        let modeText = modeTitle?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let hasModeHeader = !modeText.isEmpty
        modeLabel.stringValue = modeText
        modeLabel.isHidden = !hasModeHeader
        modeSeparator.isHidden = !hasModeHeader
        let maximumPanelWidth = min(
            Self.maximumPanelWidth,
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
                        + Self.guideHorizontalPadding * 2,
                    Self.minimumGuideWidth
                ),
                min(Self.maximumGuideWidth, maximumPanelWidth)
            )
            : 0
        let panelWidth = min(
            max(
                measuredItemSizes.map(\.width).max()
                    ?? Self.minimumItemWidth,
                hasModeHeader
                    ? ceil(modeLabel.attributedStringValue.size().width) + 20
                    : 0
            ),
            maximumPanelWidth
        )
        itemSizes = candidates.map { _ in
            NSSize(width: panelWidth, height: Self.itemHeight)
        }
        let visibleItemCount = min(candidates.count, Self.maximumRows)
        let panelHeight = CGFloat(visibleItemCount) * Self.itemHeight
            + CGFloat(max(visibleItemCount - 1, 0)) * Self.itemSpacing
        let guideContentWidth = max(guideWidth - Self.guideHorizontalPadding * 2, 1)
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
            ? guideTextHeight + Self.guideVerticalPadding * 2
            : 0
        let modeHeaderHeight = hasModeHeader ? Self.modeHeaderHeight : 0

        panel.setContentSize(NSSize(
            width: panelWidth,
            height: panelHeight + modeHeaderHeight
        ))
        scrollView.frame = NSRect(
            x: 0,
            y: 0,
            width: panelWidth,
            height: panelHeight
        )
        guidePanel.setContentSize(NSSize(width: guideWidth, height: guideHeight))
        guideLabel.frame = NSRect(
            x: Self.guideHorizontalPadding,
            y: Self.guideVerticalPadding,
            width: max(guideWidth - Self.guideHorizontalPadding * 2, 0),
            height: max(guideHeight - Self.guideVerticalPadding * 2, 0)
        )
        modeSeparator.frame = NSRect(
            x: 0,
            y: panelHeight,
            width: panelWidth,
            height: 1
        )
        modeLabel.frame = NSRect(
            x: 10,
            y: panelHeight + 1,
            width: max(panelWidth - 20, 0),
            height: max(modeHeaderHeight - 1, 0)
        )
        panel.contentView?.wantsLayer = isAccented || hasModeHeader
        panel.contentView?.layer?.borderWidth = isAccented
            ? 2
            : (hasModeHeader ? 1 : 0)
        panel.contentView?.layer?.borderColor = isAccented
            ? NSColor.controlAccentColor.cgColor
            : (hasModeHeader
                ? NSColor.controlAccentColor.withAlphaComponent(0.75).cgColor
                : NSColor.clear.cgColor)
        positionPanels(
            near: anchorFrame,
            visibleFrame: visibleFrame,
            hasGuide: hasGuide
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

    private func itemSize(for candidate: String) -> NSSize {
        let textWidth = ceil(
            (candidate as NSString).size(
                withAttributes: [.font: NSFont.systemFont(ofSize: NSFont.systemFontSize)]
            ).width
        )
        return NSSize(
            width: min(
                max(textWidth + 20, Self.minimumItemWidth),
                Self.maximumItemWidth
            ),
            height: Self.itemHeight
        )
    }

    private func positionPanels(
        near anchorFrame: NSRect,
        visibleFrame: NSRect,
        hasGuide: Bool
    ) {
        let guideExtent = hasGuide
            ? Self.guideSpacing + guidePanel.frame.height
            : 0
        let groupHeight = panel.frame.height + guideExtent
        let fitsBelow = anchorFrame.minY - Self.anchorSpacing - groupHeight
            >= visibleFrame.minY
        let panelY = fitsBelow
            ? anchorFrame.minY - Self.anchorSpacing - panel.frame.height
            : anchorFrame.maxY + Self.anchorSpacing
        let panelX = min(
            max(anchorFrame.minX, visibleFrame.minX),
            visibleFrame.maxX - panel.frame.width
        )
        panel.setFrameOrigin(NSPoint(
            x: panelX,
            y: min(max(panelY, visibleFrame.minY), visibleFrame.maxY - groupHeight)
        ))
        guard hasGuide else { return }
        let guideX = min(
            max(panel.frame.minX, visibleFrame.minX),
            visibleFrame.maxX - guidePanel.frame.width
        )
        let guideY = fitsBelow
            ? panel.frame.minY - Self.guideSpacing - guidePanel.frame.height
            : panel.frame.maxY + Self.guideSpacing
        guidePanel.setFrameOrigin(NSPoint(x: guideX, y: guideY))
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

        candidateItem.configure(text: candidates[indexPath.item])
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
                width: Self.minimumItemWidth,
                height: Self.itemHeight
            )
        }

        return itemSizes[indexPath.item]
    }
}
