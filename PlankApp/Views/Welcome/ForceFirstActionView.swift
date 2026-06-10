import SwiftUI
import PlankFood
import SwiftData
import PlankSync

// MARK: - ForceFirstActionView
//
// Per v5 D38 + §1 New user journey: post-paywall picker that gives
// the user an explicit choice — food photo OR 4-min plank — before
// landing on Home. Closes the 38% post-paywall activation gap
// surfaced in the 2026-06-02 PostHog audit (23 of 37 paid users
// never started any session in their first 3 days).
//
// Two equal-weight CTAs + soft "not right now" skip. Per v5 D51,
// plank option = existing JeniFit plank session (sets the existing
// pendingPostRitualWorkoutLaunch flag HomeView already reads on
// appear). Food option = new pendingFoodScan flag HomeView reads
// + presents CaptureFlowView.
//
// Gated on FoodFlags.isEnabled — for users not in the food rail
// rollout cohort, this view is skipped entirely (PostPurchaseFlow
// finishes straight to Home). Means the picker only appears for
// the audience getting food-rail messaging anyway.

struct ForceFirstActionView: View {

    let onFood: () -> Void
    let onPlank: () -> Void
    let onSkip: () -> Void

    /// User's daily session-length preference from onboarding (5/7/10
    /// min). The plank row copy reads from this so the duration the
    /// user is promised matches what actually opens. Defaults to 7 to
    /// match the HomeView default; in practice almost every user has
    /// set this during onboarding so the default is rarely hit.
    @AppStorage("sessionLengthPref") private var sessionLengthPref = 7

    // v8 P8.6: program-day anchor lets the welcome read "day 1 of N"
    // where N is the user's CUSTOM program duration (never hardcode
    // 75 per [[project-program-duration-custom]]). Reads the active
    // ProgramPlanRecord just-in-time — by post-paywall the plan
    // already exists from onboarding enrollment.
    @Environment(\.modelContext) private var modelContext

    private var programTotalDays: Int? {
        let userId = AppSync.shared.currentUserId ?? ""
        guard !userId.isEmpty else { return nil }
        return ProgramService.shared.activePlan(userId: userId, in: modelContext)?.totalDays
    }

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            VStack(spacing: 8) {
                // v8 P8.6: program-day anchor replaces the inline emoji
                // "welcome 🌸" greeting. Eyebrow ties the moment to the
                // custom program the user just bought — falls back to
                // a quiet "welcome" line when no plan record yet exists.
                Text(eyebrowCopy)
                    .font(Typo.eyebrow)
                    .tracking(2)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.accent)
                // v3 P11.6 (2026-06-10) — promoted to heroHeadline
                // 42pt per the locked typography ladder. Post-purchase
                // food-vs-plank picker is a hero choice screen.
                ItalicAccentText("let's start.",
                                 italic: ["start"],
                                 baseFont: Typo.heroHeadline,
                                 italicFont: Typo.heroHeadlineItalic,
                                 alignment: .center)
                    .kerning(-0.4)
                    .lineSpacing(Typo.heroHeadlineLineGap)
            }
            .multilineTextAlignment(.center)

            // v8 P8.6 — no em-dashes between words per
            // [[feedback-no-em-dash]]. Period-only register reads as
            // the same voice as the home rail rows.
            Text("pick one to start.\nthat's the whole thing.")
                .font(.system(size: 15))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.bottom, Space.sm)

            // Food option — sticker matches the home rail's snap row
            // (peach), so the user sees the same scrapbook mark here
            // that they'll see on tomorrow's PlanView.
            Button(action: onFood) {
                actionRow(
                    stickerAsset: StickerName.peach.assetName,
                    title: "log what you're eating",
                    subtitle: "(or about to eat)"
                )
            }
            .buttonStyle(.plain)

            // Plank option — opens today's existing JeniFit workout
            // session via the pendingPostRitualWorkoutLaunch flag.
            // Sticker matches the home rail's move row (balloon dog).
            Button(action: onPlank) {
                actionRow(
                    stickerAsset: StickerName.balloonDog.assetName,
                    title: "do today's \(sessionLengthPref)-min workout",
                    subtitle: "(today's session)"
                )
            }
            .buttonStyle(.plain)

            Spacer()

            // Period-only — no trailing arrow. Same register the
            // founder locked across PlanView's ghost links.
            Button(action: onSkip) {
                Text("not right now")
                    .font(.system(size: 14))
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(.bottom, Space.lg)
        }
        .padding(.horizontal, Space.screenPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        // Background lifted to PostPurchaseFlowView for stable cross-fade.
    }

    private var eyebrowCopy: String {
        if let totalDays = programTotalDays {
            return "DAY 1 OF \(totalDays)"
        }
        return "WELCOME"
    }

    @ViewBuilder
    private func actionRow(stickerAsset: String, title: String, subtitle: String) -> some View {
        HStack(spacing: Space.md) {
            Image(stickerAsset)
                .resizable()
                .scaledToFit()
                .frame(width: 44, height: 44)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.custom("Fraunces72pt-SemiBold", size: 17))
                    .foregroundStyle(Palette.textPrimary)
                Text(subtitle)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textSecondary)
            }

            Spacer(minLength: 0)

            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.cocoaSecondary)
        }
        .padding(Space.md)
        // v8 P8.6 — scrapbook chrome to match PlanView rows. White
        // card on pink canvas + soft accent stroke + paper shadow
        // = same family as the home rail.
        .background(
            RoundedRectangle(cornerRadius: Radius.programCard, style: .continuous)
                .fill(Palette.programCard)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Radius.programCard, style: .continuous)
                .stroke(Palette.accent.opacity(0.5), lineWidth: 1.5)
        )
        .programPaperShadow()
    }
}

#Preview("ForceFirstActionView") {
    ForceFirstActionView(
        onFood: { print("food") },
        onPlank: { print("plank") },
        onSkip: { print("skip") }
    )
}
