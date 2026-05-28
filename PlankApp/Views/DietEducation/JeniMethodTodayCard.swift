import SwiftUI

/// Surfaces the next available lesson of The JeniFit Method on the home
/// screen. Phase 3 of docs/diet_education_plan.md.
///
/// Tap opens `JeniMethodLessonView` as a dismissable sheet (locked
/// decision #5 — the card never auto-opens). Visibility is decided
/// upstream by HomeView via `JeniMethodState.todaysLessonForCard()` plus
/// the feature flag + goal-gate. When no lesson is due, the caller wraps
/// this view in `if let ... { ... }` so nothing is rendered — no
/// spacer, no padding, zero layout shift on completed/no-lesson days.
///
/// Visual: scrapbook chrome (24pt corners, 1.5pt accent border, hard
/// offset shadow) matching Home / Settings / Becoming-tab modules.
/// Accessibility: combine-children element with a single composed label
/// + hint, so VoiceOver reads the card as one tappable summary.
struct JeniMethodTodayCard: View {
    let lessonId: Int
    let teaser: String        // typically the lesson's learnHeadline
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: Space.xs) {
                Text("the jenifit method")
                    .font(Typo.eyebrow)
                    .foregroundStyle(Palette.textSecondary)
                Text(teaser)
                    .font(Typo.heading)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.leading)
                Text("lesson \(lessonId) of 5")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.top, 2)
            }
            .padding(Space.cardPadding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: Radius.lg)
                    .stroke(Palette.accent.opacity(0.6), lineWidth: 1.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
            .shadow(color: Palette.bgInverse.opacity(0.15), radius: 0, x: 3, y: 3)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("The JeniFit Method, lesson \(lessonId) of 5: \(teaser)")
        .accessibilityHint("Opens today's lesson")
    }
}

#if DEBUG
#Preview("Lesson 2 and Lesson 5") {
    VStack(spacing: 20) {
        JeniMethodTodayCard(
            lessonId: 2,
            teaser: "muscle is the prize.",
            onTap: {}
        )
        JeniMethodTodayCard(
            lessonId: 5,
            teaser: "trust the trend.",
            onTap: {}
        )
    }
    .padding()
    .background(Palette.bgPrimary)
}
#endif
