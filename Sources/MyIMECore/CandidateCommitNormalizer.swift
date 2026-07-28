import Foundation

public enum CandidateCommitNormalizer {
    public static func value(from candidate: String) -> String {
        guard candidate.count > 1 else {
            return candidate
        }
        return candidate
            .replacingOccurrences(of: "〜", with: "")
            .replacingOccurrences(of: "～", with: "")
    }
}
