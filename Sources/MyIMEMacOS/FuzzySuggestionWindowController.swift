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
    private static let itemHeight = CandidatePanelItemStyle.height
    private static let minimumItemWidth: CGFloat = 32
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
        stackView.spacing = Self.itemSpacing
        stackView.edgeInsets = NSEdgeInsets(
            top: 0,
            left: 0,
            bottom: 0,
            right: 0
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
        avoidingFrames: [NSRect] = [],
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

        let guideText = selectedIndex == nil
            ? "Tabで通常候補を選択後、左右矢印で移動"
            : "矢印 移動　Return 確定　Esc 戻る"
        let hasGuide = PanelShortcutGuideStyle.isEnabled
        guideLabel.stringValue = guideText

        let itemWidths = visibleSuggestions.map(itemWidth)
        let availableWidth = min(
            Self.maximumPanelWidth - stackView.edgeInsets.left
                - stackView.edgeInsets.right,
            visibleFrame.width
        )
        let targetWidth = min(
            packedTargetWidth(
                itemWidths: itemWidths,
                availableWidth: availableWidth
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

        if hasGuide {
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
        }

        positionPanels(
            near: anchorFrame,
            visibleFrame: visibleFrame,
            hasGuide: hasGuide,
            avoidingFrames: avoidingFrames
        )
        panel.orderFrontRegardless()
        if hasGuide {
            guidePanel.orderFrontRegardless()
        } else {
            guidePanel.orderOut(nil)
        }
    }

    private func itemWidth(for suggestion: FuzzySuggestion) -> CGFloat {
        let text = suggestion.candidate
        let textWidth = ceil((text as NSString).size(
            withAttributes: [.font: CandidatePanelItemStyle.font]
        ).width)
        return min(
            max(
                textWidth + CandidatePanelItemStyle.horizontalPadding * 2,
                Self.minimumItemWidth
            ),
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
        label.font = CandidatePanelItemStyle.font
        label.lineBreakMode = .byTruncatingTail
        label.textColor = isSelected
            ? .alternateSelectedControlTextColor
            : .labelColor
        label.translatesAutoresizingMaskIntoConstraints = false
        item.addSubview(label)
        NSLayoutConstraint.activate([
            item.widthAnchor.constraint(equalToConstant: width),
            item.heightAnchor.constraint(equalToConstant: Self.itemHeight),
            label.leadingAnchor.constraint(
                equalTo: item.leadingAnchor,
                constant: CandidatePanelItemStyle.horizontalPadding
            ),
            label.trailingAnchor.constraint(
                equalTo: item.trailingAnchor,
                constant: -CandidatePanelItemStyle.horizontalPadding
            ),
            label.centerYAnchor.constraint(equalTo: item.centerYAnchor)
        ])
        return item
    }

    func hide() {
        panel.orderOut(nil)
        guidePanel.orderOut(nil)
    }

    private func positionPanels(
        near anchorFrame: NSRect,
        visibleFrame: NSRect,
        hasGuide: Bool,
        avoidingFrames: [NSRect]
    ) {
        let rightX = anchorFrame.maxX + Self.spacing
        let leftX = anchorFrame.minX - Self.spacing - panel.frame.width
        let rightSpace = max(visibleFrame.maxX - rightX, 0)
        let leftSpace = max(anchorFrame.minX - Self.spacing - visibleFrame.minX, 0)
        let panelX: CGFloat
        if rightX + panel.frame.width <= visibleFrame.maxX {
            panelX = rightX
        } else if leftX >= visibleFrame.minX {
            panelX = leftX
        } else if rightSpace >= leftSpace {
            panel.setFrame(
                NSRect(
                    x: rightX,
                    y: panel.frame.minY,
                    width: rightSpace,
                    height: panel.frame.height
                ),
                display: false
            )
            panelX = rightX
        } else {
            panel.setFrame(
                NSRect(
                    x: visibleFrame.minX,
                    y: panel.frame.minY,
                    width: leftSpace,
                    height: panel.frame.height
                ),
                display: false
            )
            panelX = visibleFrame.minX
        }
        let panelY = min(
            max(anchorFrame.maxY - panel.frame.height, visibleFrame.minY),
            visibleFrame.maxY - panel.frame.height
        )
        panel.setFrameOrigin(NSPoint(
            x: panelX,
            y: panelY
        ))
        guard hasGuide else { return }
        let guideX = min(
            max(panel.frame.minX, visibleFrame.minX),
            visibleFrame.maxX - guidePanel.frame.width
        )
        var guideY = panel.frame.minY - Self.guideSpacing - guidePanel.frame.height
        var guideFrame = NSRect(
            x: guideX,
            y: guideY,
            width: guidePanel.frame.width,
            height: guidePanel.frame.height
        )
        for avoidedFrame in avoidingFrames where guideFrame.intersects(avoidedFrame) {
            guideY = avoidedFrame.minY - Self.guideSpacing - guidePanel.frame.height
            guideFrame.origin.y = guideY
        }
        if guideY < visibleFrame.minY {
            guideY = min(
                panel.frame.maxY + Self.guideSpacing,
                visibleFrame.maxY - guidePanel.frame.height
            )
        }
        guidePanel.setFrameOrigin(NSPoint(x: guideX, y: guideY))
    }
}
