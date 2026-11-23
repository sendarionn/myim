import Foundation

public enum CandidateCommitNormalizer {
    public static func value(from candidate: String) -> String {
        // Nearly every dictionary value has no wave dash; finding none in
        // the bytes avoids counting characters and two Foundation searches
        guard containsWaveDash(candidate), candidate.count > 1 else {
            return candidate
        }
        return candidate
            .replacingOccurrences(of: "〜", with: "")
            .replacingOccurrences(of: "～", with: "")
    }

    /// 〜 (E3 80 9C) or ～ (EF BD 9E) in the UTF-8 bytes
    private static func containsWaveDash(_ value: String) -> Bool {
        var previous: (UInt8, UInt8) = (0, 0)
        for byte in value.utf8 {
            if (previous == (0xE3, 0x80) && byte == 0x9C)
                || (previous == (0xEF, 0xBD) && byte == 0x9E) {
                return true
            }
            previous = (previous.1, byte)
        }
        return false
    }
}

public enum CandidateCommitReplacementRange {
    public static func resolve(
        markedRange: NSRange,
        hasActiveComposition: Bool
    ) -> NSRange {
        guard hasActiveComposition,
              markedRange.location != NSNotFound,
              markedRange.length > 0 else {
            return NSRange(location: NSNotFound, length: NSNotFound)
        }
        return markedRange
    }
}
