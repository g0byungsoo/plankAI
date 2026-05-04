import SwiftUI

/// Generates a 9:16 share card with the best roast from the session.
/// Rendered to UIImage via ImageRenderer for sharing to TikTok/IG Stories.
struct RoastCardView: View {
    let roastText: String
    let exerciseName: String
    let dayNumber: Int
    let holdTime: TimeInterval

    var body: some View {
        ZStack {
            Palette.bgPrimary

            VStack(spacing: Space.xl) {
                Spacer()

                // Quote
                VStack(spacing: Space.md) {
                    Text("\"")
                        .font(.system(size: 72, weight: .light))
                        .foregroundStyle(Palette.accent)
                        .offset(y: 20)

                    Text(roastText)
                        .font(Typo.heading)
                        .foregroundStyle(Palette.textPrimary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)
                }

                // Attribution
                Text("— Your Plank Coach, Day \(dayNumber)")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .italic()

                Spacer()

                // Stats bar
                HStack(spacing: Space.lg) {
                    VStack {
                        Text("\(Int(holdTime))s")
                            .font(Typo.heading)
                            .foregroundStyle(Palette.textPrimary)
                        Text("hold time")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }

                    Rectangle()
                        .fill(Palette.divider)
                        .frame(width: 1, height: 40)

                    VStack {
                        Text(exerciseName)
                            .font(Typo.heading)
                            .foregroundStyle(Palette.textPrimary)
                        Text("exercise")
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                    }
                }

                // Watermark
                Text("JeniFit")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary.opacity(0.5))
                    .padding(.bottom, Space.xl)
            }
        }
        .frame(width: 1080, height: 1920)
    }

    /// Render the card to a UIImage for sharing.
    @MainActor
    func renderToImage() -> UIImage? {
        let renderer = ImageRenderer(content: self)
        renderer.scale = 1.0
        return renderer.uiImage
    }
}
