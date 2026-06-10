import SwiftUI

// MARK: - PremiumWelcomeScreen
//
// Bridges paywall purchase success → MainTabView. Plays once after a
// fresh subscription completes (PaywallView or DownsellPaywallView
// `onSubscribed`). Existing paid users on re-install don't see this —
// the trigger lives on the purchase callback, not on `hasProAccess`
// flip alone, so a returning user whose entitlement auto-restores
// goes straight to home as today.
//
// Choreography (mirrors planRevealScreen in onboarding):
//   t=0.00 background fade in (0.3s)
//   t=0.05 heart sticker + halo spring in
//   t=0.15 sparkle burst fans out + fades in, holds 1.4s, fades out
//   t=0.40 eyebrow fade + slide up
//   t=0.55 italic-accent headline fade + slide up
//   t=0.85 subtitle fade in
//   t=2.50 auto-advance via onComplete()
//
// Tap anywhere to skip immediately. reduceMotion snaps to final state
// and holds 1.5s before advancing (no springs, no slides).

struct PremiumWelcomeScreen: View {
    let onComplete: () -> Void

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var bgVisible = false
    @State private var heartVisible = false
    @State private var sparkleBurstActive = false
    @State private var sparkleBurstVisible = false
    @State private var eyebrowVisible = false
    @State private var headlineVisible = false
    @State private var subtitleVisible = false
    @State private var didAdvance = false
    /// Phase 9.28 — CTA controls the welcome→ritual handoff. Auto-
    /// advance was replaced with this explicit tap so iOS doesn't
    /// drop the dismiss+present sequence (it was racing the cover
    /// transition queue and sometimes failing silently). Fades in
    /// after the subtitle lands.
    @State private var ctaVisible = false

    // Sparkle burst placements — 8 sparkles fanning out from the heart.
    // Sizes vary 12-22pt for organic feel; offsets are in points from center.
    private static let sparkleBurst: [(offset: CGSize, size: CGFloat)] = [
        (CGSize(width:  -72, height: -44), 22),
        (CGSize(width:   70, height: -48), 18),
        (CGSize(width:  -82, height:  30), 16),
        (CGSize(width:   80, height:  38), 20),
        (CGSize(width:    0, height: -82), 14),
        (CGSize(width:  -28, height:  72), 12),
        (CGSize(width:   34, height:  78), 14),
        (CGSize(width:  -98, height: -10), 12),
    ]

    var body: some View {
        ZStack {
            // v8 P8.6: PostPurchaseFlowView already paints the pink
            // canvas; this local layer just stays for the bgVisible
            // cross-fade choreography. Routed through programBgPrimary
            // so the fade-in matches what the user lands on.
            Palette.programBgPrimary
                .ignoresSafeArea()
                .opacity(bgVisible ? 1 : 0)

            VStack(spacing: 0) {
                Spacer()

                hero
                    .padding(.bottom, Space.lg)

                headline
                    .padding(.horizontal, Space.lg)

                Spacer()

                // Phase 9.28 — explicit CTA replaces the auto-advance.
                // User taps "let's begin" → advance() → onComplete()
                // → PlankAIApp transitions to Module 1. No more silent
                // failures from cover-transition queue races.
                Button(action: advance) {
                    Text("let's begin")
                }
                .buttonStyle(.ctaPrimary)
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
                .opacity(ctaVisible ? 1 : 0)
                .offset(y: ctaVisible ? 0 : 12)
            }
        }
        .onAppear {
            if reduceMotion {
                runReducedMotion()
            } else {
                runFullChoreography()
            }
        }
    }

    // MARK: - Hero (heart + halo + sparkle burst)

    private var hero: some View {
        ZStack {
            ForEach(Self.sparkleBurst.indices, id: \.self) { i in
                let entry = Self.sparkleBurst[i]
                Image(StickerName.sparkleGlossy.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: entry.size, height: entry.size)
                    .opacity(sparkleBurstVisible ? 0.85 : 0)
                    .scaleEffect(sparkleBurstActive ? 1 : 0.4)
                    .offset(sparkleBurstActive ? entry.offset : .zero)
            }
            Circle()
                .fill(Palette.accent.opacity(0.10))
                .frame(width: 140, height: 140)
                .scaleEffect(heartVisible ? 1 : 0.5)
                .opacity(heartVisible ? 1 : 0)
            Image(StickerName.heartGlossy.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 96, height: 96)
                .scaleEffect(heartVisible ? 1 : 0.6)
                .opacity(heartVisible ? StickerName.heartGlossy.style.opacity : 0)
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.65), value: heartVisible)
    }

    // MARK: - Headline (eyebrow + italic-accent title + subtitle)

    private var headline: some View {
        VStack(spacing: Space.sm) {
            Text("jenifit premium")
                .font(Typo.eyebrow)
                .tracking(1.5)
                .textCase(.uppercase)
                .foregroundStyle(Palette.accent)
                .opacity(eyebrowVisible ? 1 : 0)
                .offset(y: eyebrowVisible ? 0 : 8)

            // v8 P8.6: lowercase voice register.
            ItalicAccentText("welcome to your plan.",
                             italic: ["plan."],
                             alignment: .center)
                .opacity(headlineVisible ? 1 : 0)
                .offset(y: headlineVisible ? 0 : 12)

            // v8 P8.6 — anti-shame, peer register. "Let's get to work"
            // reads as labor-verb diet-culture; this lands as alongside.
            Text("your coach is ready. so are you.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.md)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(subtitleVisible ? 1 : 0)
        }
    }

    // MARK: - Choreography

    private func runFullChoreography() {
        Haptics.success()

        withAnimation(.easeOut(duration: 0.3)) { bgVisible = true }

        withAnimation(.spring(response: 0.55, dampingFraction: 0.7).delay(0.05)) {
            heartVisible = true
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
            withAnimation(.spring(response: 0.6, dampingFraction: 0.55)) {
                sparkleBurstActive = true
            }
            withAnimation(.easeOut(duration: 0.35)) {
                sparkleBurstVisible = true
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.55) {
            withAnimation(.easeOut(duration: 0.6)) {
                sparkleBurstVisible = false
            }
        }

        withAnimation(.easeOut(duration: 0.4).delay(0.40)) {
            eyebrowVisible = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.55)) {
            headlineVisible = true
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.85)) {
            subtitleVisible = true
        }
        // Phase 9.28 — CTA fades in just after the subtitle lands.
        // User-initiated tap is the only way forward; no auto-advance.
        withAnimation(.easeOut(duration: 0.4).delay(1.20)) {
            ctaVisible = true
        }
    }

    private func runReducedMotion() {
        bgVisible = true
        heartVisible = true
        eyebrowVisible = true
        headlineVisible = true
        subtitleVisible = true
        sparkleBurstActive = true
        sparkleBurstVisible = true
        ctaVisible = true
    }

    private func advance() {
        guard !didAdvance else { return }
        didAdvance = true
        onComplete()
    }
}
