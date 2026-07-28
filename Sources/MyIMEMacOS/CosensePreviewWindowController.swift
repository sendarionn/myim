@preconcurrency import AppKit
@preconcurrency import WebKit
import MyIMECore

final class CosensePreviewWindowController {
    private static let spacing: CGFloat = 8

    private let definitionPanel: NSPanel
    private let cosensePanel: NSPanel
    private let webView: WKWebView
    private let definitionTextView: NSTextView
    private var displayedURL: URL?
    private var requestID = UUID()

    init() {
        definitionTextView = NSTextView(frame: .zero)
        webView = WKWebView(frame: .zero)
        definitionPanel = Self.makePanel(
            title: "macOS辞書",
            size: NSSize(width: 420, height: 220)
        )
        cosensePanel = Self.makePanel(
            title: "Cosense",
            size: NSSize(width: 420, height: 420)
        )

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
        definitionPanel.contentView = definitionScrollView
        cosensePanel.contentView = webView
    }

    func showIfPageExists(
        project: String,
        pageTitle: String,
        url: URL,
        definitions: [SystemDictionaryDefinition],
        beside candidateFrame: NSRect
    ) {
        let currentRequestID = UUID()
        requestID = currentRequestID
        cosensePanel.orderOut(nil)

        if definitions.isEmpty {
            definitionPanel.orderOut(nil)
        } else {
            definitionTextView.textStorage?.setAttributedString(
                attributedDefinitions(definitions)
            )
            definitionTextView.scrollToBeginningOfDocument(nil)
            positionDefinitionPanel(near: candidateFrame)
            definitionPanel.orderFrontRegardless()
        }

        Task { @MainActor [weak self] in
            let exists = await CosensePageClient().exists(
                project: project,
                pageTitle: pageTitle
            )
            guard
                let self,
                requestID == currentRequestID,
                exists
            else {
                return
            }

            if displayedURL != url {
                webView.load(URLRequest(url: url))
                displayedURL = url
            }
            positionCosensePanel(near: candidateFrame)
            cosensePanel.orderFrontRegardless()
        }
    }

    func hide() {
        requestID = UUID()
        definitionPanel.orderOut(nil)
        cosensePanel.orderOut(nil)
    }

    private static func makePanel(
        title: String,
        size: NSSize
    ) -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.title = title
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
        return panel
    }

    private func positionDefinitionPanel(near candidateFrame: NSRect) {
        let visibleFrame = visibleFrame(near: candidateFrame)
        let panelSize = definitionPanel.frame.size
        let aboveY = candidateFrame.maxY + Self.spacing
        let belowY = candidateFrame.minY - panelSize.height - Self.spacing
        let preferredY = aboveY + panelSize.height <= visibleFrame.maxY
            ? aboveY
            : belowY
        let x = clamped(
            candidateFrame.minX,
            minimum: visibleFrame.minX,
            maximum: visibleFrame.maxX - panelSize.width
        )
        let y = clamped(
            preferredY,
            minimum: visibleFrame.minY,
            maximum: visibleFrame.maxY - panelSize.height
        )
        definitionPanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionCosensePanel(near candidateFrame: NSRect) {
        let visibleFrame = visibleFrame(near: candidateFrame)
        let panelSize = cosensePanel.frame.size
        let rightX = candidateFrame.maxX + Self.spacing
        let leftX = candidateFrame.minX - panelSize.width - Self.spacing
        let preferredX = rightX + panelSize.width <= visibleFrame.maxX
            ? rightX
            : leftX
        let x = clamped(
            preferredX,
            minimum: visibleFrame.minX,
            maximum: visibleFrame.maxX - panelSize.width
        )
        let y = clamped(
            candidateFrame.maxY - panelSize.height,
            minimum: visibleFrame.minY,
            maximum: visibleFrame.maxY - panelSize.height
        )
        cosensePanel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func visibleFrame(near candidateFrame: NSRect) -> NSRect {
        let screen = NSScreen.screens.first {
            $0.frame.intersects(candidateFrame)
        } ?? NSScreen.main
        return screen?.visibleFrame ?? candidateFrame
    }

    private func clamped(
        _ value: CGFloat,
        minimum: CGFloat,
        maximum: CGFloat
    ) -> CGFloat {
        min(max(value, minimum), max(minimum, maximum))
    }

    private func attributedDefinitions(
        _ definitions: [SystemDictionaryDefinition]
    ) -> NSAttributedString {
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
                        .font: NSFont.systemFont(
                            ofSize: 13,
                            weight: .semibold
                        ),
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
}
