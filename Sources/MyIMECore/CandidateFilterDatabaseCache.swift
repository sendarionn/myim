public struct CandidateFilterDatabaseCache: Sendable {
    public private(set) var database: KanjiFilterDatabase
    private var signature: [String]
    private let bundledText: String
    private let store: CandidateFilterIDSStore?

    public init(bundledText: String, store: CandidateFilterIDSStore?) {
        self.bundledText = bundledText
        self.store = store
        database = KanjiFilterDatabase(
            text: bundledText,
            supplementalIDSTexts: store?.supplementalTexts() ?? []
        )
        signature = store?.signature() ?? []
    }

    public func loadDatabase() -> KanjiFilterDatabase {
        KanjiFilterDatabase(
            text: bundledText,
            supplementalIDSTexts: store?.supplementalTexts() ?? []
        )
    }

    public mutating func refreshIfChanged() {
        let currentSignature = store?.signature() ?? []
        guard currentSignature != signature else { return }
        database = loadDatabase()
        signature = currentSignature
    }

    public mutating func replace(with database: KanjiFilterDatabase) {
        self.database = database
        signature = store?.signature() ?? []
    }
}
