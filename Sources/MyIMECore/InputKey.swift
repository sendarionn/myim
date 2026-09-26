public enum InputKey: Equatable, Sendable {
    case tab
    case space
    case leftArrow
    case rightArrow
    case downArrow
    case upArrow
    case returnKey
    case delete
    case escape
    case inputFormFunction
    case other

    public init(keyCode: UInt16) {
        switch keyCode {
        case 48:
            self = .tab
        case 49:
            self = .space
        case 123:
            self = .leftArrow
        case 124:
            self = .rightArrow
        case 125:
            self = .downArrow
        case 126:
            self = .upArrow
        case 36, 76:
            self = .returnKey
        case 51:
            self = .delete
        case 53:
            self = .escape
        case 97, 98, 100, 101, 109:
            self = .inputFormFunction
        default:
            self = .other
        }
    }
}
