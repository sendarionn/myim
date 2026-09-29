import Foundation

public enum CandidateLocationRetryPolicy {
    public static func delay(after attempt: Int) -> TimeInterval {
        if attempt < 10 {
            return 0.04
        }
        if attempt < 30 {
            return 0.1
        }
        return 0.25
    }
}
