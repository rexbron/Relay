import Foundation

extension Character {
    /// Whether this character is an emoji (including multi-scalar sequences like flags and skin tones).
    var isEmoji: Bool {
        guard let firstScalar = unicodeScalars.first else { return false }
        // Emoji presentation sequences or characters with explicit emoji presentation.
        if firstScalar.properties.isEmoji && firstScalar.properties.isEmojiPresentation {
            return true
        }
        // Characters that become emoji when followed by a variation selector (e.g. ©️, ®️, digit keycaps).
        if firstScalar.properties.isEmoji, unicodeScalars.count > 1 {
            return true
        }
        return false
    }
}

extension String {
    /// Whether this string contains only emoji characters (ignoring whitespace).
    /// Returns `false` for empty or whitespace-only strings.
    var isEmojiOnly: Bool {
        let stripped = filter { !$0.isWhitespace }
        guard !stripped.isEmpty else { return false }
        return stripped.allSatisfy(\.isEmoji)
    }

    /// The number of emoji characters in the string (ignoring whitespace).
    var emojiCount: Int {
        filter { !$0.isWhitespace }.filter(\.isEmoji).count
    }
}
