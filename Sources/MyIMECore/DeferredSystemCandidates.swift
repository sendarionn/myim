/// System dictionary candidates that rank after particle compositions
///
/// Generated from Mozc person names whose reading is cheaper as a stem plus
/// particle, such as `tsugino → 調` against `次 + の`
public struct DeferredSystemCandidates: Sendable {
    private let keys: Set<String>

    public init(text: String = "") {
        var keys = Set<String>()
        for line in text.split(whereSeparator: \.isNewline) {
            let columns = line.split(separator: "\t", maxSplits: 1)
            guard columns.count == 2 else { continue }
            keys.insert(Self.key(String(columns[0]), String(columns[1])))
        }
        self.keys = keys
    }

    public func contains(reading: String, candidate: String) -> Bool {
        keys.contains(Self.key(reading, candidate))
    }

    private static func key(_ reading: String, _ candidate: String) -> String {
        reading + "\t" + candidate
    }
}
