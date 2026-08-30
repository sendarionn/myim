import Foundation
import KanaKanjiConverterModuleWithDefaultDictionary

actor NeuralContextCandidateProvider {
    static let modelFileName = "zenz-v3.2-small-Q5_K_M.gguf"
    static let modelDownloadURL = URL(
        string: "https://huggingface.co/Miwa-Keita/zenz-v3.2-small-gguf/resolve/main/ggml-model-Q5_K_M.gguf"
    )!

    private lazy var converter = KanaKanjiConverter.withDefaultDictionary()

    func candidates(
        for hiragana: String,
        context: String,
        modelURL: URL,
        limit: Int
    ) -> [String] {
        guard !hiragana.isEmpty,
              FileManager.default.fileExists(atPath: modelURL.path) else {
            return []
        }
        var composingText = ComposingText()
        composingText.insertAtCursorPosition(hiragana, inputStyle: .direct)
        let directory = modelURL.deletingLastPathComponent()
        let options = ConvertRequestOptions(
            N_best: max(limit, 10),
            requireJapanesePrediction: .disabled,
            requireEnglishPrediction: .disabled,
            keyboardLanguage: .ja_JP,
            learningType: .nothing,
            maxMemoryCount: 0,
            memoryDirectoryURL: directory,
            sharedContainerURL: directory,
            textReplacer: .empty,
            specialCandidateProviders: [],
            zenzaiMode: .on(
                weight: modelURL,
                inferenceLimit: 1,
                requestRichCandidates: true,
                personalizationMode: nil,
                versionDependentMode: .v3(.init(
                    leftSideContext: context,
                    maxLeftSideContextLength: 256
                ))
            ),
            typoCorrectionMode: .disabled,
            metadata: .init(versionString: "myim")
        )
        var seen = Set<String>()
        return converter.requestCandidates(composingText, options: options)
            .mainResults
            .map(\.text)
            .filter { seen.insert($0).inserted }
            .prefix(limit)
            .map { $0 }
    }

    static func modelURL() -> URL? {
        guard let applicationSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else { return nil }
        return applicationSupport
            .appendingPathComponent("myim/Models", isDirectory: true)
            .appendingPathComponent(modelFileName)
    }
}
