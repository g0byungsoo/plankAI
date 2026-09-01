import SwiftUI

// MARK: - RatingSentimentScreen
//
// The full-screen sentiment gate (2026-07-08). Fires once from the
// post-purchase welcome flow; "yes" → native SKStoreReviewController,
// "not really" → feedback. A design-forward full-screen moment in the
// app's generative-bloom language (the JKBreathField family): the ink
// JeniMark breathing over a warm rose halo, all driven from one clock
// so nothing drifts (the glossy heart died in the 1.2.0 voice pass —
// hearts retired app-wide; the mark is the seal now). "yes" earns a
// celebratory swell + a ghost-mark pulse + haptic ramp before the
// system prompt lands.
//
// Composition (top → bottom): breathing mark bloom · line-cascade
// question · prosocial sub · docked cocoa CTA + quiet decline.
// Reduce-Motion: static bloom, no cascade, instant.

struct RatingSentimentScreen: View {
    let onYes: () -> Void      // present SKStoreReviewController
    let onNotReally: () -> Void // open FeedbackView

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var heartIn = false
    @State private var questionIn = false
    @State private var ctaIn = false
    @State private var celebrateStart: Date?
    @State private var locked = false   // guards double-taps during the yes swell

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer(minLength: 0)

                RatingMarkBloom(celebrateStart: celebrateStart)
                    .frame(width: 240, height: 240)
                    .scaleEffect(heartIn ? 1 : 0.72)
                    .opacity(heartIn ? 1 : 0)

                LineCascadeText(
                    lines: [.composite(base: "enjoying jeni so far?", italic: ["enjoying"])],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    color: Palette.textPrimary,
                    alignment: .center,
                    lineSpacing: Typo.heroHeadlineLineGap,
                    trigger: questionIn
                )
                .kerning(-0.4)
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.xl)

                Text(UserDefaults.standard.string(forKey: "onboardingGender") == "female"
                     ? "a quick word helps other people find us."
                     : "a quick word helps others find us.")
                    .font(Typo.teachSub)
                    .lineSpacing(Typo.teachSubLineSpacing)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg + Space.sm)
                    .padding(.top, Space.sm)
                    .opacity(questionIn ? 1 : 0)

                Spacer(minLength: 0)
            }

            VStack {
                Spacer()
                ctaStack
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, Space.lg)
                    .opacity(ctaIn ? 1 : 0)
                    .offset(y: ctaIn ? 0 : 14)
            }
        }
        .task { await runEntrance() }
    }

    // MARK: - CTAs

    private var ctaStack: some View {
        VStack(spacing: 10) {
            Button {
                guard !locked else { return }
                locked = true
                Haptics.success()
                // The earned beat: the bloom swells from the tap, then
                // the system prompt lands ~0.55s later so the native
                // sheet feels like the reward, not an interruption.
                celebrateStart = Date()
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) { Haptics.soft() }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.55) { onYes() }
            } label: {
                Text("yes, loving it")
                    .font(.custom("DMSans-SemiBold", size: 16))
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .fill(Palette.textPrimary)
                    )
                    // One specular sweep so the cocoa mass reads pressed
                    // + premium (the wall CTA's gloss).
                    .overlay(
                        RoundedRectangle(cornerRadius: Radius.tile, style: .continuous)
                            .fill(LinearGradient(
                                colors: [Color.white.opacity(0.10), Color.white.opacity(0)],
                                startPoint: .top, endPoint: .center
                            ))
                            .allowsHitTesting(false)
                    )
            }
            .buttonStyle(PressFeedbackStyle())
            .disabled(locked)

            Button {
                guard !locked else { return }
                locked = true
                Haptics.light()
                onNotReally()
            } label: {
                Text("not really")
                    .font(.system(size: 15, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Entrance choreography

    private func runEntrance() async {
        if reduceMotion {
            heartIn = true; questionIn = true; ctaIn = true
            return
        }
        withAnimation(.spring(response: 0.65, dampingFraction: 0.72)) { heartIn = true }
        try? await Task.sleep(nanoseconds: 380_000_000)
        withAnimation { questionIn = true }   // LineCascadeText owns its own timing
        try? await Task.sleep(nanoseconds: 520_000_000)
        withAnimation(.easeOut(duration: 0.4)) { ctaIn = true }
    }
}

// MARK: - RatingMarkBloom
//
// The official ink JeniMark, made to breathe. One clock drives
// everything (the JKBreathField discipline): a warm rose halo and the
// mark swell gently on a 5s ambient breath; `celebrateStart` (set on
// "yes") fires a one-shot swell + a ghost-mark pulse radiating outward
// — the tactile reward before the native prompt. The mark stays ink on
// the paper (one-colour law); only the halo carries rose.
struct RatingMarkBloom: View {
    /// Non-nil once "yes" is tapped — the moment the celebration began.
    var celebrateStart: Date?

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        GeometryReader { geo in
            let base = min(geo.size.width, geo.size.height)
            TimelineView(.animation(minimumInterval: 1.0 / 60.0,
                                    paused: reduceMotion && celebrateStart == nil)) { context in
                let (breath, swell, ring) = envelope(now: context.date)
                ZStack {
                    // Halo — a warm wash that swells with the breath.
                    Circle()
                        .fill(RadialGradient(
                            colors: [
                                Palette.accent.opacity(0.16 + 0.08 * breath + 0.16 * swell),
                                Palette.accent.opacity(0),
                            ],
                            center: .center, startRadius: 0, endRadius: base * 0.5
                        ))
                        .scaleEffect(0.86 + 0.22 * breath + 0.24 * swell)

                    // Celebration pulse — a ghost of the mark itself,
                    // expanding and fading from the "yes" tap.
                    if ring > 0 && ring < 1 {
                        mark(base: base)
                            .scaleEffect(1 + 0.7 * ring)
                            .opacity(0.30 * (1 - ring))
                    }

                    // The mark — ink mass, breathing. No drop shadow:
                    // the halo carries the depth (never outline, never
                    // glow the mark itself).
                    mark(base: base)
                        .scaleEffect(1 + (reduceMotion ? 0 : 0.035 * breath) + 0.13 * swell)
                }
                .frame(width: geo.size.width, height: geo.size.height)
            }
        }
        .accessibilityHidden(true)
    }

    private func mark(base: CGFloat) -> some View {
        JeniMark(height: base * 0.52, color: Palette.textPrimary)
    }

    /// (ambient breath 0…1, celebration swell 0…1, pulse ring 0…1).
    private func envelope(now: Date) -> (Double, Double, Double) {
        let t = now.timeIntervalSinceReferenceDate
        let breath = reduceMotion
            ? 0.6
            : (0.5 - 0.5 * cos(2 * .pi * t.truncatingRemainder(dividingBy: 5) / 5))
        var swell = 0.0, ring = 0.0
        if let start = celebrateStart {
            let e = now.timeIntervalSince(start)
            swell = e < 0.28 ? (e / 0.28) : max(0, 1 - (e - 0.28) / 0.9)
            ring = min(1, e / 0.7)
        }
        return (breath, swell, ring)
    }
}

#if DEBUG
#Preview("rating sentiment") {
    RatingSentimentScreen(onYes: {}, onNotReally: {})
}
#endif
