/// Candidates from another source placed after the first page of the
/// dictionary candidates, so the dictionary keeps the first page and the
/// others are seen on the next instead of after every completion
public enum CandidateListInsertion {
    public static func inserting<Element>(
        _ inserted: [Element],
        into candidates: [Element],
        afterFirst count: Int
    ) -> [Element] {
        guard !inserted.isEmpty else { return candidates }
        let index = min(max(count, 0), candidates.count)
        return Array(candidates[..<index]) + inserted + Array(candidates[index...])
    }
}
