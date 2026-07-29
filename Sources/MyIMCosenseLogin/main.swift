@preconcurrency import AppKit
@preconcurrency import WebKit
import MyIMECore

private final class LoginController: NSObject, NSApplicationDelegate,
    NSWindowDelegate, WKUIDelegate {
    private var window: NSWindow?
    private var webView: WKWebView?

    func applicationDidFinishLaunching(_ notification: Notification) {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.uiDelegate = self

        let saveButton = NSButton(
            title: "ログイン完了",
            target: self,
            action: #selector(saveAndQuit(_:))
        )
        saveButton.keyEquivalent = "\r"
        saveButton.translatesAutoresizingMaskIntoConstraints = false

        let content = NSView()
        webView.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(webView)
        content.addSubview(saveButton)
        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            webView.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            webView.topAnchor.constraint(equalTo: content.topAnchor),
            webView.bottomAnchor.constraint(
                equalTo: saveButton.topAnchor,
                constant: -8
            ),
            saveButton.trailingAnchor.constraint(
                equalTo: content.trailingAnchor,
                constant: -12
            ),
            saveButton.bottomAnchor.constraint(
                equalTo: content.bottomAnchor,
                constant: -10
            )
        ])

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 760, height: 620),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "myim Cosenseログイン"
        window.contentView = content
        window.delegate = self
        window.center()
        window.makeKeyAndOrderFront(nil)
        self.window = window
        self.webView = webView

        NSApp.activate(ignoringOtherApps: true)
        webView.load(
            URLRequest(url: URL(string: "https://scrapbox.io/login")!)
        )
    }

    @objc
    private func saveAndQuit(_ sender: Any?) {
        guard let cookieStore = webView?.configuration.websiteDataStore
            .httpCookieStore else {
            NSApp.terminate(nil)
            return
        }
        cookieStore.getAllCookies { cookies in
            let cosenseCookies = cookies.filter {
                $0.domain == "scrapbox.io"
                    || $0.domain.hasSuffix(".scrapbox.io")
            }
            do {
                try CosenseWebCookieStore().save(cosenseCookies)
                NSApp.terminate(nil)
            } catch {
                NSSound.beep()
            }
        }
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.terminate(nil)
    }

    func webView(
        _ webView: WKWebView,
        createWebViewWith configuration: WKWebViewConfiguration,
        for navigationAction: WKNavigationAction,
        windowFeatures: WKWindowFeatures
    ) -> WKWebView? {
        if let request = navigationAction.request.url {
            webView.load(URLRequest(url: request))
        }
        return nil
    }
}

let application = NSApplication.shared
application.setActivationPolicy(.regular)
private let controller = LoginController()
application.delegate = controller
application.run()
withExtendedLifetime(controller) {}
