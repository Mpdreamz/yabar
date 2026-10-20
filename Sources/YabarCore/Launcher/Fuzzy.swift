/// Fuzzy matching for the launcher: the query's characters in order, anywhere in the text (`gst` finds "Ghostty —
/// ~/Projects"), scored so that what people mean comes first: a match at the start, at the start of words, and in
/// runs beats one scattered through the middle. Case is ignored.
public enum Fuzzy {
    /// The score of `query` in `text`, higher is better; nil when it does not match. An empty query matches everything
    /// with 0.
    public static func score(_ query: String, in text: String) -> Int? {
        let needle = Array(query.lowercased().filter { !$0.isWhitespace })
        guard !needle.isEmpty else { return 0 }
        let haystack = Array(text.lowercased())
        let original = Array(text)
        var score = 0
        var position = 0
        var previous = -2
        for character in needle {
            guard let found = haystack[position...].firstIndex(of: character) else { return nil }
            score += 1
            if found == previous + 1 { score += 5 } // a run
            if found == 0 { score += 10 } // the very start
            else if !original[found - 1].isLetter, !original[found - 1].isNumber { score += 8 } // a word's start
            else if original[found].isUppercase, original[found - 1].isLowercase { score += 6 } // camelCase
            score -= min(found - position, 10) / 3 // a gap
            previous = found
            position = found + 1
        }
        // A query that is the whole text, or its start, wins outright.
        let lowered = text.lowercased()
        let typed = query.lowercased()
        if lowered == typed {
            score += 50
        } else if lowered.hasPrefix(typed) {
            score += 25
        }
        return score
    }
}
