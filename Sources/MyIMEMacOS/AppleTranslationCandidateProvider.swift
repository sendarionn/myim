import AppKit
import SwiftUI

#if canImport(Translation)
import Translation

@available(macOS 15.0, *)
@MainActor
final class AppleTranslationCandidateProvider {
    private let panel: NSPanel
    private let host: NSHostingController<AnyView>
    private var pendingCompletion: ((String?) -> Void)?

    init() {
        host = NSHostingController(rootView: AnyView(EmptyView()))
        panel = NSPanel(
            contentRect: NSRect(x: -10_000, y: -10_000, width: 1, height: 1),
            styleMask: [.borderless],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = host
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
    }

    func translateJapaneseToEnglish(_ text: String) async -> String? {
        await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                finishPendingTranslation(with: nil)
                pendingCompletion = { result in
                    continuation.resume(returning: result)
                }
                host.rootView = AnyView(
                    AppleTranslationRequestView(text: text) { [weak self] result in
                        self?.finishPendingTranslation(with: result)
                    }
                )
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finishPendingTranslation(with: nil)
            }
        }
    }

    private func finishPendingTranslation(with result: String?) {
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(result)
    }
}

@available(macOS 15.0, *)
private struct AppleTranslationRequestView: View {
    let text: String
    let completion: (String?) -> Void
    @State private var completed = false
    private let configuration = TranslationSession.Configuration(
        source: Locale.Language(identifier: "ja"),
        target: Locale.Language(identifier: "en")
    )

    var body: some View {
        EmptyView()
            .translationTask(configuration) { session in
                guard !completed else { return }
                let translated = try? await session.translate(text)
                completed = true
                completion(translated?.targetText)
            }
    }
}
#endif
