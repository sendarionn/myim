import Foundation
import MyIMECore

#if canImport(FoundationModels)
import FoundationModels
#endif

enum FoundationModelsMeaningSearchError: LocalizedError {
    case unsupportedOS
    case unavailable(String)
    case noCandidates

    var errorDescription: String? {
        switch self {
        case .unsupportedOS:
            "macOS 26以降が必要"
        case .unavailable(let reason):
            reason
        case .noCandidates:
            "候補なし"
        }
    }
}

enum FoundationModelsMeaningSearcher {
    static func candidates(
        for description: String,
        excluding excludedCandidates: [String] = []
    ) async throws -> [String] {
        guard let prompt = MeaningSearchPromptBuilder.prompt(
            for: description,
            excluding: excludedCandidates
        ) else {
            return []
        }
#if canImport(FoundationModels)
        guard #available(macOS 26.0, *) else {
            throw FoundationModelsMeaningSearchError.unsupportedOS
        }
        let model = SystemLanguageModel.default
        switch model.availability {
        case .available:
            break
        case .unavailable(.deviceNotEligible):
            throw FoundationModelsMeaningSearchError.unavailable("非対応Mac")
        case .unavailable(.appleIntelligenceNotEnabled):
            throw FoundationModelsMeaningSearchError.unavailable(
                "Apple Intelligenceが無効"
            )
        case .unavailable(.modelNotReady):
            throw FoundationModelsMeaningSearchError.unavailable("モデル準備中")
        @unknown default:
            throw FoundationModelsMeaningSearchError.unavailable("利用不可")
        }
        let session = LanguageModelSession(model: model)
        let response = try await session.respond(to: prompt)
        let candidates = MeaningSearchPromptBuilder.candidates(
            from: response.content
        )
        guard !candidates.isEmpty else {
            throw FoundationModelsMeaningSearchError.noCandidates
        }
        return candidates
#else
        throw FoundationModelsMeaningSearchError.unsupportedOS
#endif
    }
}
