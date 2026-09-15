public enum LinearCandidateNavigator {
    public static func pageRange(
        containing index: Int?,
        pageSize: Int,
        candidateCount: Int
    ) -> Range<Int> {
        guard pageSize > 0, candidateCount > 0 else { return 0..<0 }
        let boundedIndex = min(max(index ?? 0, 0), candidateCount - 1)
        let start = boundedIndex / pageSize * pageSize
        return start..<min(start + pageSize, candidateCount)
    }

    public static func index(
        from currentIndex: Int?,
        offset: Int,
        candidateCount: Int
    ) -> Int? {
        guard candidateCount > 0, offset != 0 else { return nil }
        guard let currentIndex,
              (0..<candidateCount).contains(currentIndex) else {
            return offset > 0 ? 0 : candidateCount - 1
        }
        return (
            currentIndex + offset + candidateCount
        ) % candidateCount
    }
}
