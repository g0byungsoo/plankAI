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
    @State private var showShareSheet = false

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

            VStack(spacing: Space.lg) {
                Spacer()

                if showStats {
                    // Celebration + stats
                    celebrationEmoji
                        .transition(.scale.combined(with: .opacity))

                    Text(headline)
                        .font(Typo.title)
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
                            label: "FORM",
                            color: formScore >= 0.7 ? Palette.stateGood : Palette.stateWarn
                        )
                        scoreCard(
                            value: String(format: "%.0f%%", timeScore * 100),
                            label: "TIME",
                            color: timeScore >= 0.7 ? Palette.stateGood : Palette.stateWarn
                        )
                    }
                    .padding(.horizontal, Space.screenPadding)

                    // Stats row
                    HStack(spacing: Space.sm) {
                        StatCard(value: formatTime(holdTime), label: "HOLD TIME")
                        StatCard(value: "\(streakCount)", label: "STREAK")
                    }
                    .padding(.horizontal, Space.screenPadding)

                    // Day progress
                    Text("Day \(dayNumber) of 30 complete")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)

                    Spacer()

                    // Best roast
                    if let bestRoast = playedLines.first {
                        VStack(alignment: .leading, spacing: Space.xs) {
                            Text("BEST ROAST")
                                .font(Typo.caption)
                                .foregroundStyle(Palette.textSecondary)
                                .tracking(2)
                            Text("\"\(bestRoast)\"")
                                .font(Typo.body)
                                .foregroundStyle(Palette.textSecondary)
                                .italic()
                        }
                        .padding(Space.cardPadding)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Palette.bgElevated)
                        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
                        .plankShadow()
                        .padding(.horizontal, Space.screenPadding)
                    }

                    // CTAs
                    VStack(spacing: Space.sm) {
                        Button {
                            // TODO: UIActivityViewController with RoastCardView render
                            showShareSheet = true
                        } label: {
                            Text("SHARE")
                                .font(Typo.caption)
                                .fontWeight(.semibold)
                                .foregroundStyle(Palette.textPrimary)
                                .frame(maxWidth: .infinity)
                                .frame(height: Space.minTapTarget + 8)
                                .overlay(
                                    RoundedRectangle(cornerRadius: Radius.lg)
                                        .stroke(Palette.divider, lineWidth: 1)
                                )
                                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                        }

                        Button {
                            onDone()
                        } label: {
                            Text("DONE")
                                .font(Typo.body)
                                .fontWeight(.bold)
                                .foregroundStyle(Palette.textInverse)
                                .frame(maxWidth: .infinity)
                                .frame(height: Space.minTapTarget + 12)
                                .background(Palette.bgInverse)
                                .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
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
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showStats = true
                }
            }
        }
    }

    // MARK: - Components

    private var celebrationEmoji: some View {
        Text(qualityScore >= 7.0 ? "🔥" : qualityScore >= 4.0 ? "😤" : "😅")
            .font(.system(size: 64))
    }

    private var headline: String {
        if qualityScore >= 7.0 { return "Crushed it." }
        if qualityScore >= 4.0 { return "Survived." }
        return "It happened."
    }

    private var summaryText: String {
        if qualityScore >= 7.0 { return "Your form was solid. Your core felt that." }
        if qualityScore >= 4.0 { return "Your hips dropped a few times but you held it. Barely." }
        return "We're not gonna talk about it. Tomorrow's a new day."
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
                .font(Typo.title)
                .foregroundStyle(color)
            Text(label)
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .tracking(1)
        }
        .frame(maxWidth: .infinity)
        .padding(Space.cardPadding)
        .background(Palette.bgElevated)
        .clipShape(RoundedRectangle(cornerRadius: Radius.md))
        .plankShadow()
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        if seconds >= 60 { return "\(seconds / 60)m \(seconds % 60)s" }
        return "\(seconds)s"
    }
}
