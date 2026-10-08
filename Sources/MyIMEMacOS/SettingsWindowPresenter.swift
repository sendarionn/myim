@preconcurrency import AppKit

final class SettingsWindowPresenter {
    private var window: NSWindow?

    func show(
        near inputFrame: NSRect,
        makeWindow: () -> NSWindow
    ) {
        let window: NSWindow
        if let existing = self.window {
            replaceContent(of: existing, preservingScrollPosition: true) {
                makeWindow()
            }
            window = existing
        } else {
            let created = makeWindow()
            created.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            self.window = created
            resetScrollPosition(created)
            placeOnActiveScreen(created, near: inputFrame)
            window = created
        }
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
    }

    func refreshIfPresented(makeWindow: () -> NSWindow) {
        guard let window else { return }
        replaceContent(of: window, preservingScrollPosition: true) {
            makeWindow()
        }
    }

    func run(
        _ panel: NSSavePanel,
        completion: @escaping (NSApplication.ModalResponse) -> Void
    ) {
        if let window {
            panel.beginSheetModal(for: window, completionHandler: completion)
        } else {
            completion(panel.runModal())
        }
    }

    private func placeOnActiveScreen(_ window: NSWindow, near inputFrame: NSRect) {
        let pointer = NSEvent.mouseLocation
        let screen = NSScreen.screens.first {
            inputFrame != .zero && $0.frame.intersects(inputFrame)
        } ?? NSScreen.screens.first {
            $0.frame.contains(pointer)
        } ?? NSScreen.main
        guard let visibleFrame = screen?.visibleFrame else { return }
        let origin = NSPoint(
            x: visibleFrame.midX - window.frame.width / 2,
            y: visibleFrame.midY - window.frame.height / 2
        )
        window.setFrameOrigin(origin)
    }

    private func resetScrollPosition(_ window: NSWindow) {
        guard let scrollView = window.contentView as? NSScrollView else {
            return
        }
        window.layoutIfNeeded()
        scrollView.contentView.scroll(to: .zero)
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }

    private func replaceContent(
        of window: NSWindow,
        preservingScrollPosition: Bool,
        makeWindow: () -> NSWindow
    ) {
        let origin = preservingScrollPosition
            ? scrollOrigin(in: window)
            : nil
        let frame = window.frame
        let replacement = makeWindow()
        guard let contentView = replacement.contentView else { return }
        replacement.contentView = nil
        window.contentView = contentView
        window.minSize = replacement.minSize
        window.layoutIfNeeded()
        window.setFrame(frame, display: window.isVisible)
        if let origin {
            restoreScrollOrigin(origin, in: window)
        }
    }

    private func scrollOrigin(in window: NSWindow) -> NSPoint? {
        (window.contentView as? NSScrollView)?.contentView.bounds.origin
    }

    private func restoreScrollOrigin(_ origin: NSPoint, in window: NSWindow) {
        guard let scrollView = window.contentView as? NSScrollView,
              let documentView = scrollView.documentView else {
            return
        }
        let maximumX = max(
            documentView.bounds.width - scrollView.contentView.bounds.width,
            0
        )
        let maximumY = max(
            documentView.bounds.height - scrollView.contentView.bounds.height,
            0
        )
        scrollView.contentView.scroll(to: NSPoint(
            x: min(max(origin.x, 0), maximumX),
            y: min(max(origin.y, 0), maximumY)
        ))
        scrollView.reflectScrolledClipView(scrollView.contentView)
    }
}
