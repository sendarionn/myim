/// Which reading F6 and F7 convert when the reading has an `ny` after a
/// vowel: the reading as typed first, then each further press of the same
/// key switches to the reading with ん + や行 and back, as `shinya` gives
/// しにゃ, しんや, しにゃ; switching between F6 and F7 keeps the reading.
/// The state belongs to the text it last produced for one reading, so it
/// starts over once the input, the selected candidate or the composition
/// changes
public struct MoraicNInputFormToggle: Sendable {
    private var reading: String?
    private var form: InputForm?
    private var text: String?
    private var usesMoraicN = false

    public init() {}

    /// The reading to convert for `form`; `selectedText` is the text the
    /// composition shows now
    public mutating func reading(
        for form: InputForm,
        of reading: String,
        selectedText: String?
    ) -> String {
        guard form == .hiragana || form == .fullWidthKatakana,
              let moraicN = RomajiCanonicalizer.moraicNBeforeYKanaInput(
                  from: reading
              ) else {
            reset()
            return reading
        }
        let continues = self.reading == reading
            && text != nil
            && text == selectedText
        if !continues {
            reset()
        } else if self.form == form {
            usesMoraicN.toggle()
        }
        self.reading = reading
        self.form = form
        return usesMoraicN ? moraicN : reading
    }

    /// The text shown for the reading `reading(for:of:selectedText:)` gave
    public mutating func didShow(_ text: String) {
        self.text = text
    }

    public mutating func reset() {
        self = MoraicNInputFormToggle()
    }
}
