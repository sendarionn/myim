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
    private var acceptsKeyboardInteraction = false

    override var canBecomeKey: Bool { acceptsKeyboardInteraction }
    override var canBecomeMain: Bool { false }

    func beginUserInteraction() {
        acceptsKeyboardInteraction = true
        makeKey()
    }

    func endUserInteraction() {
        acceptsKeyboardInteraction = false
    }

    override func sendEvent(_ event: NSEvent) {
        switch event.type {
        case .leftMouseDown, .rightMouseDown, .otherMouseDown,
             .scrollWheel, .keyDown:
            beginUserInteraction()
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
        (window as? BrowserPanel)?.beginUserInteraction()
        super.mouseDown(with: event)
    }

    override func rightMouseDown(with event: NSEvent) {
        recordBrowserInteraction()
        (window as? BrowserPanel)?.beginUserInteraction()
        super.rightMouseDown(with: event)
    }

    override func scrollWheel(with event: NSEvent) {
        recordBrowserInteraction()
        (window as? BrowserPanel)?.beginUserInteraction()
        super.scrollWheel(with: event)
    }
}

private final class BrowserController: NSObject, NSApplicationDelegate,
    NSWindowDelegate, WKNavigationDelegate, WKUIDelegate {
    private static let idleTerminationInterval: TimeInterval = 30
    private static let notificationName = Notification.Name(
        "io.github.sendarionn.myim.external-browser.command"
    )
    private var panel: BrowserPanel!
    private var webView: WKWebView!
    private var titleLabel: NSTextField!
    private var openButton: NSButton!
    private var displayedURL: URL?
    private var idleTerminationTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        webView = BrowserWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = self
        webView.uiDelegate = self

        panel = BrowserPanel(
            contentRect: NSRect(x: 0, y: 0, width: 420, height: 420),
            styleMask: [.borderless, .resizable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        titleLabel = NSTextField(labelWithString: "外部情報")
        titleLabel.font = .systemFont(ofSize: 12, weight: .semibold)
        titleLabel.lineBreakMode = .byTruncatingTail
        openButton = NSButton(
            title: "ブラウザで開く",
            target: self,
            action: #selector(openInDefaultBrowser(_:))
        )
        openButton.bezelStyle = .inline
        let header = NSStackView(views: [titleLabel, openButton])
        header.orientation = .horizontal
        header.alignment = .centerY
        header.spacing = 8
        header.edgeInsets = NSEdgeInsets(top: 4, left: 8, bottom: 4, right: 8)
        header.translatesAutoresizingMaskIntoConstraints = false
        webView.translatesAutoresizingMaskIntoConstraints = false
        let root = NSView()
        root.addSubview(header)
        root.addSubview(webView)
        NSLayoutConstraint.activate([
            header.topAnchor.constraint(equalTo: root.topAnchor),
            header.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            header.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            header.heightAnchor.constraint(equalToConstant: 30),
            webView.topAnchor.constraint(equalTo: header.bottomAnchor),
            webView.leadingAnchor.constraint(equalTo: root.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: root.trailingAnchor),
            webView.bottomAnchor.constraint(equalTo: root.bottomAnchor)
        ])
        panel.contentView = root
        panel.title = "外部情報"
        panel.level = .floating
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true
        panel.isMovableByWindowBackground = true
        panel.isReleasedWhenClosed = false
        panel.delegate = self

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
        idleTerminationTask?.cancel()
        idleTerminationTask = nil
        guard let url = command.url else {
            if panel.isKeyWindow {
                return
            }
            panel.endUserInteraction()
            panel.orderOut(nil)
            scheduleIdleTermination()
            return
        }
        guard url.scheme == "https" else {
            return
        }
        panel.title = command.title
        titleLabel.stringValue = command.title
        openButton.title = command.openShortcutDisplayName.map {
            "ブラウザで開く  \($0)"
        } ?? "ブラウザで開く"
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
            panel.endUserInteraction()
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
        panel.endUserInteraction()
        panel.orderOut(nil)
        scheduleIdleTermination()
        return false
    }

    private func scheduleIdleTermination() {
        idleTerminationTask?.cancel()
        idleTerminationTask = Task { @MainActor [weak self] in
            try? await Task.sleep(
                for: .seconds(Self.idleTerminationInterval)
            )
            guard !Task.isCancelled,
                  let self,
                  !panel.isVisible,
                  !panel.isKeyWindow else {
                return
            }
            webView.stopLoading()
            webView.navigationDelegate = nil
            webView.uiDelegate = nil
            NSApplication.shared.terminate(nil)
        }
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.accessory)
private let controller = BrowserController()
application.delegate = controller
application.run()
withExtendedLifetime(controller) {}
