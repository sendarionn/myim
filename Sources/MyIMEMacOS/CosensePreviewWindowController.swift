@preconcurrency import AppKit
@preconcurrency import WebKit
import MyIMECore

final class ExternalInformationWindowController {
    private static let spacing: CGFloat = 8
    private static let informationPanelSize = NSSize(width: 420, height: 420)

    private let definitionPanel: NSPanel
    private let informationPanel: NSPanel
    private let webView: WKWebView
    private let definitionTextView: NSTextView
    private var displayedURL: URL?
    private var installedCookieSignature = ""
    private var requestID = UUID()
    private var displayTask: Task<Void, Never>?

    init() {
        definitionTextView = NSTextView(frame: .zero)
        let webConfiguration = WKWebViewConfiguration()
        webConfiguration.websiteDataStore = .default()
        webView = InteractiveInformationWebView(
            frame: .zero,
            configuration: webConfiguration
        )
        definitionPanel = Self.makePanel(
            title: "macOS辞書",
            size: NSSize(width: 420, height: 220),
            interactive: false
        )
        informationPanel = Self.makePanel(
            title: "外部情報",
            size: Self.informationPanelSize,
            interactive: true
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
        informationPanel.contentView = webView
    }

    func show(
        url: URL?,
        panelTitle: String,
        definitions: [SystemDictionaryDefinition],
        showExternalInformation: Bool,
        displayDelay: TimeInterval,
        beside candidateFrame: NSRect
    ) {
        displayTask?.cancel()
        let currentRequestID = UUID()
        requestID = currentRequestID
        informationPanel.orderOut(nil)

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

        guard showExternalInformation, let url else {
            return
        }

        let cookies = url.host == "scrapbox.io"
            ? CosenseWebCookieStore().load()
            : []
        let cookieSignature = cookies
            .map { "\($0.name)=\($0.value)" }
            .sorted()
            .joined(separator: ";")
        informationPanel.title = panelTitle
        if displayedURL != url
            || installedCookieSignature != cookieSignature {
            var request = URLRequest(url: url)
            for (field, value) in HTTPCookie.requestHeaderFields(
                with: cookies
            ) {
                request.setValue(value, forHTTPHeaderField: field)
            }
            webView.load(request)
            displayedURL = url
            installedCookieSignature = cookieSignature
        }
        if !cookies.isEmpty {
            Task { @MainActor [weak self] in
                await self?.installSharedCosenseCookies(cookies)
            }
        }

        displayTask = Task { @MainActor [weak self] in
            if displayDelay > 0 {
                try? await Task.sleep(
                    for: .milliseconds(Int(displayDelay * 1_000))
                )
            }
            guard !Task.isCancelled else {
                return
            }
            guard
                let self,
                requestID == currentRequestID
            else {
                return
            }

            positionInformationPanel(near: candidateFrame)
            informationPanel.orderFrontRegardless()
        }
    }

    @MainActor
    private func installSharedCosenseCookies(
        _ cookies: [HTTPCookie]
    ) async {
        let cookieStore = webView.configuration.websiteDataStore.httpCookieStore
        for cookie in cookies {
            await withCheckedContinuation { continuation in
                cookieStore.setCookie(cookie) {
                    continuation.resume()
                }
            }
        }
    }

    func hide() {
        displayTask?.cancel()
        displayTask = nil
        requestID = UUID()
        definitionPanel.orderOut(nil)
        informationPanel.orderOut(nil)
    }

    var isInteractionActive: Bool {
        informationPanel.isVisible
            && (
                informationPanel.isKeyWindow
                    || informationPanel.frame.contains(NSEvent.mouseLocation)
            )
    }

    private static func makePanel(
        title: String,
        size: NSSize,
        interactive: Bool
    ) -> NSPanel {
        let styleMask: NSWindow.StyleMask = interactive
            ? [.titled, .closable, .resizable]
            : [.titled, .nonactivatingPanel]
        let panel: NSPanel
        if interactive {
            panel = InteractiveInformationPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: styleMask,
                backing: .buffered,
                defer: true
            )
            panel.becomesKeyOnlyIfNeeded = false
        } else {
            panel = NSPanel(
                contentRect: NSRect(origin: .zero, size: size),
                styleMask: styleMask,
                backing: .buffered,
                defer: true
            )
        }
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

    private func positionInformationPanel(near candidateFrame: NSRect) {
        let visibleFrame = visibleFrame(near: candidateFrame)
        let panelHeight = min(Self.informationPanelSize.height, visibleFrame.height)
        let panelWidth = min(Self.informationPanelSize.width, visibleFrame.width)
        informationPanel.setContentSize(
            NSSize(width: panelWidth, height: panelHeight)
        )
        let panelSize = informationPanel.frame.size
        let occupiedFrame = definitionPanel.isVisible
            ? candidateFrame.union(definitionPanel.frame)
            : candidateFrame
        let rightX = occupiedFrame.maxX + Self.spacing
        let leftX = occupiedFrame.minX - panelSize.width - Self.spacing
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
        informationPanel.setFrameOrigin(NSPoint(x: x, y: y))
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

private final class InteractiveInformationPanel: NSPanel {
    override var canBecomeKey: Bool {
        true
    }

    override var canBecomeMain: Bool {
        false
    }
}

private final class InteractiveInformationWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }
}
