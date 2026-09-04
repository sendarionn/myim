@preconcurrency import AppKit

struct FuzzySuggestion: Equatable {
    let candidate: String
    let reading: String
    let distance: Int

    init(
        candidate: String,
        reading: String,
        distance: Int
    ) {
        self.candidate = candidate
        self.reading = reading
        self.distance = distance
    }
}

final class FuzzySuggestionWindowController {
    private static let spacing: CGFloat = 6
    private static let itemHeight: CGFloat = 30
    private static let minimumItemWidth: CGFloat = 52
    private static let maximumItemWidth: CGFloat = 240
    private static let maximumPanelWidth: CGFloat = 560
    private static let minimumPanelWidth: CGFloat = 180
    private static let itemSpacing: CGFloat = 2
    private let panel: NSPanel
    private let stackView: NSStackView

    var visibleFrame: NSRect? {
        panel.isVisible ? panel.frame : nil
    }

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 80),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        stackView = NSStackView()
        stackView.wantsLayer = true
        stackView.orientation = .vertical
        stackView.alignment = .leading
        stackView.spacing = 3
        stackView.edgeInsets = NSEdgeInsets(
            top: 8,
            left: 8,
            bottom: 8,
            right: 8
        )
        panel.contentView = stackView
        panel.backgroundColor = .windowBackgroundColor
        panel.hasShadow = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.isOpaque = true
        panel.isReleasedWhenClosed = false
    }

    func show(
        suggestions: [FuzzySuggestion],
        selectedIndex: Int?,
        near anchorFrame: NSRect,
        isAccented: Bool = false
    ) {
        stackView.layer?.borderWidth = isAccented ? 2 : 0
        stackView.layer?.borderColor = isAccented
            ? NSColor.controlAccentColor.cgColor
            : NSColor.clear.cgColor
        let screen = NSScreen.screens.first {
            $0.frame.intersects(anchorFrame)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? anchorFrame
        stackView.arrangedSubviews.forEach {
            stackView.removeArrangedSubview($0)
            $0.removeFromSuperview()
        }

        let title = NSTextField(labelWithString: "もしかして？")
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabelColor
        let guideText = selectedIndex == nil
            ? "⇧Tab 選択"
            : "矢印 移動　Return 確定　Esc 戻る"
        let guide = NSTextField(labelWithString: guideText)
        guide.font = PanelShortcutGuideStyle.font
        guide.textColor = PanelShortcutGuideStyle.color
        guide.maximumNumberOfLines = 1
        guide.lineBreakMode = .byClipping
        guide.cell?.usesSingleLineMode = true
        guide.cell?.wraps = false
        guide.cell?.isScrollable = false
        guide.cell?.truncatesLastVisibleLine = false
        let header = NSStackView(views: [title, guide])
        header.orientation = .vertical
        header.alignment = .leading
        header.spacing = 2
        stackView.addArrangedSubview(header)

        let itemWidths = suggestions.map(itemWidth)
        let availableWidth = min(
            Self.maximumPanelWidth - stackView.edgeInsets.left
                - stackView.edgeInsets.right,
            visibleFrame.width
        )
        let targetWidth = min(
            max(
                max(
                    packedTargetWidth(
                        itemWidths: itemWidths,
                        availableWidth: availableWidth
                    ),
                    ceil((guideText as NSString).size(
                        withAttributes: [.font: PanelShortcutGuideStyle.font]
                    ).width)
                ),
                Self.minimumPanelWidth - stackView.edgeInsets.left
                    - stackView.edgeInsets.right
            ),
            availableWidth
        )
        var currentRow: NSStackView?
        var currentRowWidth: CGFloat = 0
        for (index, suggestion) in suggestions.enumerated() {
            let width = itemWidths[index]
            let nextWidth = currentRowWidth == 0
                ? width
                : currentRowWidth + Self.itemSpacing + width
            if currentRow == nil || nextWidth > targetWidth {
                let row = NSStackView()
                row.orientation = .horizontal
                row.alignment = .centerY
                row.spacing = Self.itemSpacing
                stackView.addArrangedSubview(row)
                currentRow = row
                currentRowWidth = 0
            }
            currentRow?.addArrangedSubview(suggestionView(
                suggestion,
                width: width,
                isSelected: index == selectedIndex
            ))
            currentRowWidth = currentRowWidth == 0
                ? width
                : currentRowWidth + Self.itemSpacing + width
        }

        stackView.layoutSubtreeIfNeeded()
        let fittingSize = stackView.fittingSize
        panel.setContentSize(NSSize(
            width: min(
                max(fittingSize.width, Self.minimumPanelWidth),
                Self.maximumPanelWidth
            ),
            height: fittingSize.height
        ))

        let belowY = anchorFrame.minY - panel.frame.height - Self.spacing
        let aboveY = anchorFrame.maxY + Self.spacing
        let y = belowY >= visibleFrame.minY ? belowY : aboveY
        let x = min(
            max(anchorFrame.minX, visibleFrame.minX),
            max(visibleFrame.minX, visibleFrame.maxX - panel.frame.width)
        )
        panel.setFrameOrigin(NSPoint(
            x: x,
            y: min(max(y, visibleFrame.minY), visibleFrame.maxY - panel.frame.height)
        ))
        panel.orderFrontRegardless()
    }

    private func itemWidth(for suggestion: FuzzySuggestion) -> CGFloat {
        let text = suggestion.candidate
        let textWidth = ceil((text as NSString).size(
            withAttributes: [.font: NSFont.systemFont(ofSize: 13)]
        ).width)
        return min(
            max(textWidth + 12, Self.minimumItemWidth),
            Self.maximumItemWidth
        )
    }

    private func packedTargetWidth(
        itemWidths: [CGFloat],
        availableWidth: CGFloat
    ) -> CGFloat {
        guard !itemWidths.isEmpty else { return Self.minimumItemWidth }
        let totalWidth = itemWidths.reduce(0, +)
            + CGFloat(max(itemWidths.count - 1, 0)) * Self.itemSpacing
        let balancedWidth = ceil(sqrt(
            totalWidth * (Self.itemHeight + Self.itemSpacing) * 2
        ))
        return min(
            availableWidth,
            max(itemWidths.max() ?? Self.minimumItemWidth, balancedWidth)
        )
    }

    private func suggestionView(
        _ suggestion: FuzzySuggestion,
        width: CGFloat,
        isSelected: Bool
    ) -> NSView {
        let item = NSView()
        item.wantsLayer = true
        item.layer?.cornerRadius = 0
        item.layer?.backgroundColor = isSelected
            ? NSColor.controlAccentColor.cgColor
            : NSColor.clear.cgColor
        let label = NSTextField(
            labelWithString: suggestion.candidate
        )
        label.font = .systemFont(ofSize: 13)
        label.lineBreakMode = .byTruncatingTail
        label.textColor = isSelected
            ? .alternateSelectedControlTextColor
            : .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        item.addSubview(label)
        NSLayoutConstraint.activate([
            item.widthAnchor.constraint(equalToConstant: width),
            item.heightAnchor.constraint(equalToConstant: Self.itemHeight),
            label.leadingAnchor.constraint(equalTo: item.leadingAnchor, constant: 6),
            label.trailingAnchor.constraint(equalTo: item.trailingAnchor, constant: -6),
            label.centerYAnchor.constraint(equalTo: item.centerYAnchor)
        ])
        return item
    }

    func hide() {
        panel.orderOut(nil)
    }
}
