public enum CalculationCandidateSet {
    public static func visible(
        generatedCandidates: [String],
        input: String
    ) -> [String] {
        var seen = Set<String>()
        return generatedCandidates.filter {
            $0 != input && seen.insert($0).inserted
        }
    }
}
