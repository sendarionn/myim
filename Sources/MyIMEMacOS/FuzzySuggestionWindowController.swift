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
    private static let guideSpacing: CGFloat = 4
    private static let itemHeight: CGFloat = 30
    private static let minimumItemWidth: CGFloat = 52
    private static let maximumItemWidth: CGFloat = 240
    private static let maximumPanelWidth: CGFloat = 360
    private static let itemSpacing: CGFloat = 2
    private static let maximumVisibleSuggestionCount = 4
    private static let guideHorizontalPadding: CGFloat = 10
    private static let guideVerticalPadding: CGFloat = 5
    private let panel: NSPanel
    private let guidePanel: NSPanel
    private let stackView: NSStackView
    private let guideLabel: NSTextField

    var visibleFrame: NSRect? {
        guard panel.isVisible else { return nil }
        return guidePanel.isVisible
            ? panel.frame.union(guidePanel.frame)
            : panel.frame
    }

    init() {
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 260, height: 80),
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
        stackView = NSStackView()
        guideLabel = NSTextField(labelWithString: "")
        stackView.wantsLayer = true
        stackView.layer?.cornerRadius = 0
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

        guideLabel.font = PanelShortcutGuideStyle.font
        guideLabel.textColor = PanelShortcutGuideStyle.color
        guideLabel.lineBreakMode = .byClipping
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
        let visibleSuggestions = Array(
            suggestions.prefix(Self.maximumVisibleSuggestionCount)
        )

        let title = NSTextField(labelWithString: "もしかして？")
        title.font = .systemFont(ofSize: 12, weight: .semibold)
        title.textColor = .secondaryLabelColor
        let guideText = selectedIndex == nil
            ? "⇧Tab 選択"
            : "矢印 移動　Return 確定　Esc 戻る"
        stackView.addArrangedSubview(title)
        guideLabel.stringValue = guideText

        let itemWidths = visibleSuggestions.map(itemWidth)
        let availableWidth = min(
            Self.maximumPanelWidth - stackView.edgeInsets.left
                - stackView.edgeInsets.right,
            visibleFrame.width
        )
        let targetWidth = min(
            max(
                packedTargetWidth(
                    itemWidths: itemWidths,
                    availableWidth: availableWidth
                ),
                ceil(title.attributedStringValue.size().width)
            ),
            availableWidth
        )
        for (index, suggestion) in visibleSuggestions.enumerated() {
            stackView.addArrangedSubview(suggestionView(
                suggestion,
                width: targetWidth,
                isSelected: index == selectedIndex
            ))
        }

        stackView.layoutSubtreeIfNeeded()
        let fittingSize = stackView.fittingSize
        panel.setContentSize(NSSize(
            width: min(fittingSize.width, Self.maximumPanelWidth),
            height: fittingSize.height
        ))

        let guideTextWidth = ceil((guideText as NSString).size(
            withAttributes: [.font: PanelShortcutGuideStyle.font]
        ).width)
        let guideTextHeight = ceil(guideLabel.attributedStringValue.size().height)
        let guideSize = NSSize(
            width: guideTextWidth + Self.guideHorizontalPadding * 2,
            height: guideTextHeight + Self.guideVerticalPadding * 2
        )
        guidePanel.setContentSize(guideSize)
        guideLabel.frame = NSRect(
            x: Self.guideHorizontalPadding,
            y: Self.guideVerticalPadding,
            width: guideTextWidth,
            height: guideTextHeight
        )

        positionPanels(near: anchorFrame, visibleFrame: visibleFrame)
        panel.orderFrontRegardless()
        guidePanel.orderFrontRegardless()
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
        return min(
            availableWidth,
            itemWidths.max() ?? Self.minimumItemWidth
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
        guidePanel.orderOut(nil)
    }

    private func positionPanels(near anchorFrame: NSRect, visibleFrame: NSRect) {
        let groupHeight = panel.frame.height
            + Self.guideSpacing
            + guidePanel.frame.height
        let fitsBelow = anchorFrame.minY - Self.spacing - groupHeight
            >= visibleFrame.minY
        let panelY = fitsBelow
            ? anchorFrame.minY - Self.spacing - panel.frame.height
            : anchorFrame.maxY + Self.spacing
        let panelX = min(
            max(anchorFrame.minX, visibleFrame.minX),
            visibleFrame.maxX - panel.frame.width
        )
        panel.setFrameOrigin(NSPoint(
            x: panelX,
            y: min(max(panelY, visibleFrame.minY), visibleFrame.maxY - groupHeight)
        ))
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
