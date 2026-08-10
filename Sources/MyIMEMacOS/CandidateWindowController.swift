@preconcurrency import AppKit

enum CandidateNavigationDirection {
    case left
    case right
    case up
    case down
}

private final class CandidateCollectionItem: NSCollectionViewItem {
    private let label = NSTextField(labelWithString: "")

    override func loadView() {
        let container = NSView()
        container.wantsLayer = true
        container.layer?.cornerRadius = 5

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
    private static let maximumPanelWidth: CGFloat = 560
    private static let maximumRows = 6
    private static let itemSpacing: CGFloat = 2
    private static let anchorSpacing: CGFloat = 8

    private let panel: NSPanel
    private let collectionView: NSCollectionView
    private let layout: NSCollectionViewFlowLayout
    private var candidates: [String] = []
    private var itemSizes: [NSSize] = []

    override init() {
        collectionView = NSCollectionView()
        layout = NSCollectionViewFlowLayout()
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 280, height: 40),
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

        let scrollView = NSScrollView()
        scrollView.documentView = collectionView
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false

        panel.contentView = scrollView
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.isOpaque = true
        panel.isReleasedWhenClosed = false
    }

    var frame: NSRect {
        panel.frame
    }

    func show(candidates: [String], selectedIndex: Int?, near anchorFrame: NSRect) {
        self.candidates = candidates
        itemSizes = candidates.map { itemSize(for: $0) }

        let screen = NSScreen.screens.first {
            $0.frame.intersects(anchorFrame)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        let contentSize = packedContentSize(
            itemSizes: itemSizes,
            availableWidth: min(
                Self.maximumPanelWidth,
                visibleFrame.width
            )
        )
        let panelWidth = contentSize.width
        let panelHeight = min(
            contentSize.height,
            CGFloat(Self.maximumRows) * (Self.itemHeight + Self.itemSpacing)
        )

        panel.setContentSize(NSSize(width: panelWidth, height: panelHeight))
        panel.setFrameOrigin(
            panelOrigin(
                panelSize: panel.frame.size,
                anchorFrame: anchorFrame,
                visibleFrame: visibleFrame
            )
        )

        collectionView.reloadData()
        if let selectedIndex {
            select(index: selectedIndex)
        } else {
            clearSelection()
        }
        panel.orderFrontRegardless()
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

    private func packedContentSize(
        itemSizes: [NSSize],
        availableWidth: CGFloat
    ) -> NSSize {
        guard !itemSizes.isEmpty else {
            return NSSize(width: Self.minimumItemWidth, height: Self.itemHeight)
        }

        let totalWidth = itemSizes.reduce(0) { $0 + $1.width }
            + CGFloat(max(itemSizes.count - 1, 0)) * Self.itemSpacing
        let widestItem = itemSizes.map(\.width).max() ?? Self.minimumItemWidth
        let balancedWidth = ceil(
            sqrt(
                totalWidth
                    * (Self.itemHeight + Self.itemSpacing)
                    * 2
            )
        )
        let targetWidth = min(
            availableWidth,
            max(widestItem, balancedWidth)
        )

        var rowWidth: CGFloat = 0
        var widestRow: CGFloat = 0
        var rowCount = 1

        for itemSize in itemSizes {
            let nextWidth = rowWidth == 0
                ? itemSize.width
                : rowWidth + Self.itemSpacing + itemSize.width

            if rowWidth > 0, nextWidth > targetWidth {
                widestRow = max(widestRow, rowWidth)
                rowCount += 1
                rowWidth = itemSize.width
            } else {
                rowWidth = nextWidth
            }
        }
        widestRow = max(widestRow, rowWidth)

        return NSSize(
            width: min(max(widestRow, widestItem), availableWidth),
            height: CGFloat(rowCount) * Self.itemHeight
                + CGFloat(max(rowCount - 1, 0)) * Self.itemSpacing
        )
    }

    private func panelOrigin(
        panelSize: NSSize,
        anchorFrame: NSRect,
        visibleFrame: NSRect
    ) -> NSPoint {
        let x = min(
            max(anchorFrame.minX, visibleFrame.minX),
            visibleFrame.maxX - panelSize.width
        )

        let belowY = anchorFrame.minY
            - Self.anchorSpacing
            - panelSize.height
        let aboveY = anchorFrame.maxY + Self.anchorSpacing
        let preferredY = belowY >= visibleFrame.minY ? belowY : aboveY
        let y = min(
            max(preferredY, visibleFrame.minY),
            visibleFrame.maxY - panelSize.height
        )
        return NSPoint(x: x, y: y)
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
