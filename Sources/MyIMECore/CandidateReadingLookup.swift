public enum CandidateReadingLookup {
    public static func resolve(
        candidate: String,
        userEngine: LayeredConversionEngine,
        basicEngine: ConversionEngine,
        indexedEngine: IndexedDictionaryEngine
    ) async -> [String] {
        await Task.detached(priority: .utility) {
            var seen = Set<String>()
            return (
                userEngine.readings(for: candidate)
                + basicEngine.readings(for: candidate)
                + indexedEngine.readings(for: candidate)
            ).flatMap {
                RomajiCanonicalizer.dictionaryLookupInputs(from: $0)
            }.filter {
                seen.insert($0).inserted
            }
        }.value
    }
}
