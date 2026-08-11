@preconcurrency import AppKit
@preconcurrency import WebKit
import MyIMECore

private func recordBrowserInteraction() {
    do {
        let fileManager = FileManager.default
        let base = try fileManager.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let directory = base.appendingPathComponent(
            "myim/browser",
            isDirectory: true
        )
        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true,
            attributes: [.posixPermissions: 0o700]
        )
        let marker = directory.appendingPathComponent("interaction")
        try Data().write(to: marker, options: .atomic)
        try fileManager.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: marker.path
        )
    } catch {
        NSLog("外部情報ブラウザの操作記録に失敗: %@", error.localizedDescription)
    }
    DistributedNotificationCenter.default().postNotificationName(
        Notification.Name(
            "io.github.sendarionn.myim.external-browser.interaction-began"
        ),
        object: nil,
        userInfo: nil,
        deliverImmediately: true
    )
}

private final class BrowserPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown,
             .scrollWheel, .keyDown:
            makeKey()
            recordBrowserInteraction()
        default:
            break
        }
        super.sendEvent(event)
    }
}

private final class BrowserWebView: WKWebView {
    override func acceptsFirstMouse(for event: NSEvent?) -> Bool {
        true
    }

    override func mouseDown(with event: NSEvent) {
        recordBrowserInteraction()
        window?.makeKey()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        recordBrowserInteraction()
        window?.makeKey()
        super.rightMouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        recordBrowserInteraction()
        window?.makeKey()
        super.scrollWheel(with: event)
    }
}

private final class BrowserController: NSObject, NSApplicationDelegate,
    NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    private static let notificationName = Notification.Name(
        "io.github.sendarionn.myim.external-browser.command"
    )
    private var panel: BrowserPanel!
    private var webView: WKWebView!
    private var displayedURL: URL?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = BrowserWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self

        panel = BrowserPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.titled, .closable, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.title = "外部情報"
        panel.contentView = webView
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false
        panel.isReleasedWhenClosed = false
        panel.delegate = self

        let button = NSButton(
            title: "ブラウザで開く  ⌘O",
            target: self,
            action: #selector(openInDefaultBrowser(_:))
        )
        button.bezelStyle = .inline
        let accessory = NSTitlebarAccessoryViewController()
        accessory.layoutAttribute = .right
        accessory.view = button
        panel.addTitlebarAccessoryViewController(accessory)

        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(receiveCommand(_:)),
            name: Self.notificationName,
            object: nil
        )
        applyStoredCommand()
    }

    @objc private func receiveCommand(_ notification: Notification) {
        applyStoredCommand()
    }

    private func applyStoredCommand() {
        guard let command = loadCommand() else {
            return
        }
        guard let url = command.url else {
            if panel.isKeyWindow {
                return
            }
            panel.orderOut(nil)
            return
        }
        guard url.scheme == "https" else {
            return
        }
        panel.title = command.title
        panel.setFrame(
            NSRect(
                x: command.frameX,
                y: command.frameY,
                width: command.frameWidth,
                height: command.frameHeight
            ),
            display: true
        )
        if displayedURL != url {
            webView.load(URLRequest(url: url))
            displayedURL = url
        }
        guard command.isVisible else {
            if panel.isKeyWindow {
                return
            }
            panel.orderOut(nil)
            return
        }
        panel.orderFrontRegardless()
    }

    private func loadCommand() -> ExternalBrowserCommand? {
        guard let file = try? commandFileURL(),
              let data = try? Data(contentsOf: file) else {
            return nil
        }
        return try? JSONDecoder().decode(ExternalBrowserCommand.self, from: data)
    }

    private func commandFileURL() throws -> URL {
        try FileManager.default.url(
            for: .applicationSupportDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        .appendingPathComponent("myim/browser", isDirectory: true)
        .appendingPathComponent("command.json")
    }

    @objc private func openInDefaultBrowser(_ sender: Any?) {
        guard let url = webView.url ?? displayedURL else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func webView(
        _ webView: WKWebView,
        decidePolicyFor navigationAction: WKNavigationAction,
        decisionHandler: @escaping (WKNavigationActionPolicy) -> Void
    ) {
        guard let url = navigationAction.request.url else {
            decisionHandler(.cancel)
            return
        }
        let allowed = url.scheme == "https" || url.scheme == "about"
        decisionHandler(allowed ? .allow : .cancel)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        guard let url = navigationAction.request.url,
              url.scheme == "https" else {
            return nil
        }
        webView.load(URLRequest(url: url))
        return nil
    }

    func windowShouldClose(_ sender: NSWindow) -> Bool {
        panel.orderOut(nil)
        return false
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
private let controller = BrowserController()
application.delegate = controller
application.run()
withExtendedLifetime(controller) {}
