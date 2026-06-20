import SwiftUI

// MARK: - CancellationWinbackSheet
//
// Sprint A (2026-06-15) — soft cancellation-intent recovery.
//
// Triggers when the user dismisses the paywall via the close X (the
// `paywall_dismiss_attempted` signal). This is NOT the May-31-retired
// discount downsell — premium positioning stays intact, no price cut,
// no separate SKU. Instead, a single voice-aligned identity beat that
// asks her to sit with the decision for one more screen.
//
// Why not the discount downsell:
//   - May-31 founder decision (per [[project-trial-downsell-locked]]
//     + [[feedback-clean-luxury-aesthetic]]): "discount-free premium
//     positioning. Premium positioning IS the lever — Calm/Headspace/
//     Mejuri pattern." That decision stands.
//   - Apple 5.6 risk: post-Cal-AI-pull, any "decline → second
//     discounted SKU" pattern is reviewer-flagged. Stay clear.
//   - Brand register: discounting the cohort she just spent 50 screens
//     of onboarding earning trust with reads as panic. The brand voice
//     IS the moat (per the PMF expert report).
//
// What this sheet does instead:
//   - Reflects ONE sentence of identity-language back at her, derived
//     from her own onboarding answer (priorWin if she gave one,
//     bodyFocus/identityFeeling otherwise, generic permission fallback).
//   - Names the *thing she came here for* — not the product, the
//     becoming. "you came for the *quiet* you said you wanted."
//   - Two CTAs: primary "stay open ♥" (returns to the paywall, fires
//     a winback-confirmed signal) + secondary "not today" (dismisses
//     both sheets, fires the actual leave signal).
//
// Voice locked: lowercase, italic-Fraunces on punch word, no labor
// verbs, permission-frame, no urgency, no scarcity, no ✨/🌸/✨ scatter
// (this is a re-engagement moment, not an earned beat per
// [[feedback-scatter-milestone-rule]]).

struct CancellationWinbackSheet: View {

    var onStayOpen: () -> Void
    var onLeave: () -> Void

    @AppStorage("onboardingPriorWin")     private var priorWin: String = ""
    @AppStorage("identityFeeling")        private var identityFeeling: String = ""
    @AppStorage("onboardingBodyFocusKey") private var bodyFocus: String = ""

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            // her75 register: hero on flat bgPrimary. NO scrapbook
            // chrome on the modal (that was casting the text-shadow
            // effect on the heroes). Layout matches
            // ProgramIntroFullScreenCover — content scroll + docked
            // footer painting bgPrimary so the bg is consistent.
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        eyebrow
                        heroLine
                        reflectiveLine
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.top, Space.hero)
                    .padding(.bottom, 24)
                    .opacity(hasAppeared ? 1 : 0)
                    .offset(y: hasAppeared ? 0 : 12)
                }

                VStack(spacing: 8) {
                    stayCTA
                    leaveCTA
                }
                .padding(.horizontal, 24)
                .padding(.top, 16)
                .padding(.bottom, 20)
                .background(Palette.bgPrimary)
                .opacity(hasAppeared ? 1 : 0)
            }
        }
        .onAppear {
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.08)) {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Eyebrow

    private var eyebrow: some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.accent).frame(width: 5, height: 5)
            Text("before you go")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.8)
                .textCase(.uppercase)
        }
    }

    // MARK: - Hero line — punch word reflects identity feeling

    private var heroLine: some View {
        // her75 hero — JeniHeroSerif at heroHeadline (38pt) with
        // heroHeadlineLineGap (-19). 3-line cascade with italic
        // punches on the feeling word (line 1) + "here" (line 3).
        // `.kerning(-0.4)` per the her75 spec.
        VStack(alignment: .leading, spacing: Typo.heroHeadlineLineGap) {
            // Line 1: "the [feeling]"
            (
                Text("the ")
                    .font(Typo.heroHeadline)
                    .foregroundStyle(Palette.textPrimary)
                +
                Text(heroParts.feeling)
                    .font(Typo.heroHeadlineItalic)
                    .foregroundStyle(Palette.textPrimary)
            )

            // Line 2: "you"
            Text("you")
                .font(Typo.heroHeadline)
                .foregroundStyle(Palette.textPrimary)

            // Line 3: "is still here ♥"
            (
                Text("is still ")
                    .font(Typo.heroHeadline)
                    .foregroundStyle(Palette.textPrimary)
                +
                Text("here")
                    .font(Typo.heroHeadlineItalic)
                    .foregroundStyle(Palette.textPrimary)
                +
                Text(" ♥")
                    .font(Typo.heroHeadline)
                    .foregroundStyle(Palette.textPrimary)
            )
        }
        .kerning(-0.4)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Punch word is derived from her identityFeeling answer (case 1
    /// in onboarding). Five paths covered explicitly so every cohort
    /// gets a line that lands. Default for missing/legacy users.
    private var heroParts: (feeling: String, italic: [String]) {
        switch identityFeeling {
        case "powerful":  return ("strong",  ["strong"])
        case "calm":      return ("calm",    ["calm"])
        case "light":     return ("light",   ["light"])
        case "strong":    return ("strong",  ["strong"])
        case "radiant":   return ("radiant", ["radiant"])
        default:          return ("next",    ["next"])
        }
    }

    // MARK: - Reflective line — references her priorWin or barrier

    @ViewBuilder
    private var reflectiveLine: some View {
        let parts = reflectiveParts
        ItalicAccentText(
            parts.base,
            italic: parts.italic,
            baseFont: .custom("Fraunces72pt-Regular", size: 15),
            italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 15),
            color: Palette.textSecondary,
            alignment: .leading
        )
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Three-tier fallback. If she shared a priorWin we mirror it
    /// back gently. Otherwise we lean on bodyFocus (less personal,
    /// still in-cohort). Otherwise pure permission frame. her75
    /// register: shorter lines, italic punch on the active verb so
    /// the body reads as editorial pull-quote, not paragraph.
    private var reflectiveParts: (base: String, italic: [String]) {
        let p = priorWin.trimmingCharacters(in: .whitespacesAndNewlines)
        let b = bodyFocus.trimmingCharacters(in: .whitespacesAndNewlines)
        if !p.isEmpty {
            return (
                "you came back because \(p.lowercased()) worked once. it can again ♥",
                ["worked"]
            )
        }
        if !b.isEmpty {
            return (
                "we built your plan for your \(b.lowercased()) horizon. it's still here ♥",
                ["here"]
            )
        }
        return (
            "no pressure either way. the plan is here when you are ♥",
            ["here"]
        )
    }

    // MARK: - CTAs

    private var stayCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
            Analytics.track(.paywallDismissAttempted, properties: [
                "winback_outcome": "stayed",
                "placement": "cancellation_winback"
            ])
            onStayOpen()
        } label: {
            Text("stay open ♥")
                .font(.custom("DMSans-SemiBold", size: 15))
                .foregroundStyle(Palette.bgPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .background(Capsule().fill(Palette.textPrimary))
        }
        .buttonStyle(.plain)
    }

    private var leaveCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Analytics.track(.paywallDismissAttempted, properties: [
                "winback_outcome": "left",
                "placement": "cancellation_winback"
            ])
            onLeave()
        } label: {
            Text("not today")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
