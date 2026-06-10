import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Replaces the legacy wordmark splash. Shown while AuthService.bootstrap()
// runs on every app launch (after onboarding completes, returning users
// see this for one or two frames; on a slow first launch it covers the
// anonymous sign-in round trip). Same job as the old AuthBootstrapSplash:
// passive view, parent unmounts when auth.isReady.
//
// v1.0.7 round 14 (founder feedback 2026-06-06): "i don't like this
// loading screen where it shows some ugly pink dot in the middle and
// only one sentence. can we try to make all loading look like
// [AffirmationScreen]?" The central pink bloom is gone; the single
// rotating quote is gone; this loader now mirrors AffirmationScreen's
// 3-beat cascade — three Fraunces lines fade in one by one over a
// denser 10-sticker scatter. When auth resolves quickly the parent
// unmounts mid-cascade; when it resolves slowly the cascade completes
// and the lines just hold (no rotation, no pulse, no central blob).

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var bgVisible = false
    @State private var stickerRevealCount = 0
    @State private var line1Visible = false
    @State private var line2Visible = false
    @State private var line3Visible = false
    @State private var triplet: (l1: String, l2: String, l3: String, italics: [String]) = ("", "", "", [])
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Three-line affirmation triplets — same voice + register as
    /// AffirmationScreen ("you made it here / that already means
    /// something / let's go"). One triplet picked per mount via
    /// .randomElement() so each launch can feel fresh on slow
    /// bootstraps. The last line carries the italic punch.
    private static let triplets: [(l1: String, l2: String, l3: String, italics: [String])] = [
        ("welcome back.",
         "she's already in you.",
         "let's go.",
         ["already", "let's go"]),
        ("today counts.",
         "small reps. real changes.",
         "show up.",
         ["real", "show up"]),
        ("your body.",
         "your pace.",
         "your week.",
         ["pace", "week"]),
        ("soft girl.",
         "strong body.",
         "still here.",
         ["strong", "still"]),
        ("you don't have to earn rest.",
         "slow days count too.",
         "trust the season.",
         ["earn", "count", "season"]),
        ("you already started.",
         "the rest is rhythm.",
         "let's go.",
         ["already", "rhythm", "let's go"]),
    ]

    // 10-sticker cluster mirroring AffirmationScreen exactly — 3 top,
    // 3 mid (edges only), 4 bottom. Edges only so the centered text
    // breathes through.
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
        // Mid edges
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
            // v8 P8.6: auth-bootstrap loader fires on every launch (not
            // just first install) — conditional helper picks pink only
            // for program-era users so legacy users keep cream.
            Palette.programEraBg
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
                Spacer()

                // v3 P11.6 (2026-06-10) — promoted from questionHero
                // 34pt to heroHeadline 42pt per [[feedback-hero-
                // typography-ladder]]. AffirmationLoader is a hero
                // moment (post-purchase choreography), not an in-
                // question header.
                ItalicAccentText(
                    triplet.l1,
                    italic: triplet.italics,
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .opacity(line1Visible ? 1 : 0)
                .scaleEffect(line1Visible ? 1.0 : 0.95)

                ItalicAccentText(
                    triplet.l2,
                    italic: triplet.italics,
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .kerning(-0.4)
                .lineSpacing(Typo.heroHeadlineLineGap)
                .opacity(line2Visible ? 1 : 0)
                .scaleEffect(line2Visible ? 1.0 : 0.95)

                // Line 3 promoted to all-italic — JeniFit voice signal
                // (italic = the punch). Same hand as AffirmationScreen's
                // closer.
                Text(triplet.l3)
                    .font(Typo.heroHeadlineItalic)
                    .kerning(-0.4)
                    .foregroundStyle(Palette.textPrimary)
                    .multilineTextAlignment(.center)
                    .opacity(line3Visible ? 1 : 0)
                    .scaleEffect(line3Visible ? 1.0 : 0.95)

                Spacer()

                bottomContent
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, Space.lg)
        }
        .task { await runChoreography() }
    }

    /// Bottom-row content — only the failure state shows a CTA. The
    /// running state used to show 3 pulsing dots; that's gone now to
    /// match AffirmationScreen's "no spinner" register.
    @ViewBuilder
    private var bottomContent: some View {
        switch state {
        case .idle, .running, .ready:
            EmptyView()
        case .failed(let message):
            VStack(spacing: Space.md) {
                (
                    Text("couldn't ").font(.custom("Fraunces72pt-SemiBold", size: 18)) +
                    Text("connect.").font(.custom("Fraunces72pt-SemiBoldItalic", size: 18))
                )
                .foregroundStyle(Palette.textPrimary)

                Text(message)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)

                Button(action: onRetry) {
                    Text("try again")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 16))
                        .foregroundStyle(Palette.textInverse)
                        .frame(width: 160, height: 44)
                        .background(Palette.bgInverse)
                        .clipShape(Capsule())
                }
                .padding(.top, Space.xs)
            }
            .padding(.horizontal, Space.lg)
        }
    }

    @MainActor
    private func runChoreography() async {
        triplet = Self.triplets.randomElement() ?? Self.triplets[0]

        if reduceMotion {
            bgVisible = true
            stickerRevealCount = Self.placements.count
            line1Visible = true
            line2Visible = true
            line3Visible = true
            return
        }

        // t=0 background fade
        withAnimation(Motion.entranceSoft) { bgVisible = true }

        async let _: Void = cascadeStickers()
        async let _: Void = revealText()
    }

    /// Same sticker cascade rate as AffirmationScreen — 100ms between
    /// reveals so the whole scatter is in by t≈1.0s.
    private func cascadeStickers() async {
        try? await Task.sleep(nanoseconds: 300_000_000) // t=0.3
        for _ in Self.placements.indices {
            await MainActor.run { stickerRevealCount += 1 }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    /// Slightly tighter cadence than AffirmationScreen since this is a
    /// transient loader, not a 5.5s ceremony — but still 3 distinct
    /// beats so the eye reads them as peer statements, not a
    /// headline + finisher. If auth resolves before the cascade
    /// completes, the parent unmounts and the in-flight Task gets
    /// cancelled (Task.sleep CancellationError path).
    private func revealText() async {
        try? await Task.sleep(nanoseconds: 500_000_000) // t=0.5
        await MainActor.run {
            withAnimation(Motion.entrance) { line1Visible = true }
        }
        try? await Task.sleep(nanoseconds: 900_000_000) // → t=1.4
        await MainActor.run {
            withAnimation(Motion.entrance) { line2Visible = true }
        }
        try? await Task.sleep(nanoseconds: 1_000_000_000) // → t=2.4
        await MainActor.run {
            withAnimation(Motion.entrance) { line3Visible = true }
        }
    }
}

#Preview("Running") {
    AffirmationLoaderScreen(state: .running, onRetry: {})
}

#Preview("Failed") {
    AffirmationLoaderScreen(
        state: .failed("Make sure you're connected to the internet, then try again."),
        onRetry: {}
    )
}
