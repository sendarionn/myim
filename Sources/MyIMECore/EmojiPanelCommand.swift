public enum EmojiPanelCommand: Equatable, Sendable {
    case moveSelection(backward: Bool)

    public init?(selectorName: String) {
        switch selectorName {
        case "insertTab:", "insertTabIgnoringFieldEditor:":
            self = .moveSelection(backward: false)
        case "insertBacktab:", "insertBacktabIgnoringFieldEditor:":
            self = .moveSelection(backward: true)
        default:
            return nil
        }
    }
}
