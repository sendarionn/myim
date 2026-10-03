@preconcurrency import AppKit

final class SettingsWindowPresenter {
    private var window: NSWindow?

    func show(
        near inputFrame: NSRect,
        makeWindow: () -> NSWindow
    ) {
        let window = self.window ?? {
            let window = makeWindow()
            window.collectionBehavior = [.moveToActiveSpace, .fullScreenAuxiliary]
            self.window = window
            return window
        }()
        resetScrollPosition(window)
        placeOnActiveScreen(window, near: inputFrame)
        NSApp.activate(ignoringOtherApps: true)
        window.makeKeyAndOrderFront(nil)
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
}
