/// Keys that delete text, from the composition or in the application:
/// Delete and Forward Delete with any modifier, by character or by word,
/// and their Control-H and Control-D equivalents
public enum TextDeletionKey {
    public static func matches(keyCode: UInt16, control: Bool) -> Bool {
        switch keyCode {
        case 51, 117:
            true
        case 4, 2:
            control
        default:
            false
        }
    }
}
