public enum CandidateResultUpdatePolicy {
    public static func changes<Value: Equatable>(
        current: [Value],
        updated: [Value]
    ) -> Bool {
        current != updated
    }
}
