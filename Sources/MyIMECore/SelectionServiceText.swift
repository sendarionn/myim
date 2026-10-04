public enum SelectionServiceText {
    public static func received(_ value: String?) -> String? {
        guard let value, !value.isEmpty else { return nil }
        return value
    }
}
