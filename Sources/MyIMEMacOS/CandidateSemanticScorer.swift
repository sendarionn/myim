import Foundation
import NaturalLanguage

enum CandidateSemanticScorer {
    private static let embedding = NLEmbedding.wordEmbedding(for: .japanese)

    static func score(
        query: String,
        candidate: String,
        definitions: [String]
    ) -> Double? {
        if candidate.contains(query) || query.contains(candidate) {
            return 1
        }
        if definitions.contains(where: { $0.localizedCaseInsensitiveContains(query) }) {
            return 0.95
        }
        guard let embedding else { return 0 }
        let distance = embedding.distance(between: query, and: candidate)
        guard distance.isFinite else { return 0 }
        return 1 / (1 + max(distance, 0))
    }
}
