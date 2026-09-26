import Foundation

public enum CalculationInputHistory {
    public static func value(
        input: String,
        selectedCandidate: String,
        generatedCandidates: [String]
    ) -> String? {
        guard input.trimmingCharacters(in: .whitespaces).hasSuffix("="),
              generatedCandidates.contains(selectedCandidate) else {
            return nil
        }
        return input
    }

    public static func completionCandidates(
        input: String,
        historyCandidates: [String]
    ) -> [String] {
        guard input.count >= 2 else { return [] }
        return historyCandidates.filter {
            $0.hasPrefix(input)
                && $0.trimmingCharacters(in: .whitespaces).hasSuffix("=")
        }
    }
}
