@preconcurrency import AppKit
@preconcurrency import WebKit
import MyIMECore

final class ExternalInformationWindowController: NSObject {
    private struct PendingPresentation {
        let url: URL?
        let panelTitle: String
        let definitions: [SystemDictionaryDefinition]
        let showExternalInformation: Bool
        let displayDelay: TimeInterval
        let candidateFrame: NSRect
    }

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
    private var navigationTask: Task<Void, Never>?
    private var cachedCosenseCookies: [HTTPCookie] = []
    private var cookiesLoadedAt = Date.distantPast
    private var pendingPresentation: PendingPresentation?
    private(set) var isInteractionActive = false
    var onInteractionBegan: (() -> Void)?
    var onInteractionEnded: (() -> Void)?
    private static let navigationDebounce: TimeInterval = 0.2
    private static let cookieCacheLifetime: TimeInterval = 5

    override init() {
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

        super.init()

        let openInBrowserButton = NSButton(
            title: "ブラウザで開く  ⌘O",
            target: self,
            action: #selector(openDisplayedPageInDefaultBrowser(_:))
        )
        openInBrowserButton.bezelStyle = .inline
        openInBrowserButton.font = PanelShortcutGuideStyle.font
        openInBrowserButton.contentTintColor = PanelShortcutGuideStyle.color
        openInBrowserButton.toolTip = "現在のページを既定ブラウザで開く（Command＋O）"
        let browserAccessory = NSTitlebarAccessoryViewController()
        browserAccessory.layoutAttribute = .right
        browserAccessory.view = openInBrowserButton
        informationPanel.addTitlebarAccessoryViewController(browserAccessory)

        if let panel = informationPanel as? InteractiveInformationPanel {
            panel.onInteractionBegan = { [weak self] in
                self?.beginInteraction()
            }
            panel.onInteractionEnded = { [weak self] in
                self?.endInteraction()
            }
        }
        if let interactiveWebView = webView as? InteractiveInformationWebView {
            interactiveWebView.onInteractionBegan = { [weak self] in
                self?.beginInteraction()
            }
            interactiveWebView.onEscape = { [weak self] in
                self?.endInteraction(resignPanel: true)
            }
        }

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
        if isInteractionActive {
            pendingPresentation = PendingPresentation(
                url: url,
                panelTitle: panelTitle,
                definitions: definitions,
                showExternalInformation: showExternalInformation,
                displayDelay: displayDelay,
                candidateFrame: candidateFrame
            )
            return
        }

        present(
            url: url,
            panelTitle: panelTitle,
            definitions: definitions,
            showExternalInformation: showExternalInformation,
            displayDelay: displayDelay,
            beside: candidateFrame
        )
    }

    private func present(
        url: URL?,
        panelTitle: String,
        definitions: [SystemDictionaryDefinition],
        showExternalInformation: Bool,
        displayDelay: TimeInterval,
        beside candidateFrame: NSRect
    ) {
        displayTask?.cancel()
        navigationTask?.cancel()
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

        let cookies = cookies(for: url)
        let cookieSignature = cookies
            .map { "\($0.name)=\($0.value)" }
            .sorted()
            .joined(separator: ";")
        informationPanel.title = panelTitle
        if displayedURL != url
            || installedCookieSignature != cookieSignature {
            webView.stopLoading()
            let navigationDelay = min(
                Self.navigationDebounce,
                displayDelay
            )
            navigationTask = Task { @MainActor [weak self] in
                if navigationDelay > 0 {
                    try? await Task.sleep(
                        for: .milliseconds(Int(navigationDelay * 1_000))
                    )
                }
                guard
                    !Task.isCancelled,
                    let self,
                    requestID == currentRequestID
                else {
                    return
                }
                var request = URLRequest(url: url)
                for (field, value) in HTTPCookie.requestHeaderFields(
                    with: cookies
                ) {
                    request.setValue(value, forHTTPHeaderField: field)
                }
                webView.load(request)
                displayedURL = url
                if installedCookieSignature != cookieSignature {
                    installedCookieSignature = cookieSignature
                    await installSharedCosenseCookies(cookies)
                }
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

    private func cookies(for url: URL) -> [HTTPCookie] {
        guard url.host == "scrapbox.io" else {
            return []
        }
        if Date().timeIntervalSince(cookiesLoadedAt)
            >= Self.cookieCacheLifetime {
            cachedCosenseCookies = CosenseWebCookieStore().load()
            cookiesLoadedAt = Date()
        }
        return cachedCosenseCookies
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
        navigationTask?.cancel()
        navigationTask = nil
        webView.stopLoading()
        requestID = UUID()
        pendingPresentation = nil
        isInteractionActive = false
        definitionPanel.orderOut(nil)
        informationPanel.orderOut(nil)
    }

    private func beginInteraction() {
        guard !isInteractionActive else {
            return
        }
        isInteractionActive = true
        displayTask?.cancel()
        navigationTask?.cancel()
        onInteractionBegan?()
    }

    private func endInteraction(resignPanel: Bool = false) {
        guard isInteractionActive else {
            return
        }
        isInteractionActive = false
        if resignPanel {
            informationPanel.resignKey()
        }
        onInteractionEnded?()

        guard let pendingPresentation else {
            return
        }
        self.pendingPresentation = nil
        present(
            url: pendingPresentation.url,
            panelTitle: pendingPresentation.panelTitle,
            definitions: pendingPresentation.definitions,
            showExternalInformation: pendingPresentation.showExternalInformation,
            displayDelay: pendingPresentation.displayDelay,
            beside: pendingPresentation.candidateFrame
        )
    }

    func finishInteraction() {
        endInteraction()
    }

    @discardableResult
    func openDisplayedPageInDefaultBrowser() -> Bool {
        guard let url = webView.url ?? displayedURL,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        return NSWorkspace.shared.open(url)
    }

    @objc
    private func openDisplayedPageInDefaultBrowser(_ sender: Any?) {
        if !openDisplayedPageInDefaultBrowser() {
            NSSound.beep()
        }
    }

    private static func makePanel(
        title: String,
        size: NSSize,
        interactive: Bool
    ) -> NSPanel {
        let styleMask: NSWindow.StyleMask = interactive
            ? [.titled, .closable, .resizable, .nonactivatingPanel]
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
    var onInteractionBegan: (() -> Void)?
    var onInteractionEnded: (() -> Void)?

    override var canBecomeKey: Bool {
        false
    }

    override var canBecomeMain: Bool {
        false
    }

    override func sendEvent(_ event: NSEvent) {
        if event.type == .leftMouseDown
            || event.type == .rightMouseDown
            || event.type == .otherMouseDown
            || event.type == .scrollWheel {
            onInteractionBegan?()
        }
        super.sendEvent(event)
    }

    override func close() {
        onInteractionEnded?()
        super.close()
    }
}

private final class InteractiveInformationWebView: WKWebView {
    var onInteractionBegan: (() -> Void)?
    var onEscape: (() -> Void)?

    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        onInteractionBegan?()
        super.mouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        onInteractionBegan?()
        super.scrollWheel(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 {
            onEscape?()
            return
        }
        super.keyDown(with: event)
    }
}
