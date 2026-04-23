import SwiftUI

/// Post-session summary screen.
/// Shows stats, best roast, and share card selection.
struct PostSessionView: View {
    let holdTime: TimeInterval
    let qualityScore: Double
    let dayNumber: Int
    let streakCount: Int
    let previousScore: Double?
    let playedLines: [String]  // roast lines that played during the session

    @State private var selectedRoast: String?
    @State private var showShareSheet = false
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: Space.lg) {
            Spacer()

            // Emoji + headline
            Text("😤")
                .font(.system(size: 56))
            Text("Survived.")
                .font(Typo.title)
                .foregroundStyle(Palette.textPrimary)
            Text(summaryText)
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.lg)

            // Stats grid
            LazyVGrid(columns: [.init(), .init()], spacing: Space.sm) {
                StatCard(value: formatTime(holdTime), label: "HOLD TIME")
                StatCard(value: String(format: "%.1f", qualityScore), label: "CORE SCORE")
                StatCard(value: "\(streakCount)", label: "DAY STREAK")
                if let prev = previousScore {
                    let delta = qualityScore - prev
                    StatCard(
                        value: (delta >= 0 ? "+" : "") + String(format: "%.1f", delta),
                        label: "VS YESTERDAY"
                    )
                }
            }
            .padding(.horizontal, Space.screenPadding)

            Spacer()

            // Best roast recap
            if let bestRoast = playedLines.first {
                VStack(alignment: .leading, spacing: Space.sm) {
                    Text("BEST ROAST TODAY")
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

            // Actions
            VStack(spacing: Space.sm) {
                Button {
                    showShareSheet = true
                } label: {
                    Text("SHARE TO TIKTOK")
                        .font(Typo.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(Palette.textPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: Space.minTapTarget + 8)
                        .background(Palette.bgPrimary)
                        .overlay(
                            RoundedRectangle(cornerRadius: Radius.lg)
                                .stroke(Palette.divider, lineWidth: 1)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: Radius.lg))
                }

                Button {
                    dismiss()
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
        .background(Palette.bgPrimary)
    }

    private var summaryText: String {
        if qualityScore >= 7.0 {
            return "Solid session. Your form held up."
        } else if qualityScore >= 4.0 {
            return "Your hips dropped a few times but you held it together. Barely."
        } else {
            return "We'll pretend that didn't happen. See you tomorrow."
        }
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let seconds = Int(time)
        if seconds >= 60 {
            return "\(seconds / 60)m \(seconds % 60)s"
        }
        return "\(seconds)s"
    }
}
