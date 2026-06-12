import SwiftUI

// MARK: - AffirmationLoaderScreen
//
// Shown while AuthService.bootstrap() runs on every app launch for
// returning users; parent unmounts when auth.isReady && entitlement
// resolves.
//
// v4.6 redesign (founder QA 2026-06-11 + loading-experience expert
// brief): the previous 3-line cascade was back-loaded (lines at
// t=0.5/1.4/2.4s), so fast bootstraps unmounted it mid-pop and it read
// as a flash of half-finished UI. This version is front-loaded and
// looks complete at ANY unmount time:
//   - cream is opaque from frame 0 (continues the static launch screen
//     invisibly; no cream-on-cream fade wasting a beat)
//   - the bow blooms in immediately (gentleSpring), then breathes
//   - ONE affirmation line fades in only if we're still waiting at
//     600ms, so quick launches never flash text
// No stickers, no GeometryReader: one Image + one Text.

struct AffirmationLoaderScreen: View {
    let state: BootstrapState
    let onRetry: () -> Void

    @State private var bowVisible = false
    @State private var bowBreathing = false
    @State private var lineVisible = false
    @State private var line: (text: String, italics: [String]) = ("", [])
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Single-line affirmations — the triplet ceremony stays exclusive
    /// to the first-launch AffirmationScreen.
    private static let lines: [(text: String, italics: [String])] = [
        ("she's already in you.", ["already"]),
        ("small reps. real changes.", ["real"]),
        ("your pace. your week.", ["pace"]),
        ("soft girl. strong body.", ["strong"]),
        ("slow days count too.", ["count"]),
        ("the rest is rhythm.", ["rhythm"]),
    ]

    var body: some View {
        ZStack {
            // Opaque from frame 0 — same cream as the static launch
            // screen, so the handoff is invisible.
            Palette.programEraBg
                .ignoresSafeArea()

            VStack(spacing: Space.lg) {
                Spacer()

                Image("logo_jenifit_bow")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 56, height: 56)
                    .scaleEffect(bowVisible ? (bowBreathing ? 1.03 : 1.0) : 0.92)
                    .opacity(bowVisible ? 1 : 0)
                    .accessibilityHidden(true)

                ItalicAccentText(
                    line.text,
                    italic: line.italics,
                    baseFont: Typo.body,
                    italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 17),
                    color: Palette.textSecondary,
                    alignment: .center
                )
                .opacity(lineVisible ? 1 : 0)
                .frame(height: 24)

                Spacer()

                bottomContent
                    .padding(.bottom, 60)
            }
            .padding(.horizontal, Space.lg)
        }
        .task { await runChoreography() }
    }

    /// Bottom-row content — only the failure state shows a CTA.
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
        line = Self.lines.randomElement() ?? Self.lines[0]

        if reduceMotion {
            bowVisible = true
            lineVisible = true
            return
        }

        // t=0 — the bow blooms. The screen already looks finished here;
        // any unmount from now on reads as a clean dissolve.
        withAnimation(Motion.gentleSpring) { bowVisible = true }
        withAnimation(Motion.breathing.repeatForever(autoreverses: true).delay(0.5)) {
            bowBreathing = true
        }

        // Affirmation only if the wait is real (>600ms), so fast
        // launches never flash text.
        try? await Task.sleep(nanoseconds: 600_000_000)
        guard !Task.isCancelled else { return }
        withAnimation(Motion.entranceSoft) { lineVisible = true }
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
