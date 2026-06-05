#if canImport(UIKit)
import SwiftUI

// MARK: - JeniLine
//
// Per v5 §Calorie scan Screen 3: one-sentence Jeni interpretation
// line below the macros, with italic Fraunces on punch words and
// a heart as terminal punctuation per `feedback_voice_signals` lock.
// Cycle-aware / GLP-1-aware copy lands here when the upstream
// context flags are available.
//
// Examples (all generated server-side by GPT-5 + cuisine prompt,
// not composed in iOS):
//   "luteal-phase *wednesday*, the bowl's the right call. add the
//    chicken if it's there. ♥"
//   "matcha latte with oat — *easy yes* on the protein front. ♥"
//   "you have *room* today. easy yes."  ← pre-eat mode variant
//
// Voice locks (`feedback_voice_signals` + `feedback_post_ozempic_vocabulary`):
//   - italic Fraunces on punch word only (one per sentence ideally)
//   - lowercase casual everything else
//   - hearts as terminal punctuation only
//   - no "AI" / "deficit" / "crush" / "burn" / "earn it"

public struct JeniLine: View {

    public let copy: String
    public var alignment: TextAlignment

    public init(_ copy: String, alignment: TextAlignment = .leading) {
        self.copy = copy
        self.alignment = alignment
    }

    public var body: some View {
        let parsed = ItalicAccentText.parseAsterisks(copy)
        ItalicAccentText(
            parsed.base,
            italic: parsed.italic,
            baseFont: .custom("Fraunces72pt-Regular", size: 16),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
            color: FoodTheme.textPrimary,
            alignment: alignment
        )
        .lineSpacing(3)
        .accessibilityLabel(parsed.base)
    }
}

// MARK: - Preview

#Preview("JeniLine") {
    VStack(alignment: .leading, spacing: 20) {
        JeniLine("luteal-phase *wednesday*, the bowl's the right call. add the chicken if it's there. ♥")

        JeniLine("matcha latte with oat — *easy yes* on the protein front. ♥")

        JeniLine("you have *room* today. easy yes.")

        JeniLine("a higher week. *tomorrow* resets. ♥")
    }
    .padding()
    .background(FoodTheme.bgPrimary)
}

#endif  // canImport(UIKit)
