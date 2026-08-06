import SwiftUI
import RevenueCat

// MARK: - ForgingRevealView
//
// v3 P11.4 (2026-06-10) — the keystone. Post-paywall "forging"
// moment that lands as the FIRST phase of PostPurchaseFlowView,
// before CoachIntro. Five milestone cascade lines reveal the
// program activating; a single Haptics.success() fires at 380ms
// into the cascade so the second line ("locked in") lands with
// a louder beat than the soft per-line taps.
//
// Total dwell: ~8 seconds (5 lines × 0.42s perLineDelay = 2.1s
// reveal, then a 4-5s read pause, then auto-advance to CoachIntro).
// User can tap "continue" mid-pause to advance early.
//
// Why this exists:
// - the existing PostPurchaseFlowView jumped straight to CoachIntro
//   after purchase, which felt abrupt — the user just committed
//   $47.99 + watched a 25s onboarding loader, and the first thing
//   they saw was "hi, I'm Jeni" with no acknowledgement of the
//   commitment itself
// - the forging beat acknowledges WHAT they just bought before
//   introducing WHO will guide them through it
// - per Cal AI calai31 ("All done!" frame), the post-loader / post-
//   purchase moment is a high-value emotional pivot — the cohort
//   converts on adherence to whatever rhythm the next 20 seconds
//   establishes
//
// Voice: italic-Fraunces punch per line on the verb that carries
// commitment ("activated", "locked in", "ready", "becoming",
// "begin"). Heart terminal on the final line. No labor verbs.

struct ForgingRevealView: View {
    let onContinue: () -> Void

    @State private var ctaVisible = false
    @State private var successHapticFired = false
    /// "you chose: $24.99 · renews oct 6 · yours to cancel anytime" —
    /// the paid receipt, restating exactly what she confirmed one
    /// StoreKit sheet ago. Kills the "wait, what did it charge?"
    /// panic that turns into a refund request by day 5. nil (omitted)
    /// when the entitlement/product can't resolve — never invented.
    @State private var paidReceiptLine: String?
    @AccessibilityFocusState private var heroFocused: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    /// Time from view appear to single Haptics.success() — lands on
    /// line 2 ("locked in") which is the meaning beat of the cascade.
    private static let successHapticDelay: Double = 0.38

    /// Total dwell before auto-advance. 5 lines × 0.42s reveal = 2.1s
    /// + 4.9s read pause = 7s total. Cap matches the her75 "magazine
    /// page-turn" pacing per [[feedback-her75-motion-vocabulary]].
    private static let autoAdvanceAfter: Double = 7.0

    var body: some View {
        VStack(spacing: 0) {
            Spacer()
            LineCascadeText(
                lines: [
                    .composite(base: "your program is activated.", italic: ["activated."]),
                    .composite(base: "your routine is locked in.",  italic: ["locked in."]),
                    // 2026-07-07: "first session" → "day one" — the wall
                    // sold DAY ONE; the first paid frame cashes the same
                    // object by name.
                    .composite(base: "your day one is ready.",       italic: ["ready."]),
                    .composite(base: "your becoming starts now.",    italic: ["becoming"]),
                    .composite(base: "let's begin", italic: ["begin"]),
                ],
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                color: Palette.textPrimary,
                alignment: .leading,
                lineSpacing: Typo.heroHeadlineLineGap,
                perLineDelay: 0.42
            )
            .kerning(-0.4)
            .padding(.horizontal, Space.lg)
            .accessibilityFocused($heroFocused)
            .accessibilityLabel("Your program is activated. Your routine is locked in. Your day one is ready. Your becoming starts now. Let's begin.")
            Spacer()
            if let paidReceiptLine {
                Text(paidReceiptLine)
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, 10)
                    .opacity(ctaVisible ? 1 : 0)
            }
            JFContinueButton(label: "let's go") {
                onContinue()
            }
            .opacity(ctaVisible ? 1 : 0)
            .allowsHitTesting(ctaVisible)
        }
        .task { await resolvePaidReceipt() }
        .onAppear {
            heroFocused = true
            // Single success haptic at +380ms — louder beat on the
            // second line ("locked in"), the commitment moment.
            // LineCascadeText still fires per-line soft haptics on
            // top; the success here adds emphasis rather than
            // replacing the cascade signal.
            if !reduceMotion {
                DispatchQueue.main.asyncAfter(deadline: .now() + Self.successHapticDelay) {
                    guard !successHapticFired else { return }
                    successHapticFired = true
                    Haptics.success()
                }
            }
            // Reveal the CTA after the cascade finishes reading
            // (~2.5s = 5 lines × 0.42s + 0.4s settle). Auto-advance
            // safety net fires `Self.autoAdvanceAfter` seconds after
            // appear if the user hasn't tapped.
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                withAnimation(Motion.entranceSoft) {
                    ctaVisible = true
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Self.autoAdvanceAfter) {
                onContinue()
            }
        }
    }

    /// Read-only RC lookups (both served from the SDK cache at this
    /// point): the active entitlement's product → its package in the
    /// current offering → localized price + renewal cadence. Entitlement
    /// LOGIC is untouched — this only narrates what already happened.
    private func resolvePaidReceipt() async {
        guard Purchases.isConfigured else { return }
        guard let info = try? await Purchases.shared.customerInfo(),
              let entitlement = info.entitlements[RevenueCatConfig.entitlementID],
              entitlement.isActive else { return }
        let productId = entitlement.productIdentifier

        let cadence: String
        switch productId {
        case RevenueCatConfig.ProductID.yearly,
             RevenueCatConfig.ProductID.yearlyDiscount,
             RevenueCatConfig.ProductID.V2.yearlyDiscount:
            cadence = "renews yearly"
        case RevenueCatConfig.ProductID.quarterly:
            cadence = "renews quarterly"
        case RevenueCatConfig.ProductID.weekly:
            cadence = "renews weekly"
        default:
            cadence = "renews on schedule"
        }

        var priceText: String?
        if let offerings = try? await Purchases.shared.offerings() {
            let all = [offerings.current].compactMap { $0 } + Array(offerings.all.values)
            for offering in all {
                if let pkg = offering.availablePackages.first(where: {
                    $0.storeProduct.productIdentifier == productId
                }) {
                    priceText = pkg.storeProduct.localizedPriceString
                    break
                }
            }
        }

        await MainActor.run {
            if let priceText {
                paidReceiptLine = "you chose: \(priceText) \u{00B7} \(cadence) \u{00B7} yours to cancel anytime"
            } else {
                paidReceiptLine = "\(cadence) \u{00B7} yours to cancel anytime"
            }
        }
    }
}

#Preview {
    ForgingRevealView(onContinue: {})
        .background(Palette.programBgPrimary)
}
