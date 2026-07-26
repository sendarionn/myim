@preconcurrency import AppKit
@preconcurrency import WebKit

final class CosensePreviewWindowController {
    private let panel: NSPanel
    private let webView: WKWebView
    private var displayedURL: URL?

    init() {
        webView = WKWebView(frame: .zero)
        panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 420),
            styleMask: [.titled, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )

        panel.title = "Cosense"
        panel.contentView = webView
        panel.hidesOnDeactivate = false
        panel.level = .floating
        panel.isReleasedWhenClosed = false
    }

    func show(url: URL, beside candidateFrame: NSRect) {
        if displayedURL != url {
            webView.load(URLRequest(url: url))
            displayedURL = url
        }

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

    func hide() {
        panel.orderOut(nil)
    }
}
