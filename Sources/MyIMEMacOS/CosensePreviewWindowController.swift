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

        let origin = NSPoint(
            x: candidateFrame.maxX + 8,
            y: candidateFrame.maxY
        )
        panel.setFrameTopLeftPoint(origin)
        panel.orderFrontRegardless()
    }

    func hide() {
        panel.orderOut(nil)
    }
}
