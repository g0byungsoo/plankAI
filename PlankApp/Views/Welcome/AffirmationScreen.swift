import SwiftUI

// MARK: - Copy
//
// Constants kept at file scope so v1.0.1 A/B tests can swap variants
// without touching the choreography. Three equal beats — same
// Fraunces SemiBold 28pt on every line so each fade-up reveals as
// a peer statement, not headline + finisher. Each line is its own
// Text view with its own visibility state so the choreography can
// land them as three distinct beats.

private let kAffirmationLine1 = "You made it here."
private let kAffirmationLine2 = "That already means something."
private let kAffirmationLine3 = "Let's go."

// MARK: - AffirmationScreen
//
// First-launch only. Renders before the onboarding Welcome screen
// when the @AppStorage("hasSeenAffirmation") flag is false.
//
// Choreography:
//   t=0.0  background fade in (0.4s)
//   t=0.3  sticker cascade begins, 0.1s between each
//   t=0.8  line 1 fade + scale 0.95→1.0 (0.6s ease-out)
//   t=2.0  line 2 fade + scale 0.95→1.0 (0.6s ease-out)
//   t=3.5  line 3 fade + scale 0.95→1.0 (0.6s ease-out)
//   t=5.0  hold; idle drift continues
//   t=5.5  auto-advance via onComplete()
//
// Tap anywhere on the cream surface skips to advance immediately.
// reduceMotion snaps everything to final state, holds 3s, advances.
//
// The flag is persisted at 1s for next-launch resilience (kill the
// app inside the first second and the affirmation re-shows). The
// parent gates on a @State copy of the flag captured at init time
// so the mid-flight write does NOT unmount this view.

struct AffirmationScreen: View {
    let onComplete: () -> Void

    @AppStorage("hasSeenAffirmation") private var hasSeenAffirmation = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bgVisible = false
    @State private var stickerRevealCount = 0
    @State private var line1Visible = false
    @State private var line2Visible = false
    @State private var line3Visible = false
    @State private var didAdvance = false

