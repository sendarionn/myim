import Foundation
import MyIMECore

#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoundationModelsTextGeneratorError: LocalizedError {
    case unsupportedOS
    case unavailable(String)

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            return "生成モードにはmacOS 26以降が必要です"
        case .unavailable(let reason):
            return reason
        }
    }
}

enum FoundationModelsTextGenerator {
    static func generate(requirements: String, purpose: String) async throws -> String {
        guard let prompt = GenerationPromptBuilder.prompt(
            requirements: requirements,
            purpose: purpose
        ) else {
            return ""
        }
#if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else {
            throw FoundationModelsTextGeneratorError.unsupportedOS
        }
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(.deviceNotEligible):
            throw FoundationModelsTextGeneratorError.unavailable(
                "このMacはApple Intelligenceに対応していません"
            )
        case .unavailable(.appleIntelligenceNotEnabled):
            throw FoundationModelsTextGeneratorError.unavailable(
                "Apple Intelligenceを有効にしてください"
            )
        case .unavailable(.modelNotReady):
            throw FoundationModelsTextGeneratorError.unavailable(
                "言語モデルの準備が完了していません"
            )
        @unknown default:
            throw FoundationModelsTextGeneratorError.unavailable(
                "言語モデルを利用できません"
            )
        }
        let session = LanguageModelSession(model: model)
        let response = try await session.respond(to: prompt)
        return GenerationPromptBuilder.normalizeGeneratedText(response.content)
#else
        throw FoundationModelsTextGeneratorError.unsupportedOS
#endif
    }
}
