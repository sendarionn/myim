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

public enum CandidateCommitReplacementRange {
    public static func resolve(
        markedRange: NSRange,
        replacingMarkedText: Bool
    ) -> NSRange {
        guard replacingMarkedText,
              markedRange.location != NSNotFound,
              markedRange.length > 0 else {
            return NSRange(location: NSNotFound, length: NSNotFound)
        }
        return markedRange
    }
}