    // 10-sticker cluster — 3 top, 3 mid (left + right edges only,
    // never the center column where text lands), 4 bottom. Mix of
    // line-art and painterly per the sticker style spec. phaseDelay
    // values are unique 0.0…1.0 to give each sticker a distinct idle
    // drift period (Sticker derives wobble/float periods from it).
    private static let placements: [StickerPlacement] = [
        // Top
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.15, y: 0.10),
                         size: 38, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.50, y: 0.06),
                         size: 32, rotation: 12, phaseDelay: 0.10),
        StickerPlacement(sticker: .bowIridescent,
                         position: CGPoint(x: 0.85, y: 0.12),
                         size: 42, rotation: -14, phaseDelay: 0.20),
        // Mid edges (well outside any text line; centered text at 28pt
        // Fraunces only spans roughly x=0.20–0.80 of the screen width).
        StickerPlacement(sticker: .cameraLineart,
                         position: CGPoint(x: 0.08, y: 0.42),
                         size: 36, rotation: 9, phaseDelay: 0.30),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.93, y: 0.38),
                         size: 34, rotation: -8, phaseDelay: 0.40),
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.92, y: 0.62),
                         size: 40, rotation: 13, phaseDelay: 0.50),
        // Bottom
        StickerPlacement(sticker: .gummyBear,
                         position: CGPoint(x: 0.13, y: 0.85),
                         size: 44, rotation: 11, phaseDelay: 0.60),
        StickerPlacement(sticker: .cherries,
                         position: CGPoint(x: 0.45, y: 0.94),
                         size: 36, rotation: -10, phaseDelay: 0.70),
        StickerPlacement(sticker: .teddyPink,
                         position: CGPoint(x: 0.78, y: 0.86),
                         size: 42, rotation: 6, phaseDelay: 0.85),
        StickerPlacement(sticker: .strawberry,
                         position: CGPoint(x: 0.95, y: 0.93),
                         size: 32, rotation: -15, phaseDelay: 1.00),
    ]

    var body: some View {
        ZStack {
            Palette.bgPrimary
                .ignoresSafeArea()
                .opacity(bgVisible ? 1 : 0)

            GeometryReader { geo in
                ZStack {
                    ForEach(
                        Array(Self.placements.prefix(stickerRevealCount).enumerated()),
                        id: \.element.id
                    ) { _, p in
                        Sticker(placement: p)
                            .position(
                                x: p.position.x * geo.size.width,
                                y: p.position.y * geo.size.height
                            )
                    }
                }
            }
            .allowsHitTesting(false)

            VStack(spacing: 16) {
                Text(kAffirmationLine1)
                    .font(.custom("Fraunces72pt-SemiBold", size: 28))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(line1Visible ? 1 : 0)
                    .scaleEffect(line1Visible ? 1.0 : 0.95)

                Text(kAffirmationLine2)
                    .font(.custom("Fraunces72pt-SemiBold", size: 28))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(line2Visible ? 1 : 0)
                    .scaleEffect(line2Visible ? 1.0 : 0.95)

                Text(kAffirmationLine3)
                    .font(.custom("Fraunces72pt-SemiBold", size: 28))
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(line3Visible ? 1 : 0)
                    .scaleEffect(line3Visible ? 1.0 : 0.95)
            }
            .padding(.horizontal, Space.lg)
        }
        .contentShape(Rectangle())
        .onTapGesture { advanceNow() }
        .task { await runChoreography() }
    }

    // MARK: - Choreography

    @MainActor
    private func runChoreography() async {
        if reduceMotion {
            bgVisible = true
            stickerRevealCount = Self.placements.count
            line1Visible = true
            line2Visible = true
            line3Visible = true
            hasSeenAffirmation = true
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            advanceNow()
            return
        }

        // t=0 background fade
        withAnimation(.easeOut(duration: 0.4)) { bgVisible = true }

        // Concurrent legs of the timeline. async let keeps everything
        // structured under .task — if the view unmounts (tap-skip
        // flips the parent gate) the legs cancel cleanly via the
        // Task.sleep CancellationError path.
        async let _: Void = persistFlagAfterDelay()
        async let _: Void = cascadeStickers()
        async let _: Void = revealText()

        // Hold from t=3.5 (line 3 reveal start) → t=5.5 auto-advance
        try? await Task.sleep(nanoseconds: 5_500_000_000)
        advanceNow()
    }

    private func persistFlagAfterDelay() async {
        // 1s resilience: a kill within the first second re-shows the
        // affirmation on next launch. After that we mark it seen.
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        await MainActor.run { hasSeenAffirmation = true }
    }

    private func cascadeStickers() async {
        try? await Task.sleep(nanoseconds: 300_000_000) // t=0.3
        for _ in Self.placements.indices {
            await MainActor.run { stickerRevealCount += 1 }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    private func revealText() async {
        try? await Task.sleep(nanoseconds: 800_000_000) // t=0.8
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.6)) { line1Visible = true }
        }
        try? await Task.sleep(nanoseconds: 1_200_000_000) // → t=2.0
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.6)) { line2Visible = true }
        }
        try? await Task.sleep(nanoseconds: 1_500_000_000) // → t=3.5
        await MainActor.run {
            withAnimation(.easeOut(duration: 0.6)) { line3Visible = true }
        }
    }

    // MARK: - Advance

    @MainActor
    private func advanceNow() {
        guard !didAdvance else { return }
        didAdvance = true
        // Belt-and-suspenders flag write in case advance fires before
        // the 1s persist task did. Idempotent.
        hasSeenAffirmation = true
        Haptics.light()
        onComplete()
    }
}

// MARK: - Preview

#Preview {
    AffirmationScreen(onComplete: {})
}
