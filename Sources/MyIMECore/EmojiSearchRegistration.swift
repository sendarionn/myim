import Foundation

/// The reading an emoji chosen from search results is registered under:
/// the letters typed for the search, never derived back from its display
public enum EmojiSearchRegistration {
    /// `typedInput` is the composition as typed, such as `neko` while the
    /// panel searches for ねこ; recent emojis chosen without a search and
    /// empty searches register nothing
    public static func reading(
        typedInput: String,
        conversionReading: String,
        isRecentEmoji: Bool
    ) -> String? {
        guard !isRecentEmoji,
              !typedInput.trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty else {
            return nil
        }
        let reading = CandidateSelectionReading.resolve(
            conversionReading: conversionReading,
            originalInput: typedInput
        )
        return reading.isEmpty ? nil : reading
    }
}
