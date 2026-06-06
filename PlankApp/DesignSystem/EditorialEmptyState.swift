import SwiftUI

/// v1.0.7 aggressive Gen-Z luxury — editorial empty state
/// (docs/aggressive_genz_luxury_2026_06_06.md §6 "Empty state design").
///
/// The 2026 brief explicitly rejects illustrated empty states:
///   > "Custom illustrated empty states cost design effort to maintain
///   >  and instantly date the app. Editorial empty states age the way
///   >  magazines age — slowly, gracefully, in their favor."
///
/// The locked pattern is:
///   1. 80% whitespace minimum (use ample vertical padding at the
///      call site — this view itself just lays out the marks).
///   2. One italic Fraunces line + one DM Sans CTA line. Never more.
///   3. Optional: one signature sticker at 28pt (top-right).
///   4. 24pt-wide 0.5pt jeweledRose hairline below the CTA — the
///      "section break" signature mark.
///   5. No hero illustration, no animated character, no progress
///      placeholder.
///
/// Voice signal locks: italic Fraunces on the punch word only,
/// lowercase casual, hearts ♥ as terminal punctuation only.
struct EditorialEmptyState: View {
    /// The italic-Fraunces opening line (e.g. "the page is open.").
    /// Pass without quotes; the view renders in 28pt Fraunces italic.
    let headline: String

    /// The DM Sans CTA / hint line below the headline (e.g.
    /// "tap to log your first plate.").
    let cta: String

    /// Optional signature sticker, rendered at its locked size +
    /// rotation in the top-right corner. Must be a member of
    /// `StickerName.signature`; passing an archived sticker
    /// debug-asserts via `canonicalPlacement`.
    let sticker: StickerName?

    init(
        headline: String,
        cta: String,
        sticker: StickerName? = nil
    ) {
        self.headline = headline
        self.cta = cta
        self.sticker = sticker
    }

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 8) {
                Text(headline)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 28))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(cta)
                    .font(Typo.body)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Rectangle()
                    .fill(Palette.jeweledRose.opacity(0.4))
                    .frame(width: 24, height: 0.5)
                    .padding(.top, 16)
            }

            Spacer(minLength: 0)

            if let sticker, let placement = sticker.canonical {
                Image(sticker.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: placement.size, height: placement.size)
                    .opacity(sticker.style.opacity)
                    .accessibilityHidden(true)
            }
        }
        .padding(.vertical, Space.lg)
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(headline) \(cta)")
    }
}

#if DEBUG
#Preview("Becoming Ch II — no food") {
    EditorialEmptyState(
        headline: "the page is open.",
        cta: "tap to log your first plate.",
        sticker: .cherries
    )
    .padding(.horizontal, 20)
    .background(Palette.bgPrimary)
}

#Preview("Becoming Ch IV — no progress") {
    EditorialEmptyState(
        headline: "the shape is forming.",
        cta: "two more weeks and we'll show you.",
        sticker: .bowSatin
    )
    .padding(.horizontal, 20)
    .background(Palette.bgPrimary)
}

#Preview("Becoming Ch I — no weight logs") {
    EditorialEmptyState(
        headline: "your week is unwritten.",
        cta: "log when you're ready.",
        sticker: .flower3D
    )
    .padding(.horizontal, 20)
    .background(Palette.bgPrimary)
}
#endif
