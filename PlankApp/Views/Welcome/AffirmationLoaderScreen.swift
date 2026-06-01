import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Replaces the legacy wordmark splash. Shown while AuthService.bootstrap()
// runs on every app launch (after onboarding completes, returning users
// see this for one or two frames; on a slow first launch it covers the
// anonymous sign-in round trip). Same job as the old AuthBootstrapSplash:
// passive view, parent unmounts when auth.isReady.
//
// Tone: a single short Fraunces quote on cream + a light 4-sticker
// scatter. No wordmark — the brand carries through the typography and
// sticker language alone, so users open the app to an affirmation
// instead of a logo. Error state still surfaces a retry button under
// the quote.
//
// One quote is picked per mount via .randomElement() so a fast bootstrap
// shows a different quote on each launch. The pool is intentionally
// short and rewriteable — these are the same voice the AffirmationScreen
// uses on first launch (calm, empowering, present-tense).

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var quoteIndex: Int = 0
    @State private var quoteVisible = false
    @State private var stickerRevealCount = 0
    @State private var pulse = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    // Central breathing bloom — three concentric soft pink circles that
    // pulse 3.5s in/out. v1.0.7: replaces the prior static-center
    // composition that read as "nothing is happening" on cold-launch
    // boots where auth bootstrap takes 1-3s. Modern aesthetic apps
    // (Calm, Headspace) use continuous gentle motion to fill the
    // loading void; the bloom is JeniFit's version of that, on-brand
    // with the BreathworkSessionView circle pattern users already see.
    @State private var bloomScale: CGFloat = 0.92
    @State private var bloomVisible = false

    /// Each quote pairs the line with the word(s) to render in italic
    /// Fraunces — JeniFit voice signal (italic = the punch). All quotes
    /// stay short + present-tense; the italic carries the emphasis.
    private static let quotes: [(line: String, italics: [String])] = [
        ("She's already in you.",          ["already"]),
        ("Soft girl. Strong body.",        ["Strong"]),
        ("Show up. That's the whole thing.", ["whole"]),
        ("Your body, your pace.",          ["pace"]),
        ("Small reps. Real changes.",      ["Real"]),
        ("You don't have to earn rest.",   ["earn"]),
        ("Slow days count too.",           ["count"]),
        ("Today counts.",                   ["Today"]),
        ("You already started.",            ["already"]),
        ("Trust the season.",               ["season"]),
    ]

    // 4-sticker scatter. Edges only so the centered quote breathes.
    // Mix of two line-art (opacity 1.0) and two painterly (opacity 0.85)
    // per the sticker style convention. Distinct phaseDelay values give
    // each sticker its own idle drift period.
    private static let placements: [StickerPlacement] = [
        StickerPlacement(sticker: .heartsLineart,
                         position: CGPoint(x: 0.16, y: 0.18),
                         size: 34, rotation: -10, phaseDelay: 0.00),
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.86, y: 0.22),
                         size: 32, rotation: 12, phaseDelay: 0.30),
        StickerPlacement(sticker: .bowIridescent,
                         position: CGPoint(x: 0.18, y: 0.80),
                         size: 38, rotation: 8, phaseDelay: 0.55),
        StickerPlacement(sticker: .flower3D,
                         position: CGPoint(x: 0.84, y: 0.84),
                         size: 36, rotation: -12, phaseDelay: 0.80),
    ]

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            // Central breathing bloom — sits BEHIND the quote, soft pink
            // pulse that gives the eye a focal point while auth resolves.
            centralBloom

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

            VStack(spacing: Space.lg) {
                Spacer()

                ItalicAccentText(
                    Self.quotes[quoteIndex].line,
                    italic: Self.quotes[quoteIndex].italics,
                    baseFont: .custom("Fraunces72pt-SemiBold", size: 28),
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 28),
                    color: Palette.textPrimary,
                    alignment: .center
                )
                .padding(.horizontal, Space.lg)
                .opacity(quoteVisible ? 1 : 0)
                .scaleEffect(quoteVisible ? 1.0 : 0.95)
                // .id() ties the transition to the index so each rotated
                // quote gets a fresh fade-in tree instead of crossfading
                // text glyphs (which can look jumpy with italics).
                .id(quoteIndex)

                Spacer()

                bottomContent
                    .padding(.bottom, 60)
            }
        }
        .task { await runChoreography() }
    }

    // MARK: - Central bloom

    /// Three concentric soft pink circles with a continuous breath cycle.
    /// Sits behind the quote at screen center. Blur on the outer rings
    /// makes them read as a glow rather than discrete shapes — same
    /// approach as the BreathworkSessionView's BreathCircle, scaled
    /// smaller for the loader's quieter register. Reduce-motion holds
    /// the bloom at its mid scale (still visible, no animation).
    private var centralBloom: some View {
        ZStack {
            Circle()
                .fill(Palette.accent.opacity(0.07))
                .frame(width: 220, height: 220)
                .scaleEffect(bloomScale)
                .blur(radius: 24)
            Circle()
                .fill(Palette.accent.opacity(0.14))
                .frame(width: 140, height: 140)
                .scaleEffect(bloomScale)
                .blur(radius: 10)
            Circle()
                .fill(Palette.accent.opacity(0.22))
                .frame(width: 72, height: 72)
                .scaleEffect(bloomScale)
                .blur(radius: 3)
        }
        .opacity(bloomVisible ? 1 : 0)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private var bottomContent: some View {
        switch state {
        case .idle, .running:
            HStack(spacing: 6) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Palette.accent.opacity(pulse ? 0.8 : 0.2))
                        .frame(width: 6, height: 6)
                        .animation(
                            .easeInOut(duration: 0.5)
                                .repeatForever(autoreverses: true)
                                .delay(Double(i) * 0.15),
                            value: pulse
                        )
                }
            }
        case .ready:
            EmptyView()
        case .failed(let message):
            VStack(spacing: Space.md) {
                // Fraunces voice instead of system bold; italic punch
                // word per JeniFit pattern.
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
        // Random per mount so a quick bootstrap shows a different quote
        // each launch. Index instead of a copy of the string so the
        // ItalicAccentText render always pairs the right italics array.
        quoteIndex = Int.random(in: 0..<Self.quotes.count)

        // Bloom comes up FIRST so the center has visible mass even
        // before the quote fades in. Soft 0.8s ease so the bloom feels
        // like it's blooming on, not popping. Then the perpetual
        // breath cycle starts (reduce-motion holds at mid).
        withAnimation(.easeOut(duration: 0.8)) { bloomVisible = true }
        if reduceMotion {
            bloomScale = 1.0
        } else {
            withAnimation(.easeInOut(duration: 3.5).repeatForever(autoreverses: true)) {
                bloomScale = 1.08
            }
        }

        withAnimation(Motion.entranceSoft) { quoteVisible = true }
        pulse = true

        // Quick sticker cascade — 80ms between reveals so the whole
        // scatter is on screen by t=0.4s. Snappier than AffirmationScreen
        // because this is a transient loader, not a 5.5s ceremony.
        try? await Task.sleep(nanoseconds: 200_000_000)
        for _ in Self.placements.indices {
            stickerRevealCount += 1
            try? await Task.sleep(nanoseconds: 80_000_000)
        }

        // Quote auto-rotation for long loads. Returning users with
        // cached sessions unmount this view in 200-500ms; fresh-install
        // anonymous sign-in or a slow connection can stretch to 2-5s,
        // and that's exactly the window where "nothing is happening"
        // shows up. Every 4.5s we cross-fade to the next quote so the
        // composition keeps evolving. The loop sits inside `.task`'s
        // structured-concurrency scope — `.task` cancels on view
        // unmount, which cascades to `Task.sleep`'s cancellation, so
        // no manual cleanup is needed. Reduce-motion skips rotation
        // (the central bloom holds, the quote stays steady).
        guard !reduceMotion else { return }
        while !Task.isCancelled {
            try? await Task.sleep(for: .seconds(4.5))
            if Task.isCancelled { break }
            withAnimation(.easeIn(duration: 0.4)) {
                quoteVisible = false
            }
            try? await Task.sleep(for: .milliseconds(450))
            if Task.isCancelled { break }
            quoteIndex = (quoteIndex + 1) % Self.quotes.count
            withAnimation(.easeOut(duration: 0.5)) {
                quoteVisible = true
            }
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
