/// Input written as a time, `HH:MM` or `HHMM`, that `time.js` formats.
/// Only the shape is recognised here; whether the time is valid and how it
/// is written stay in `time.js`
public enum TimeShapedInput {
    public static func matches(_ input: String) -> Bool {
        let characters = Array(input)
        let digits: [Character]
        switch characters.count {
        case 5 where characters[2] == ":":
            digits = Array(characters[0..<2] + characters[3...])
        case 4:
            digits = characters
        default:
            return false
        }
        return digits.allSatisfy { $0.isASCII && $0.isNumber }
    }
}
