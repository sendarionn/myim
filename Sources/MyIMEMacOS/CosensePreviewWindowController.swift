@preconcurrency import AppKit
@preconcurrency import WebKit

final class CosensePreviewWindowController {
    private let panel: NSPanel
    private let webView: WKWebView
    private let definitionTextView: NSTextView
    private var displayedURL: URL?

    init() {
        webView = WKWebView(frame: .zero)
        definitionTextView = NSTextView(frame: .zero)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 560),
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        let definitionTitle = NSTextField(labelWithString: "macOS辞書")
        definitionTitle.font = .systemFont(
            ofSize: NSFont.smallSystemFontSize,
            weight: .semibold
        )
        definitionTitle.translatesAutoresizingMaskIntoConstraints = false

        definitionTextView.isEditable = false
        definitionTextView.isSelectable = true
        definitionTextView.drawsBackground = false
        definitionTextView.font = .systemFont(ofSize: 13)
        definitionTextView.textContainerInset = NSSize(width: 8, height: 7)

        let definitionScrollView = NSScrollView()
        definitionScrollView.documentView = definitionTextView
        definitionScrollView.hasVerticalScroller = true
        definitionScrollView.autohidesScrollers = true
        definitionScrollView.drawsBackground = false
        definitionScrollView.translatesAutoresizingMaskIntoConstraints = false

        let container = NSView()
        definitionTitle.translatesAutoresizingMaskIntoConstraints = false
        definitionScrollView.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        container.addSubview(definitionTitle)
        container.addSubview(definitionScrollView)
        container.addSubview(webView)
        NSLayoutConstraint.activate([
            definitionTitle.topAnchor.constraint(
                equalTo: container.topAnchor,
                constant: 6
            ),
            definitionTitle.leadingAnchor.constraint(
                equalTo: container.leadingAnchor,
                constant: 8
            ),
            definitionTitle.trailingAnchor.constraint(
                lessThanOrEqualTo: container.trailingAnchor,
                constant: -8
            ),
            definitionScrollView.topAnchor.constraint(
                equalTo: definitionTitle.bottomAnchor,
                constant: 3
            ),
            definitionScrollView.leadingAnchor.constraint(
                equalTo: container.leadingAnchor
            ),
            definitionScrollView.trailingAnchor.constraint(
                equalTo: container.trailingAnchor
            ),
            definitionScrollView.heightAnchor.constraint(equalToConstant: 160),
            webView.topAnchor.constraint(
                equalTo: definitionScrollView.bottomAnchor
            ),
            webView.leadingAnchor.constraint(equalTo: container.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: container.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: container.bottomAnchor)
        ])

        panel.title = "辞書・Cosense"
        panel.contentView = container
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
    }

    func show(
        url: URL,
        definitions: [SystemDictionaryDefinition],
        beside candidateFrame: NSRect
    ) {
        if displayedURL != url {
            webView.load(URLRequest(url: url))
            displayedURL = url
        }
        definitionTextView.textStorage?.setAttributedString(
            attributedDefinitions(definitions)
        )
        definitionTextView.scrollToBeginningOfDocument(nil)

        let screen = NSScreen.screens.first {
            $0.frame.intersects(candidateFrame)
        } ?? NSScreen.main
        let visibleFrame = screen?.visibleFrame ?? candidateFrame
        let panelSize = panel.frame.size
        let spacing: CGFloat = 8

        let rightOriginX = candidateFrame.maxX + spacing
        let leftOriginX = candidateFrame.minX - panelSize.width - spacing
        let preferredX = rightOriginX + panelSize.width <= visibleFrame.maxX
            ? rightOriginX
            : leftOriginX
        let x = min(
            max(preferredX, visibleFrame.minX),
            visibleFrame.maxX - panelSize.width
        )

        let preferredY = candidateFrame.maxY - panelSize.height
        let y = min(
            max(preferredY, visibleFrame.minY),
            visibleFrame.maxY - panelSize.height
        )
        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
    }

    private func attributedDefinitions(
        _ definitions: [SystemDictionaryDefinition]
    ) -> NSAttributedString {
        guard !definitions.isEmpty else {
            return NSAttributedString(
                string: "指定した辞書に語義が見つかりません",
                attributes: [
                    .font: NSFont.systemFont(ofSize: 13),
                    .foregroundColor: NSColor.secondaryLabelColor
                ]
            )
        }

        let result = NSMutableAttributedString()
        for (index, definition) in definitions.enumerated() {
            if index > 0 {
                result.append(
                    NSAttributedString(
                        string: "\n\n",
                        attributes: [.font: NSFont.systemFont(ofSize: 13)]
                    )
                )
            }

            result.append(
                NSAttributedString(
                    string: definition.dictionaryName + "\n",
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
                        .foregroundColor: NSColor.labelColor
                    ]
                )
            )
            result.append(
                NSAttributedString(
                    string: definition.text,
                    attributes: [
                        .font: NSFont.systemFont(ofSize: 13),
                        .foregroundColor: NSColor.textColor
                    ]
                )
            )
        }
        return result
    }

    func hide() {
        panel.orderOut(nil)
    }
}
