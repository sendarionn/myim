@preconcurrency import AppKit
import MyIMECore

final class ExternalInformationWindowController: NSObject {
    private struct PendingPresentation {
        let url: URL?
        let panelTitle: String
        let definitions: [SystemDictionaryDefinition]
        let showExternalInformation: Bool
        let candidateFrame: NSRect
    }

    private static let spacing: CGFloat = 8
    private static let informationPanelSize = NSSize(width: 420, height: 420)

    private let definitionPanel: NSPanel
    private let definitionTextView: NSTextView
    private let externalBrowser = ExternalBrowserBridge()
    private var informationPanelFrame = NSRect(
        origin: .zero,
        size: informationPanelSize
    )
    private var displayedURL: URL?
    private var requestID = UUID()
    private var displayTask: Task<Void, Never>?
    private var navigationTask: Task<Void, Never>?
    private var pendingPresentation: PendingPresentation?
    private(set) var isInteractionActive = false
    var onInteractionBegan: (() -> Void)?
    var onInteractionEnded: (() -> Void)?
    private static let navigationDebounce: TimeInterval = 0.2
    private static let displayDelay: TimeInterval = 0.5

    override init() {
        definitionTextView = NSTextView(frame: .zero)
        definitionPanel = Self.makePanel(
            title: "macOS辞書",
            size: NSSize(width: 420, height: 220)
        )

        super.init()

        Self.removeLegacyCookieFile()
        externalBrowser.onInteractionBegan = { [weak self] in
            self?.beginInteraction()
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
    }

    func show(
        url: URL?,
        panelTitle: String,
        definitions: [SystemDictionaryDefinition],
        showExternalInformation: Bool,
        beside candidateFrame: NSRect
    ) {
        if isInteractionActive {
            pendingPresentation = PendingPresentation(
                url: url,
                panelTitle: panelTitle,
                definitions: definitions,
                showExternalInformation: showExternalInformation,
                candidateFrame: candidateFrame
            )
            return
        }

        present(
            url: url,
            panelTitle: panelTitle,
            definitions: definitions,
            showExternalInformation: showExternalInformation,
            beside: candidateFrame
        )
    }

    private func present(
        url: URL?,
        panelTitle: String,
        definitions: [SystemDictionaryDefinition],
        showExternalInformation: Bool,
        beside candidateFrame: NSRect
    ) {
        displayTask?.cancel()
        navigationTask?.cancel()
        let currentRequestID = UUID()
        requestID = currentRequestID
        externalBrowser.hide()

        definitionPanel.orderOut(nil)
        if !definitions.isEmpty {
            definitionTextView.textStorage?.setAttributedString(
                attributedDefinitions(definitions)
            )
            definitionTextView.scrollToBeginningOfDocument(nil)
        }

        if showExternalInformation, let url, displayedURL != url {
            let navigationDelay = min(
                Self.navigationDebounce,
                Self.displayDelay
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
                positionInformationPanel(near: candidateFrame)
                externalBrowser.send(browserCommand(
                    url: url,
                    title: panelTitle,
                    isVisible: false
                ))
                displayedURL = url
            }
        }

        displayTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .milliseconds(500))
            guard !Task.isCancelled else {
                return
            }
            guard
                let self,
                requestID == currentRequestID
            else {
                return
            }

            if !definitions.isEmpty {
                positionDefinitionPanel(near: candidateFrame)
                definitionPanel.orderFrontRegardless()
            }
            guard showExternalInformation, let url else {
                return
            }
            positionInformationPanel(near: candidateFrame)
            externalBrowser.send(browserCommand(
                url: url,
                title: panelTitle,
                isVisible: true
            ))
        }
    }

    private func browserCommand(
        url: URL,
        title: String,
        isVisible: Bool
    ) -> ExternalBrowserCommand {
        let frame = informationPanelFrame
        return ExternalBrowserCommand(
            url: url,
            title: title,
            frameX: frame.origin.x,
            frameY: frame.origin.y,
            frameWidth: frame.width,
            frameHeight: frame.height,
            isVisible: isVisible
        )
    }

    private static func removeLegacyCookieFile() {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            return
        }
        let file = applicationSupport
            .appendingPathComponent("myim/web-session", isDirectory: true)
            .appendingPathComponent("cosense-web-cookies.json")
        try? FileManager.default.removeItem(at: file)
    }

    func hide() {
        displayTask?.cancel()
        displayTask = nil
        navigationTask?.cancel()
        navigationTask = nil
        requestID = UUID()
        pendingPresentation = nil
        isInteractionActive = false
        definitionPanel.orderOut(nil)
        externalBrowser.hide()
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

    private func endInteraction() {
        guard isInteractionActive else {
            return
        }
        isInteractionActive = false
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
            beside: pendingPresentation.candidateFrame
        )
    }

    func finishInteraction() {
        externalBrowser.clearInteractionMarker()
        endInteraction()
    }

    func shouldPreserveForExternalInteraction() -> Bool {
        if externalBrowser.hasRecentInteraction() {
            beginInteraction()
        }
        return isInteractionActive
    }

    @discardableResult
    func openDisplayedPageInDefaultBrowser() -> Bool {
        guard let url = displayedURL,
              let scheme = url.scheme?.lowercased(),
              scheme == "http" || scheme == "https" else {
            return false
        }
        return NSWorkspace.shared.open(url)
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

    private func positionInformationPanel(near candidateFrame: NSRect) {
        let visibleFrame = visibleFrame(near: candidateFrame)
        let panelSize = NSSize(
            width: min(Self.informationPanelSize.width, visibleFrame.width),
            height: min(Self.informationPanelSize.height, visibleFrame.height)
        )
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
        informationPanelFrame = NSRect(
            origin: NSPoint(x: x, y: y),
            size: panelSize
        )
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
