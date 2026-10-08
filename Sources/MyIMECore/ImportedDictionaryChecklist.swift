public struct ImportedDictionaryChecklistItem: Equatable, Sendable {
    public let filename: String
    public let isEnabled: Bool

    public init(filename: String, isEnabled: Bool) {
        self.filename = filename
        self.isEnabled = isEnabled
    }
}

public enum ImportedDictionaryChecklist {
    public static func items(
        dictionaries: [ImportedDictionary],
        disabledFilenames: Set<String>
    ) -> [ImportedDictionaryChecklistItem] {
        dictionaries.map {
            let filename = $0.fileURL.lastPathComponent
            return ImportedDictionaryChecklistItem(
                filename: filename,
                isEnabled: !disabledFilenames.contains(filename)
            )
        }
    }
}
