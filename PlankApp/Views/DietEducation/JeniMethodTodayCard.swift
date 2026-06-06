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
        .padding(.vertical, Space.md)
        .frame(maxWidth: .infinity, alignment: .leading)
        // v1.0.7 aggressive Gen-Z luxury — scrapbook chrome stripped
        // per docs/aggressive_genz_luxury_2026_06_06.md §2:
        // > "JeniMethod card — kill the 24pt corners + 1.5pt accent
        // >  border + offset shadow. The lesson IS the chrome. Acne
        // >  Paper doesn't put borders around its essays."
        // Cocoa pill CTA stays (brand-lock). Ribbon-lineart sticker
        // retired per the §6 12→5 curation (kept signatures: bowSatin,
        // heartGlossy, flower3D, sparkleGlossy, cherries). Hairline
        // rules above + below mark the section editorially without
        // the carded register.
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Palette.divider)
                .frame(height: 0.5)
        }
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Palette.divider)
                .frame(height: 0.5)
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
