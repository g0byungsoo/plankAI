#if canImport(UIKit)
import SwiftUI

// MARK: - ItalicAccentText
//
// Renders a base string with selected substrings in Fraunces italic
// for editorial emphasis ("around *480*, give or take a slice").
// Mirrors PlankApp/DesignSystem/Components.swift's ItalicAccentText
// — small enough to duplicate vs extracting a shared design package
// (v3 D27 "no abstraction until 3+ examples" rule applies).
//
// Implementation: Text concatenation via `+` preserves per-fragment
// fonts and produces a single layout-aware Text node, avoiding the
// wrapping artifacts that an HStack of Texts would create.
//
// Font resolution: at runtime SwiftUI looks up custom fonts from any
// loaded bundle. PlankApp ships Fraunces72pt-* in its Info.plist;
// PlankFood references the same names. In Xcode SwiftUI Previews
// running from the package alone the fonts fall back to system —
// acceptable preview behavior.

public struct ItalicAccentText: View {

    public let base: String
    public let italic: [String]
    public var baseFont: Font
    public var italicFont: Font
    public var color: Color
    public var alignment: TextAlignment

    public init(
        _ base: String,
        italic: [String],
        baseFont: Font = .custom("Fraunces72pt-Regular", size: 16),
        italicFont: Font = .custom("Fraunces72pt-SemiBoldItalic", size: 16),
        color: Color = FoodTheme.textPrimary,
        alignment: TextAlignment = .leading
    ) {
        self.base = base
        self.italic = italic
        self.baseFont = baseFont
        self.italicFont = italicFont
        self.color = color
        self.alignment = alignment
    }

    public var body: some View {
        composed
            .foregroundStyle(color)
            .multilineTextAlignment(alignment)
    }

    // MARK: - Composition

    private var composed: Text {
        var output = Text("")
        var cursor = base.startIndex
        let end = base.endIndex

        while cursor < end {
            // Find the earliest italic substring at or after cursor.
            // First-match wins so callers can pass overlapping
            // candidates safely.
            var earliest: (range: Range<String.Index>, term: String)?
            for term in italic {
                guard let range = base.range(of: term, range: cursor..<end) else { continue }
                if earliest == nil || range.lowerBound < earliest!.range.lowerBound {
                    earliest = (range, term)
                }
            }

            if let (range, term) = earliest {
                if range.lowerBound > cursor {
                    let prefix = String(base[cursor..<range.lowerBound])
                    output = output + Text(prefix).font(baseFont)
                }
                output = output + Text(term).font(italicFont)
                cursor = range.upperBound
            } else {
                let remainder = String(base[cursor..<end])
                output = output + Text(remainder).font(baseFont)
                cursor = end
            }
        }
        return output
    }
}

// MARK: - Convenience for inline *asterisk* markers
//
// Many result-card copy strings are written as "around *480*, give
// or take a slice" where the asterisks delimit the italic substring.
// `ItalicAccentText.fromMarkdownish(...)` parses those out so callers
// don't have to construct the italic array manually.

public extension ItalicAccentText {

    /// Parse a string like "around *480*, give or take a slice" into
    /// (cleaned base, list of italic substrings). Asterisks are
    /// removed from the output string; the substrings between them
    /// become the italic candidates.
    static func parseAsterisks(_ raw: String) -> (base: String, italic: [String]) {
        var base = ""
        var italic: [String] = []
        var inItalic = false
        var current = ""

        for ch in raw {
            if ch == "*" {
                if inItalic && !current.isEmpty {
                    italic.append(current)
                }
                base.append(current)
                current = ""
                inItalic.toggle()
            } else {
                current.append(ch)
            }
        }
        base.append(current)
        return (base, italic)
    }
}

#endif  // canImport(UIKit)
