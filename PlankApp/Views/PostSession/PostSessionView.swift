import SwiftUI

/// Post-session celebration + stats screen.
struct PostSessionView: View {
    let holdTime: TimeInterval
    let qualityScore: Double
    let dayNumber: Int
    let streakCount: Int
    let previousScore: Double?
    let playedLines: [String]
    let onDone: () -> Void

    @State private var showStats = false

    /// 2026-05-30 (epic #1 child #6): review prompt sentiment sheet.
    /// Fires once per install for users completing a plank session with
    /// hold ≥45s. The RatingPromptService.isEligible check handles the
    /// per-trigger lifetime flag + 30-day soft cooldown. For existing
    /// v1.0.6 users on update, this captures the next ≥45s PR session
    /// — a fresh peak-end moment for an honest review.
    @State private var showReviewSheet = false
    @Environment(\.openURL) private var openURL

    // Phase 16 — celebration scatter (HIGH treatment, 6 stickers,
    // 1 line-art / 5 painterly). Margins only — never on the centered
    // stat cards or score breakdowns.
    private static let celebrationPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.08, y: 0.08),
                         size: 28, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .bowIridescent,
                         position: CGPoint(x: 0.92, y: 0.08),
                         size: 36, rotation: 12, phaseDelay: 0.18),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.08, y: 0.45),
                         size: 32, rotation: 9, phaseDelay: 0.36),
        StickerPlacement(sticker: .gummyBear,
                         position: CGPoint(x: 0.94, y: 0.42),
                         size: 36, rotation: -10, phaseDelay: 0.55),
        StickerPlacement(sticker: .strawberry,
                         position: CGPoint(x: 0.10, y: 0.92),
                         size: 30, rotation: 13, phaseDelay: 0.72),
        StickerPlacement(sticker: .teddyPink,
                         position: CGPoint(x: 0.92, y: 0.94),
                         size: 38, rotation: -11, phaseDelay: 0.90),
    ]

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            StickerScatter(placements: Self.celebrationPlacements)

            // Fireworks Lottie burst — kicks in once the stats reveal
            // (1.2s after appearance) so it lands with the haptic + spring.
            if showStats {
                LottieEffectView(.fireworks, loop: false)
                    .frame(maxWidth: .infinity)
                    .frame(height: 320)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, Space.xl)
                    .allowsHitTesting(false)
            }

            // Sparkling-hearts as a secondary effect when the user crushed it.
            if showStats && qualityScore >= 7.0 {
                LottieEffectView(.sparklingHearts, loop: false)
                    .frame(width: 240, height: 240)
                    .allowsHitTesting(false)
            }

            VStack(spacing: Space.lg) {
                Spacer()

                if showStats {
                    // Celebration + stats
                    celebrationEmoji
                        .transition(.scale.combined(with: .opacity))

                    Text(headline)
                        .font(Typo.titleItalic)
                        .foregroundStyle(Palette.textPrimary)
                        .transition(.opacity)

                    Text(summaryText)
                        .font(Typo.body)
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)

                    // Score breakdown
                    HStack(spacing: Space.sm) {
                        scoreCard(
                            value: String(format: "%.0f%%", formScore * 100),
                            label: "form",
                            color: formScore >= 0.7 ? Palette.stateGood : Palette.stateWarn
                        )
                        scoreCard(
                            value: String(format: "%.0f%%", timeScore * 100),
                            label: "time",
                            color: timeScore >= 0.7 ? Palette.stateGood : Palette.stateWarn
                        )
                    }
                    .padding(.horizontal, Space.screenPadding)

                    // Stats row
                    HStack(spacing: Space.sm) {
                        StatCard(value: formatTime(holdTime), label: "hold time")
                        StatCard(value: "\(streakCount)", label: "streak")
                    }
                    .padding(.horizontal, Space.screenPadding)

                    // Day progress
                    Text("day \(dayNumber) of 30 complete")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)

                    Spacer()

                    // Best roast
                    if let bestRoast = playedLines.first {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("best roast")
                                .font(Typo.eyebrow).tracking(2)
                                .foregroundStyle(Palette.textSecondary)
                            Text("\"\(bestRoast)\"")
                                .font(Typo.body)
                                .foregroundStyle(Palette.textSecondary)
                                .italic()
                        }
                        .padding(Space.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            ZStack {
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Palette.accent.opacity(0.15))
                                    .offset(x: 4, y: 4)
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .fill(Palette.bgElevated)
                                RoundedRectangle(cornerRadius: 22, style: .continuous)
                                    .stroke(Palette.divider, lineWidth: 1.5)
                            }
                        )
                        .padding(.horizontal, Space.screenPadding)
                    }

                    // CTAs
                    VStack(spacing: Space.sm) {
                        ShareLink(item: shareMessage) {
                            Text("share")
                                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                                .foregroundStyle(Palette.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: Space.minTapTarget + 8)
                                .overlay(
                                    Capsule()
                                        .stroke(Palette.divider, lineWidth: 1.5)
                                )
                        }
                        .simultaneousGesture(TapGesture().onEnded { Haptics.light() })

                        Button {
                            onDone()
                        } label: {
                            HStack {
                                Text("done")
                                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 22))
                                Spacer()
                                Image(systemName: "arrow.right")
                                    .font(.system(size: 16, weight: .bold))
                            }
                            .foregroundStyle(Palette.textInverse)
                            .padding(.horizontal, 22)
                            .frame(height: 60)
                            .background(Palette.bgInverse)
                            .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, Space.screenPadding)
                    .padding(.bottom, Space.lg)
                }
            }
        }
        .onAppear {
            Haptics.success()
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                Haptics.heavy()
                withAnimation(Motion.gentleSpring) {
                    showStats = true
                }
            }
            // After the celebration peak (~2.5s) — Kahneman peak-end:
            // the review prompt lands at the dopamine apex, not when
            // the user is reaching to dismiss the screen. Conditional
            // gates: hold ≥45s (the spec threshold for "real session"),
            // RatingPromptService eligibility (per-install flag +
            // 30-day cooldown + legacy onboarding-prompt back-compat).
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                if holdTime >= 45 &&
                   RatingPromptService.shared.isEligible(for: .sessionThreePR) {
                    RatingPromptService.shared.markShown(.sessionThreePR)
                    showReviewSheet = true
                }
            }
        }
        .sheet(isPresented: $showReviewSheet) {
            PreReviewSentimentSheet(
                title: "the workout",
                message: "a quick rating helps other women find us, and keeps the app independent.",
                onYes: {
                    RatingPromptService.shared.trackSentimentResult(
                        trigger: .sessionThreePR, sentimentYes: true)
                    RatingPromptService.shared.presentSystemReviewSheet()
                },
                onNotYet: {
                    RatingPromptService.shared.trackSentimentResult(
                        trigger: .sessionThreePR, sentimentYes: false)
                    // Slot 2 routes "not yet" users to FeedbackView via
                    // mailto so the dissatisfied user has somewhere to
                    // vent without burning a real review slot.
                    if let url = URL(string: "mailto:support@jenifit.app?subject=jenifit%20feedback") {
                        openURL(url)
                    }
                },
                onDismiss: { showReviewSheet = false }
            )
        }
    }

    // MARK: - Components

    private var celebrationEmoji: some View {
        Text(qualityScore >= 7.0 ? "🔥" : qualityScore >= 4.0 ? "😤" : "😅")
            .font(.system(size: 64))
    }

    private var headline: String {
        if qualityScore >= 7.0 { return "crushed it." }
        if qualityScore >= 4.0 { return "survived." }
        return "it happened."
    }

    private var summaryText: String {
        if qualityScore >= 7.0 { return "your form was solid. your core felt that." }
        if qualityScore >= 4.0 { return "your hips dropped a few times but you held it. barely." }
        return "we're not gonna talk about it. tomorrow's a new day."
    }

    private var shareMessage: String {
        let seconds = Int(holdTime.rounded())
        let emoji = qualityScore >= 7.0 ? "🔥" : qualityScore >= 4.0 ? "😤" : "😅"
        let streakSuffix = streakCount > 1 ? ", \(streakCount)-day streak" : ""
        return "day \(dayNumber) done — \(seconds)s plank\(streakSuffix) \(emoji) jenifit"
    }

    /// Form score = % of hold time with good form (the 70% weight component)
    private var formScore: Double {
        guard holdTime > 0 else { return 0 }
        // qualityScore = (formRatio * 0.7 + timeRatio * 0.3) * 10
        // Approximate form ratio from quality score
        return min(qualityScore / 10.0, 1.0)
    }

    /// Time score = hold time / target time
    private var timeScore: Double {
        min(holdTime / 60.0, 1.0)
    }

    private func scoreCard(value: String, label: String, color: Color) -> some View {
        VStack(spacing: Space.xs) {
            Text(value)
                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                .foregroundStyle(color)
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.cardPadding)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(color.opacity(0.18))
                    .offset(x: 4, y: 4)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Palette.bgElevated)
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(color, lineWidth: 1.5)
            }
        )
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        if seconds >= 60 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds)s"
    }
}
