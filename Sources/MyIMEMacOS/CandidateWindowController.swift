@preconcurrency import AppKit

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
    private static let itemWidth: CGFloat = 140
    private static let itemHeight: CGFloat = 30
    private static let maximumColumns = 4
    private static let maximumRows = 6

    private let panel: NSPanel
    private let collectionView: NSCollectionView
    private let layout: NSCollectionViewFlowLayout
    private var candidates: [String] = []

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

        layout.minimumInteritemSpacing = 0
        layout.minimumLineSpacing = 0
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

        let screen = NSScreen.screens.first {
            $0.frame.intersects(anchorFrame)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame
            ?? NSRect(x: 0, y: 0, width: 800, height: 600)

        let columns = columnCount(
            candidateCount: candidates.count,
            availableWidth: visibleFrame.width
        )
        let rows = max(
            1,
            Int(ceil(Double(candidates.count) / Double(columns)))
        )
        let visibleRows = min(rows, Self.maximumRows)
        let panelWidth = min(
            CGFloat(columns) * Self.itemWidth,
            visibleFrame.width
        )
        let panelHeight = min(
            CGFloat(visibleRows) * Self.itemHeight,
            visibleFrame.height
        )
        layout.itemSize = NSSize(
            width: floor(panelWidth / CGFloat(columns)),
            height: Self.itemHeight
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

    func clearSelection() {
        collectionView.selectionIndexPaths = []
    }

    func hide() {
        panel.orderOut(nil)
    }

    private func columnCount(
        candidateCount: Int,
        availableWidth: CGFloat
    ) -> Int {
        let columnsForCandidates = max(
            1,
            Int(ceil(Double(candidateCount) / Double(Self.maximumRows)))
        )
        let columnsForScreen = max(
            1,
            Int(floor(availableWidth / Self.itemWidth))
        )
        return min(
            Self.maximumColumns,
            columnsForCandidates,
            columnsForScreen
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

        let belowY = anchorFrame.minY - panelSize.height
        let aboveY = anchorFrame.maxY
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

extension CandidateWindowController: NSCollectionViewDelegate {}
