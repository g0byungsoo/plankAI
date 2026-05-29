import SwiftUI

/// Surfaces the next available lesson of The JeniFit Method on the home
/// screen. Phase 3 of docs/diet_education_plan.md.
///
/// Tap opens `JeniMethodLessonView` as a dismissable sheet (locked
/// decision #5 — the card never auto-opens). Visibility is decided
/// upstream by HomeView via `JeniMethodState.lessonForCard(currentDay:)`
/// plus the feature flag + goal-gate. When no lesson is due, the caller wraps
/// this view in `if let ... { ... }` so nothing is rendered — no
/// spacer, no padding, zero layout shift on completed/no-lesson days.
///
/// Visual: scrapbook chrome (24pt corners, 1.5pt accent border, hard
/// offset shadow) matching Home / Settings / Becoming-tab modules.
/// Accessibility: combine-children element with a single composed label
/// + hint, so VoiceOver reads the card as one tappable summary.
struct JeniMethodTodayCard: View {
    let teaser: String        // typically the lesson's learnHeadline
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: Space.xs) {
            Text("the jenifit method")
                .font(Typo.eyebrow)
                .foregroundStyle(Palette.textSecondary)
                .accessibilityHidden(true)
            Text(teaser)
                .font(Typo.heading)
                .foregroundStyle(Palette.textPrimary)
                .multilineTextAlignment(.leading)

            // Only the pill is the CTA — the card itself is no longer
            // tappable, so the tap target is explicit (and leaves room for
            // a future swipe gesture on the card body). Cocoa pill + arrow
            // mirrors the workout card's "start" idiom; compact so it
            // doesn't compete with the full-width start CTA below it.
            Button(action: onTap) {
                HStack(spacing: 8) {
                    Text("today's lesson")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                    Image(systemName: "arrow.right")
                        .font(.system(size: 13, weight: .bold))
                }
                .foregroundStyle(Palette.textInverse)
                .padding(.horizontal, 18)
                .padding(.vertical, 11)
                .background(Palette.bgInverse)
                .clipShape(Capsule())
            }
            .buttonStyle(CardCTAPressStyle())
            .padding(.top, Space.sm)
            .accessibilityLabel("Open today's lesson: \(teaser)")
            .accessibilityHint("Opens the JeniFit Method lesson")
        }
        .padding(Space.cardPadding)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Palette.accentSubtle)
        .overlay(
            RoundedRectangle(cornerRadius: Radius.lg)
                .stroke(Palette.accent, lineWidth: 1.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
        .shadow(color: Palette.bgInverse.opacity(0.15), radius: 0, x: 3, y: 3)
        // Scrapbook sticker accent on the empty top-right of the card.
        // Line-art ribbon balances the painterly stickers elsewhere on
        // the screen. Applied after clipShape so it bleeds off-corner.
        .overlay(alignment: .topTrailing) {
            Image(StickerName.ribbonLineart.assetName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 50, height: 50)
                .rotationEffect(.degrees(10))
                .offset(x: 10, y: -16)
                .opacity(StickerName.ribbonLineart.style.opacity)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }
}

/// Light press feedback for the card's pill CTA — gentle scale + dim, in
/// the same restrained register as the rest of the home buttons.
private struct CardCTAPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1.0)
            .opacity(configuration.isPressed ? 0.92 : 1.0)
            .animation(Motion.tap, value: configuration.isPressed)
    }
}

#if DEBUG
#Preview("Lesson 2 and Lesson 5") {
    VStack(spacing: 20) {
        JeniMethodTodayCard(
            teaser: "muscle is the prize.",
            onTap: {}
        )
        JeniMethodTodayCard(
            teaser: "trust the trend.",
            onTap: {}
        )
    }
    .padding()
    .background(Palette.bgPrimary)
}
#endif
