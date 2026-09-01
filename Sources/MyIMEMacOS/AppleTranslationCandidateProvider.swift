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
            contentRect: NSRect(x: -10_000, y: -10_000, width: 360, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        panel.contentViewController = host
        panel.title = "翻訳言語を準備"
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        panel.orderFrontRegardless()
    }

    func translateJapaneseToEnglish(_ text: String) async -> String? {
        await translateJapanese(text, targetIdentifier: "en")
    }

    func translateJapanese(
        _ text: String,
        targetIdentifier: String
    ) async -> String? {
        let sourceLanguage = Locale.Language(identifier: "ja")
        let targetLanguage = Locale.Language(identifier: targetIdentifier)
        let availability = LanguageAvailability()
        let status = await availability.status(
            from: sourceLanguage,
            to: targetLanguage
        )
        guard status != .unsupported else { return nil }

        if status == .installed {
            if #available(macOS 26.0, *) {
                let session = TranslationSession(
                    installedSource: sourceLanguage,
                    target: targetLanguage
                )
                do {
                    let response = try await session.translate(text)
                    return response.targetText
                } catch {
                    return nil
                }
            }
        }

        let requiresPreparation = status == .supported
        return await withTaskCancellationHandler {
            await withCheckedContinuation { continuation in
                finishPendingTranslation(with: nil)
                pendingCompletion = { result in
                    continuation.resume(returning: result)
                }
                host.rootView = AnyView(
                    AppleTranslationRequestView(
                        text: text,
                        sourceLanguage: sourceLanguage,
                        targetLanguage: targetLanguage,
                        showsPreparation: requiresPreparation
                    ) { [weak self] result in
                        self?.finishPendingTranslation(with: result)
                    }
                )
                if requiresPreparation {
                    panel.alphaValue = 1
                    panel.ignoresMouseEvents = false
                    panel.center()
                    panel.orderFrontRegardless()
                }
            }
        } onCancel: {
            Task { @MainActor [weak self] in
                self?.finishPendingTranslation(with: nil)
            }
        }
    }

    private func finishPendingTranslation(with result: String?) {
        panel.alphaValue = 0
        panel.ignoresMouseEvents = true
        panel.setFrameOrigin(NSPoint(x: -10_000, y: -10_000))
        let completion = pendingCompletion
        pendingCompletion = nil
        completion?(result)
    }
}

@available(macOS 15.0, *)
private struct AppleTranslationRequestView: View {
    let text: String
    let sourceLanguage: Locale.Language
    let targetLanguage: Locale.Language
    let showsPreparation: Bool
    let completion: (String?) -> Void
    @State private var completed = false

    var body: some View {
        Group {
            if showsPreparation {
                Text("翻訳言語データを準備しています")
                    .padding()
            } else {
                EmptyView()
            }
        }
            .translationTask(
                source: sourceLanguage,
                target: targetLanguage
            ) { session in
                guard !completed else { return }
                do {
                    try await session.prepareTranslation()
                    let translated = try await session.translate(text)
                    completed = true
                    completion(translated.targetText)
                } catch {
                    completed = true
                    completion(nil)
                }
            }
    }
}
#endif
