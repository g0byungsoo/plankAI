import SwiftUI
import SwiftData
import RevenueCat
import PlankFood
import PlankSync
import Auth

// MARK: - PaywallView
//
// Post-onboarding paywall. Phase 7 redesign: JENIFIT PREMIUM eyebrow +
// italic-accent personalized headline (keyed off bodyFocus.first) +
// benefit checklist + PricingCard yearly/weekly + accent CTA + auto-
// renewal disclosure + Terms/Privacy footer. Voice is aspirational-
// feminine ("Become her in 30 days."), no AI language, no scarcity.
//
// RevenueCat: offerings.current populates the cards by productIdentifier;
// storeProduct.priceFormatter formats prices in the user's locale; CTA
// calls Purchases.shared.purchase(package:); savings % is computed
// dynamically from the live yearly + weekly prices and rendered as a
// separate Typo.eyebrow element below the price (Phase 7 polish).

struct PaywallView: View {
    let dismissable: Bool
    let onSubscribed: () -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    let onPurchaseCancelled: () -> Void

    init(
        dismissable: Bool = true,
        onSubscribed: @escaping () -> Void,
        onRestore: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {},
        onPurchaseCancelled: @escaping () -> Void = {}
    ) {
        self.dismissable = dismissable
        self.onSubscribed = onSubscribed
        self.onRestore = onRestore
        self.onDismiss = onDismiss
        self.onPurchaseCancelled = onPurchaseCancelled
    }

    // On-device fast-path mirror, written by handleOnboardingComplete +
    // EditProfileView.selectBodyFocus. Cross-device sync goes through
    // UserRecord (synced via SyncService.hydrateUser on sign-in); the
    // mirror lags by one EditProfile save. effectiveBodyFocus below
    // prefers UserRecord when present so a fresh device-B sign-in
    // shows the right personalized headline immediately.
    @AppStorage("bodyFocus") private var bodyFocusMirror: String = ""

    // Phase 1 conversion pass — paywall reads the user's onboarding
    // answers to personalize plan-bridge + week-1 preview + coach
    // promise. All keys are written by PlankAIApp.handleOnboardingComplete
    // so they're populated by the time the paywall cover presents.
    @AppStorage("userName")           private var userName: String = ""
    @AppStorage("commitmentDays")     private var commitmentDays: String = ""
    @AppStorage("sessionLengthPref")  private var sessionLengthPref: String = ""
    @AppStorage("voicePreference")    private var voicePreference: String = "encouraging"

    // v9 P9.2/P9.5 — set in OnboardingRevealView's pace picker. When
    // present, paywall headline pivots to "unlock your N-day plan."
    // and the trial-recap line can reference the user's actual program
    // length instead of a generic horizon.
    @AppStorage("onboardingPickedTier") private var onboardingPickedTierRaw: String = ""
    @AppStorage("onboardingHormonalStage") private var paywallHormonalStage: String = ""
    @AppStorage("onboarding_glp1_status")  private var paywallGlp1Status: String = ""

    @Query private var userRecords: [UserRecord]

    @State private var auth = AuthService.shared

    /// Cross-device-synced UserRecord row for the current auth user, or
    /// nil if hydration hasn't run yet (e.g., during the bootstrap
    /// window before SyncService.hydrateUser fires) or if the user
    /// onboarded on a device + version that predates the body_focus
    /// column.
    private var currentUserRecord: UserRecord? {
        guard let userId = auth.currentUser?.id.uuidString, !userId.isEmpty else { return nil }
        return userRecords.first { $0.id == userId }
    }

    /// Source of truth for the personalized headline. UserRecord wins
    /// when populated (cross-device truth, just hydrated from Supabase);
    /// falls back to the AppStorage mirror so single-device flow stays
    /// unchanged. Empty array on UserRecord falls through to the mirror
    /// so legacy users (onboarded pre-2026-05-04 schema migration) still
    /// get personalization from the mirror without re-onboarding.
    private var bodyFocus: String {
        if let record = currentUserRecord, let first = record.onboardingBodyFocus.first {
            return first
        }
        return bodyFocusMirror
    }

    @State private var selectedPlan: Plan = .yearly
    @State private var working = false
    @State private var errorMessage: String?
    @State private var legalDoc: LegalDoc?
    @State private var offering: Offering?
    @State private var loadingOfferings = true
    @State private var offeringsLoadFailed = false
    @State private var restoreAlert: RestoreAlert?

    /// Captures the moment PaywallView first appears so the issue #2
    /// diagnostic events can report `time_on_paywall_ms` (a deceptively
    /// useful signal — long times correlate with hesitation and short
    /// times with auto-dismiss bugs).
    @State private var viewOpenTime: Date = Date()

    /// 2026-05-30 DEBUG-only mock pricing fallback. When the v1.0.7 new
    /// products are all in MISSING_METADATA state (waiting on screenshot
    /// upload in ASC), RC's SDK filters them out of offerings.all and
    /// returns 0 packages for the preview offering. This blocks visual
    /// verification of the 3-card layout + new pricing.
    ///
    /// Fix: in DEBUG, when the preview offering returned 0 usable
    /// packages, fall back to mock pricing strings so the new 3-card
    /// paywall renders with hardcoded $47.99 / $24.99 / $5.99 for visual
    /// iteration. Purchase attempts in this mode silently no-op (no real
    /// RC package = no real StoreKit handoff). Removed when the founder
    /// completes the ASC manual setup and RC starts returning real
    /// packages.
    #if DEBUG
    private var debugMockPricing: Bool {
        // Trigger mock mode when in DEBUG and the new quarterly product
        // isn't available from RC. This is the "v1.0.7 setup not yet
        // complete" condition — usually because all 6 new products are
        // still MISSING_METADATA in ASC waiting on screenshot upload.
        //
        // When mock mode is on, the price computed properties IGNORE
        // any legacy package that happens to be resolving (e.g.
        // absmaxxing_yearly) and force the new mock prices instead,
        // so the founder sees the v1.0.7 design visually as it'll
        // ship — not a hybrid of v1.0.6 prices + v1.0.7 chrome.
        //
        // Auto-disables in DEBUG the moment quarterlyPackage starts
        // resolving (= v1.0.7 setup complete), and is always disabled
        // in release builds.
        return quarterlyPackage == nil
    }
    #else
    private var debugMockPricing: Bool { false }
    #endif

    /// 2026-05-30 redesign: added `.quarterly` for the v1.0.7 3-tier
    /// pricing structure (annual + quarterly + weekly). String raw
    /// values are used in Analytics event properties (paywallCtaTapped,
    /// purchaseSheetShown, etc.) so funnel queries can segment by plan.
    private enum Plan: String, Equatable { case yearly, quarterly, weekly }

    private enum LegalDoc: String, Identifiable {
        case terms, privacy
        var id: String { rawValue }
        var url: URL {
            switch self {
            case .terms: return URL(string: "https://jenifit.app/terms")!
            case .privacy: return URL(string: "https://jenifit.app/privacy")!
            }
        }
    }

    private struct RestoreAlert: Identifiable {
        let id = UUID()
        let title: String
        let message: String
    }

    // MARK: Copy

    /// 2026 research-led headline. The "becoming ritual" frame echoes
    /// the user's onboarding answer (the Becoming tab + the daily ritual
    /// they just saw on case 250) — Noom-style personalization that
    /// lifts +15-25%. "becoming" is the italic punch word + the brand-
    /// anchor verb from the Becoming tab.
    ///
    /// Why not outcome framing ("lose X lbs"): TikTok content moderation
    /// post-Ozempic flags direct weight-loss copy + this audience now
    /// pattern-matches it to scammy (Rolling Stone 2026). Identity has
    /// caught up to outcome for the 22-35F cohort.
    ///
    /// Name prefix when known — "hi sarah." reads as a personal note,
    /// not a sales pitch. Falls back gracefully when name missing.
    private var headlineParts: (base: String, italic: [String]) {
        let first = displayFirstName
        let namePrefix = first.isEmpty ? "" : "\(first), "

        // v9 P9.5 — when the user came through the new program-design
        // chapter in onboarding (cases pacePicker + goalDate), she
        // already holds her custom program length. Paywall headline
        // sells THAT plan, not an idea. Wins over every variant below
        // when `onboardingPickedTier` is set.
        if let nDay = derivedProgramDays {
            let punch = "your"
            let base = "\(namePrefix)unlock \(punch) \(nDay)-day plan."
            return (base, [punch])
        }

        // Delta v7 D72 — US-specific food-first headline variant.
        // Replaces brand-promise framing ("becoming starts here") with
        // a camera-promise wedge ("snap your plate. see if it fits.").
        // Adapty 2026 cross-app diet data: camera-promise headlines
        // outperform brand-promise 1.3-1.5× in US 18-29F segment
        // (Brief #3 §1 — expected US trial-to-paid lift +30-50%).
        // PostHog dashboard targets US via geoip + caps rollout %.
        // Most-specific gate first: requires both the US PostHog
        // variant AND food rail being advertised (so users not in the
        // food rollout don't see camera promises).
        if FoodFlags.isAdvertised && FoodFlags.isPaywallFoodFirstEnabled {
            let punch = "fits"
            let base = "snap your plate. see if it \(punch). before you eat."
            return (base, [punch])
        }

        // W4-T5 — food-variant hero when food rail is the v1.0.7
        // headline feature. Frames the value-prop around the full
        // weight-loss story (what you eat + how you move + the trend)
        // instead of the weight projection number alone. Per v5
        // §Paywall hero variant + voice locks. Gated on
        // FoodFlags.isAdvertised (PostHog-only check, skips the paid
        // entitlement gate — user hasn't paid yet at paywall time).
        if FoodFlags.isAdvertised {
            // 2026-06-29 - explicit line breaks so "weight-loss story"
            // stays intact on its own line instead of breaking on the
            // hyphen. line1 = name + "your", line2 = italic punch,
            // line3 = the close.
            let punch = "weight-loss story"
            let base = "\(namePrefix)your\n\(punch)\nstarts today."
            return (base, [punch])
        }

        // 2026-06-06 v2 — quarterly-anchor-aligned timeline frame (UX
        // expert v2, docs/paywall_research_ux_v2_2026_06_06.md). Replaces
        // the food-rail-future "softer with food" variant. Both are
        // permission-framed and Cal-AI-safe; the timeline frame aligns
        // with the quarterly-emphasis layout (12-week becoming horizon)
        // instead of pre-promoting the unshipped food rail.
        // Italic-Fraunces lands on "your" per locked voice; hearts ♥ as
        // terminal punctuation (locked); lowercase casual (locked).
        let punch = "your"
        let base = "\(namePrefix)sized for \(punch) timeline ♥"
        return (base, [punch])
    }

    // MARK: RevenueCat package lookup

    private var yearlyPackage: Package? {
        offering?.availablePackages.first {
            $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.yearly
                || $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.V2.yearly
        }
    }

    /// 2026-05-30: NEW tier added by epic #1 child #3. Self-gating —
    /// returns nil until RC's default offering includes a package with
    /// productIdentifier == `jenifit_quarterly`. The PaywallView pricing
    /// section omits the quarterly card whenever this is nil, so the
    /// 3-tier code ships safely BEFORE Apple approves the new SKU.
    private var quarterlyPackage: Package? {
        offering?.availablePackages.first {
            $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.quarterly
        }
    }

    private var weeklyPackage: Package? {
        offering?.availablePackages.first {
            $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.weekly
                || $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.V2.weekly
        }
    }

    private var selectedPackage: Package? {
        switch selectedPlan {
        case .yearly:    return yearlyPackage
        case .quarterly: return quarterlyPackage
        case .weekly:    return weeklyPackage
        }
    }

    // MARK: - Weight-loss projection (v5 2026-05-31)
    //
    // Pulls from already-collected onboarding fields (currentWeightKg +
    // goalWeightKg) to drive the weight-loss-direct hero copy + the
    // goal-projection pill. Pace math: ACSM 0.5-1%/wk sustainable loss,
    // midpoint 0.75%/wk. Conservative — projection date is what we
    // VERBALLY hedge as "on track to" (never a promise).
    //
    // Per Apple post-Cal-AI-pullout research (techcrunch/macrumors):
    // weight-loss copy is allowed; what got Cal AI pulled was deceptive
    // billing UI, not WL claims. So "lose 8 lbs by aug 12" is safe —
    // just keeps the projection hedge in the surrounding copy.
    //
    // Graceful fallback at every site: if the user didn't set a weight
    // goal (or is in maintain/gain mode), the WL hero + pill drop out
    // and the paywall falls back to the becoming-ritual copy.

    /// 2026-05-30 (epic #1 child #6): true when the user has set a
    /// weight-loss goal that's solvable in ~12 weeks at ACSM's 0.5-1%/wk
    /// sustainable-loss pace. Drives the goal-aware default plan
    /// selection on .task — quarterly default for these users (matches
    /// the locked "3-month frame" voice signal), annual default for
    /// everyone else (no-goal, maintain-mode, or longer-horizon goals).
    /// v9 P9.5 — derives the user's custom program duration in days
    /// from the onboarding pace pick + collected weights. Returns nil
    /// when she didn't go through the new program-design chapter (legacy
    /// paywall path stays on its original headline variants). Mirrors
    /// the same ProgramGoalCalculator.compute(...) call PacePicker uses,
    /// so the day count here = the day count she just held in onboarding.
    private var derivedProgramDays: Int? {
        guard let tier = IntensityTier(rawValue: onboardingPickedTierRaw),
              let record = currentUserRecord,
              let current = record.onboardingCurrentWeightKg,
              let goal = record.onboardingGoalWeightKg,
              current > goal else { return nil }
        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: current,
            goalWeightKg: goal,
            sex: .female,
            age: nil,
            // v3 P11.2 (2026-06-10) — routed through engine-v2 helpers.
            // Note: paywall doesn't yet read sleep — adding it would
            // need a new @AppStorage on PaywallView. Skipping for
            // now since paywall only displays the day count, doesn't
            // alter the program; the actual program-shape decisions
            // happen upstream in PacePicker + ProgramSetupSubflow
            // (both of which now read sleep).
            isGLP1User:       ProgramGoalCalculator.isGLP1User(from: paywallGlp1Status),
            isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(from: paywallHormonalStage)
        ))
        return window.weeks(for: tier) * 7
    }

    private var goalSolvableInTwelveWeeks: Bool {
        guard let record = currentUserRecord,
              let current = record.onboardingCurrentWeightKg,
              let goal = record.onboardingGoalWeightKg,
              current > goal else {
            return false  // no goal set, or maintain/gain mode
        }
        let kgToLose = current - goal
        // ACSM 0.5-1%/wk → ~0.75 kg/wk for a 75kg starting weight.
        // 12 weeks at 0.75 kg/wk = ~9kg. Anything more requires >12 weeks.
        let weeksAtSustainablePace = kgToLose / (current * 0.0075)
        return weeksAtSustainablePace <= 12
    }

    // MARK: Pricing display

    /// Localized price for the yearly card ("$49.99/year" in en-US,
    /// equivalent in other locales). Falls back to v1.0.7 mock pricing
    /// when no RC package is available (debugMockPricing path) or
    /// during initial offerings load.
    private var yearlyPriceText: String {
        if !debugMockPricing, let pkg = yearlyPackage {
            return "\(pkg.storeProduct.localizedPriceString)/year"
        }
        return "$49.99/year"
    }

    /// 2026-05-30 (epic #1 child #3): quarterly tier display strings.
    /// Mirrors the yearly pattern. Apple 2026 compliance: subtitle
    /// shows the actual amount charged in the period it's charged for,
    /// no per-week math on a quarterly card.
    private var quarterlyPriceText: String {
        if let pkg = quarterlyPackage {
            return "\(pkg.storeProduct.localizedPriceString)/3 months"
        }
        return "$29.99/3 months"
    }

    private var weeklyPriceText: String {
        if !debugMockPricing, let pkg = weeklyPackage {
            return "\(pkg.storeProduct.localizedPriceString)/week"
        }
        return "$5.99/week"
    }

    private static let defaultCurrencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    /// 2026-06-27 - value + billed-amount CTA ("start my plan · $49.99/yr").
    /// The CRO teardown: a generic "continue" buries the value exchange;
    /// surfacing the billed price on the button is both higher-converting
    /// AND Apple 3.1.2-safe (the button now MATCHES the actual charge
    /// instead of hiding it). Price comes from the selected package's
    /// localized string - never hardcoded - so it stays correct across
    /// locales + any future ASC price change. Falls back to a plain label
    /// pre-load so we never show a stale or invented number.
    /// Billed price + cadence for the CTA suffix ("$49.99/yr"). Localized,
    /// never hardcoded; nil pre-load so we never invent a number.
    private var ctaPriceSuffix: String? {
        guard let pkg = selectedPackage else { return nil }
        let price = pkg.storeProduct.localizedPriceString
        let suffix: String
        switch selectedPlan {
        case .yearly:    suffix = "/yr"
        case .quarterly: suffix = "/3mo"
        case .weekly:    suffix = "/wk"
        }
        return "\(price)\(suffix)"
    }

    /// CTA label as composed Text - "start my plan" LEADS at full
    /// contrast; the billed price follows at 62% so the action reads
    /// first while the (Apple-3.1.2-safe) price stays visible.
    private var ctaText: Text {
        let lead = Text("start my plan")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Palette.textInverse)
        if let suffix = ctaPriceSuffix {
            return lead
                + Text("  \u{00B7}  \(suffix)")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Palette.textInverse.opacity(0.62))
        }
        return lead
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bgPrimary.ignoresSafeArea()

            // 2026-06-29 premium design polish (2-designer consensus). The
            // screen is now zoned by emotional register so each band does
            // one job cleanly:
            //   ZONE 1 (warm / coquette) - identity hero + the becoming
            //     PROJECTION as the emotional peak (animated curve, arrival
            //     bloom, bookended you-today / her-date axis). ONE glossy
            //     sticker by the headline + ONE bloom at the arrival = the
            //     only two stickers on the screen.
            //   ZONE 2 (medical-grade restraint) - "what's inside your
            //     becoming", 3 short warm lines, hairline ticks, no sticker.
            //   ZONE 3 (Tiffany-clean) - yearly HERO card, quiet secondary
            //     pair, the cocoa CTA as the one dark mass, money-back row.
            //
            // More content than the v2 single-screen (bigger chart + the 3
            // feature lines), so the scrollable body is partitioned from a
            // DOCKED close (CTA + risk reversal + legal). .safeAreaInset is
            // unreliable under the ignoresSafeArea bg ZStack here - this is
            // the VStack{ ScrollView; docked } pattern Assessment /
            // PacePicker presentations use.
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Status bar + topBar (Restore) reserve so the
                        // hero always clears the Dynamic Island.
                        Spacer().frame(height: 44)

                        // ZONE 1 - warm / coquette
                        heroPermission
                            .overlay(alignment: .topTrailing) { headlineSticker }
                            .padding(.horizontal, Space.lg)

                        projectionHero
                            .padding(.horizontal, Space.lg)
                            .padding(.top, 16)

                        // The chart's conclusion - pulled tight to the
                        // projection so it reads as the curve's caption,
                        // not a fresh section.
                        sunkCostLine
                            .padding(.horizontal, Space.lg)
                            .padding(.top, 10)

                        // ZONE 2 - medical-grade restraint
                        whatsInsideSection
                            .padding(.horizontal, Space.lg)
                            .padding(.top, 22)

                        // ZONE 3 - Tiffany-clean pricing. The yearly hero
                        // sits within the first viewport so the billed
                        // price anchors on load; the secondary pair + legal
                        // are one short scroll below.
                        tierCardAnnualHero
                            .padding(.horizontal, Space.lg)
                            .padding(.top, 22)

                        // Gap to the secondary pair is larger than the gap
                        // WITHIN the pair (8pt) so the yearly hero reads as
                        // the obvious default.
                        secondaryTierRow
                            .padding(.horizontal, Space.lg)
                            .padding(.top, 16)

                        if offeringsLoadFailed {
                            offeringsLoadFailedRow
                                .padding(.horizontal, Space.lg)
                                .padding(.top, 10)
                        }

                        trustAndLegalFooter
                            .padding(.horizontal, Space.lg)
                            .padding(.top, 16)
                            .padding(.bottom, 8)
                    }
                }

                // Docked close - CTA + risk reversal always visible,
                // never clipped. A hairline + soft lift marks the boundary
                // so content scrolling beneath reads as a deliberate layer.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.5)
                        .frame(maxWidth: .infinity)
                    ctaButtonV2
                        .padding(.horizontal, Space.lg)
                        .padding(.top, 12)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.stateBad)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .padding(.top, 6)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    reassuranceRow
                        .padding(.horizontal, Space.lg)
                        .padding(.top, 12)
                        .padding(.bottom, 8)
                }
                .background(Palette.bgPrimary)
            }

            topBar
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
        }
        .sheet(item: $legalDoc) { doc in
            SafariView(url: doc.url).ignoresSafeArea()
        }
        .alert(item: $restoreAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message),
                  dismissButton: .default(Text("OK")))
        }
        .task {
            Analytics.captureScreen("Paywall")
            viewOpenTime = Date()
            await loadOfferings()
            // 2026-06-15: annual is now the default for every cohort.
            // RC mix (6/6/6 even split since v2 launch) confirmed the
            // paywall wasn't anchoring; the prior quarterly auto-default
            // for goalSolvableInTwelveWeeks users was permanently
            // disqualifying them from the annual 3-day trial via Apple's
            // "one intro per group" rule. Annual at $47.99/yr has the
            // highest LTV of the three tiers; defaulting here gates the
            // higher-LTV path while quarterly stays one tap away.
        }
    }

    // MARK: - v2 single-screen helpers (2026-05-31 redesign)
    //
    // 8-slot no-scroll layout for iPhone 14+ (~720pt usable). Built from
    // 2026 luxury-comp teardown (Glossier, Hims/Hers, Cal AI April 2026)
    // + behavioral research synthesis: identity hero → reflected onboarding
    // answer → commitment-ladder bar → horizontal pricing row → conditional
    // trial timeline → near-black CTA → risk reversal + legal. Drops the
    // StickerScatter (no illustration on paywall above-fold per luxury
    // convention), the chip strip (down to 44pt caption), and the
    // testimonial (no real source available).

    // MARK: - 2026-06-06 single-screen helpers
    //
    // Built from the two-expert paywall research (UX + monetization,
    // saved at docs/paywall_research_*_2026_06_06.md). Cuts step 1
    // (commitment-only) and the 3-card horizontal pricing row in favor
    // of a projection-as-hero composition with the alt plans behind a
    // drawer. Single screen, no scroll, iPhone 13 mini compatible.

    /// Quarterly-anchor-aligned hero. 2026-06-06 v3 — subhead dropped
    /// (UX brief: "headline alone carries voice"). Italic-Fraunces on
    /// "your"; hearts ♥ as terminal punctuation per voice locks.
    private var heroPermission: some View {
        // v9 P9.7 — bumped from 28pt to displayHero (52pt Light + 52pt
        // SemiBoldItalic) so the paywall hero lands at the her75 scale
        // matching the rest of the program-design chapter we just shipped.
        // 28pt read like body copy at the hero slot; 52pt with tight
        // negative leading reads as the her75 "headline alone carries
        // voice" register the v3 brief called for.
        // v3 P11.6 (2026-06-10) — promoted to heroHeadline 42pt
        // SemiBold for parity with the rest of the onboarding hero
        // register. Was 38pt Light (displayHero); the visual hierarchy
        // now reads as: onboarding hero (42pt) → paywall hero (42pt,
        // same) — no inconsistent step-down between reveal and
        // paywall. Celebration peak (ChapterCompleteView 52pt) is
        // the only register that earns the next step up.
        let parts = headlineParts
        return ItalicAccentText(
            parts.base,
            italic: parts.italic,
            baseFont: Typo.heroHeadline,
            italicFont: Typo.heroHeadlineItalic,
            alignment: .center
        )
        .lineSpacing(Typo.heroHeadlineLineGap)
        .tracking(-0.4)
        .padding(.horizontal, 8)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    /// 2026-06-29 - PROJECTION-as-becoming-moment. The single highest-
    /// leverage element on the screen, now the emotional hero. The
    /// animated curve draws in on appear with a soft rose area fill, the
    /// arrival blooms a glossy sticker last, and the axis is bookended
    /// with identity ("you, today" → "her, sep 14") so the chart literally
    /// tells the becoming story. The arrival DATE is the JeniHeroSerif
    /// italic dusty-rose punch at the curve terminus (single instance - the
    /// old duplicate top stat row is gone). The raw goal number is DEMOTED
    /// into a small pill anchored at the endpoint; the "~x lb/wk · steady
    /// pace" honesty qualifier stays (data-provenance + compliance safe).
    /// Renders only when a weight-loss goal was set.
    @ViewBuilder
    private var projectionHero: some View {
        if let goal = goalWeightPunch, let date = arrivalDatePunch {
            VStack(spacing: 14) {
                PaywallBecomingChart(goalLabel: goal)

                // Bookended identity axis - the axis tells the becoming
                // story. Date leads as the rose-italic hero; the scale
                // number supports from the endpoint pill above.
                HStack(alignment: .bottom) {
                    (Text("you, ")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                     + Text("today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textPrimary))
                    Spacer(minLength: 12)
                    (Text("her, ")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                     + Text(date)
                        .font(.custom("JeniHeroSerif-Italic", size: 22))
                        .foregroundStyle(Palette.accent))
                }

                if let caption = paceCaption {
                    Text(caption)
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 20, style: .continuous)
                            .stroke(Palette.accent.opacity(0.22), lineWidth: 1)
                    )
            )
            .plankShadow()
        }
    }

    /// "~1.2 lb/wk · steady pace" - derived from her own current weight +
    /// picked pace via the canonical ProjectionMath. Honest hedge that
    /// frames the curve as a projection, never a promise. Nil when no loss
    /// goal is set.
    private var paceCaption: String? {
        guard let currentKg = currentUserRecord?.onboardingCurrentWeightKg,
              let goalKg = currentUserRecord?.onboardingGoalWeightKg,
              currentKg > goalKg else { return nil }
        let unit = WeightUnit.current
        let perWeek = unit.display(fromKg: currentKg * ProjectionMath.weeklyFraction(paceKey: paywallPaceChoice))
        let s = (perWeek == perWeek.rounded()) ? String(format: "%.0f", perWeek) : String(format: "%.1f", perWeek)
        return "~\(s) \(unit.label)/wk \u{00B7} \(ProjectionMath.paceLabel(paceKey: paywallPaceChoice))"
    }

    /// ONE glossy sticker by the headline - the single coquette accent in
    /// ZONE 1. Confident (full) opacity per the "no smudges" rule; the
    /// edge-scatter ghosts were removed in this pass.
    private var headlineSticker: some View {
        Image("sticker_bow_iridescent")
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(width: 30, height: 30)
            .rotationEffect(.degrees(10))
            .offset(x: 4, y: 2)
            .accessibilityHidden(true)
    }

    /// ZONE 2 - "what's inside your becoming": 3 short warm noun-phrases,
    /// not a SaaS checklist. Tracked-caps micro-label + hairline cocoa
    /// ticks, no icons, no stickers (medical-grade restraint). References
    /// only shipping features.
    private var whatsInsideSection: some View {
        VStack(alignment: .leading, spacing: 11) {
            Text("what's inside your becoming")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.6)
                .textCase(.uppercase)
                .foregroundStyle(Palette.cocoaTertiary)
            VStack(alignment: .leading, spacing: 9) {
                whatsInsideRow("your custom plan")
                whatsInsideRow("jenimethod lessons")
                whatsInsideRow("snap-a-photo food log")
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func whatsInsideRow(_ text: String) -> some View {
        HStack(spacing: 12) {
            Rectangle()
                .fill(Palette.cocoaTertiary)
                .frame(width: 13, height: 1)
            Text(text)
                .font(.custom("JeniHeroSerif-Regular", size: 16))
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
        }
    }

    /// Picked pace - drives the arrival-date projection so the paywall
    /// date matches every other surface (single source of truth in
    /// ProjectionMath). Empty key anchors at steady (0.75%/wk).
    @AppStorage(ProjectionMath.paceDefaultsKey) private var paywallPaceChoice: String = ""

    /// Goal weight as a display-type punch ("145 lb"). Her own entered
    /// goal - a fact, not a projection. Nil when no loss goal set.
    private var goalWeightPunch: String? {
        guard let goalKg = currentUserRecord?.onboardingGoalWeightKg,
              let currentKg = currentUserRecord?.onboardingCurrentWeightKg,
              currentKg > goalKg else { return nil }
        let unit = WeightUnit.current
        let v = unit.display(fromKg: goalKg)
        let s = (v == v.rounded()) ? String(format: "%.0f", v) : String(format: "%.1f", v)
        return "\(s) \(unit.label)"
    }

    /// Projected arrival date ("sep 14"), via the canonical ProjectionMath
    /// so it matches the curve endpoint + every onboarding surface. Nil
    /// when no loss goal set. Framed as a projection by the qualifier.
    private var arrivalDatePunch: String? {
        guard let goalKg = currentUserRecord?.onboardingGoalWeightKg,
              let currentKg = currentUserRecord?.onboardingCurrentWeightKg,
              currentKg > goalKg else { return nil }
        return ProjectionMath.formattedShortDate(
            currentKg: currentKg, goalKg: goalKg, paceKey: paywallPaceChoice
        )
    }

    /// 2026-06-27 - cashes the 53-screen onboarding sunk cost. Identity /
    /// ownership only ("your plan is ready." / "built from your answers,
    /// not a template.") - no claim, no number. Italic-Fraunces lands on
    /// the single punch word "ready" per the locked voice signal.
    private var sunkCostLine: some View {
        VStack(spacing: 3) {
            ItalicAccentText(
                "your plan is ready.",
                italic: ["ready"],
                baseFont: .system(size: 16, weight: .semibold),
                italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 16),
                color: Palette.textPrimary,
                alignment: .center
            )
            Text("built from your answers, not a template.")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    /// Derived strikethrough + savings copy for the anchor line. Returns
    /// nil when we can't compute (missing package, non-positive savings,
    /// debugMockPricing without packages). Quarterly annualized (×4) is
    /// the labeled, derivable anchor - defensible, not fabricated.
    private var quarterlyAnchorCopy: (strikethrough: String, savings: String)? {
        guard let yearly = yearlyPackage, let quarterly = quarterlyPackage else { return nil }
        let yearlyPrice = yearly.storeProduct.price as NSDecimalNumber
        let formatter = yearly.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
        let quarterlyAnnualized = (quarterly.storeProduct.price as NSDecimalNumber)
            .multiplying(by: NSDecimalNumber(value: 4))
        let savings = quarterlyAnnualized.subtracting(yearlyPrice)
        guard quarterlyAnnualized.doubleValue > 0, savings.doubleValue > 0 else { return nil }
        guard let strikethroughStr = formatter.string(from: quarterlyAnnualized),
              let savingsStr = formatter.string(from: savings) else { return nil }
        return (strikethroughStr, savingsStr)
    }

    /// 2026-06-27 - derived per-day equivalent for the YEARLY card.
    /// Apple 3.1.2c (Cal AI was PULLED in April 2026 for violating it):
    /// the per-day number must read SMALLER + less prominent than the
    /// actually-billed amount. Here it renders at 11pt vs the $49.99 at
    /// 28pt. Math is the live product price / 365 - never hardcoded - so
    /// it tracks any future ASC price change. Nil pre-load so we never
    /// invent a number.
    private var yearlyPerDayText: String? {
        guard let yearly = yearlyPackage else { return nil }
        let price = yearly.storeProduct.price as NSDecimalNumber
        let formatter = yearly.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
        let perDay = price.dividing(by: NSDecimalNumber(value: 365))
        guard let s = formatter.string(from: perDay) else { return nil }
        return "about \(s)/day"
    }

    /// Yearly HERO card - full-width, tall, highest-contrast, pre-selected
    /// (annual is the default in `.task`). 2026-06-27 conversion redesign:
    /// the prior layout made the 12-week card the largest/most-central
    /// object, so center-stage bias pushed buyers onto the worst-LTV tier.
    /// Yearly now reads as the obvious default at a glance. Carries the
    /// BEST badge, the per-day reframe (compliantly smaller than $49.99),
    /// and the LABELED anchor (strikethrough tied to the yearly card +
    /// "vs paying quarterly all year" so the reference is defensible, not
    /// fabricated).
    private var tierCardAnnualHero: some View {
        let isSelected = selectedPlan == .yearly
        return Button {
            Haptics.light()
            withAnimation(Motion.tap) { selectedPlan = .yearly }
        } label: {
            VStack(spacing: 10) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        HStack(spacing: 6) {
                            Text("Yearly")
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                            Text("BEST")
                                .font(.system(size: 8, weight: .bold))
                                .tracking(0.8)
                                .foregroundStyle(Palette.textInverse)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(Palette.bgInverse, in: Capsule())
                        }
                        Text("billed yearly")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    Spacer(minLength: 0)
                    // The billed amount stays the dominant number on the
                    // whole screen; per-day sits directly under it for a
                    // clean $49.99 → $0.14/day vertical sweep. "/yr" is
                    // quieter (cocoa-tertiary) so the figure leads.
                    VStack(alignment: .trailing, spacing: 2) {
                        HStack(alignment: .firstTextBaseline, spacing: 2) {
                            Text(yearlyPrice)
                                .font(.custom("Fraunces72pt-SemiBold", size: 28))
                                .foregroundStyle(Palette.textPrimary)
                            Text("/yr")
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.cocoaTertiary)
                        }
                        if let perDay = yearlyPerDayText {
                            // per-day reframe - deliberately 11pt, far
                            // smaller than the 28pt billed price (3.1.2c).
                            Text(perDay)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.textSecondary)
                        }
                    }
                }

                if let anchor = quarterlyAnchorCopy {
                    HStack(spacing: 6) {
                        // Quieted anchor - small + cocoa-tertiary + struck,
                        // so it informs without shouting a second price.
                        (Text(anchor.strikethrough)
                            .strikethrough(true, color: Palette.cocoaTertiary)
                         + Text("  vs paying quarterly all year"))
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.cocoaTertiary)
                        Spacer(minLength: 0)
                        // "save" gets a quiet rose-tinted pill (a visual
                        // home) - NOT saturated accent text; rose is
                        // reserved for emotion (the date / identity).
                        Text("save \(anchor.savings)")
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Capsule().fill(Palette.accentSubtle))
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Palette.bgElevated)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(
                                isSelected ? Palette.bgInverse : Palette.textSecondary.opacity(0.18),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    // Cocoa (not rose) selection mark - keeps rose
                    // reserved for emotion + reads Tiffany-clean against
                    // the cocoa selected border.
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Palette.bgInverse)
                        .background(Palette.bgElevated, in: Circle())
                        .offset(x: 6, y: -8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Secondary row - 12-week + weekly as clearly subordinate options.
    /// Smaller, lower-contrast (hairline border, muted titles, 17pt price
    /// vs the yearly hero's 28pt) so the yearly card stays the visual
    /// hero. Both still fully selectable.
    private var secondaryTierRow: some View {
        // 8pt within-pair gap - deliberately tighter than the 16pt gap
        // separating this pair from the yearly hero above.
        HStack(spacing: 8) {
            secondaryTierCard(
                plan: .quarterly, title: "12-week",
                price: quarterlyPrice, period: "/3 mo", sub: "billed once"
            )
            secondaryTierCard(
                plan: .weekly, title: "Weekly",
                price: weeklyPrice, period: "/wk", sub: "billed weekly"
            )
        }
        .frame(maxWidth: .infinity)
    }

    private func secondaryTierCard(
        plan: Plan, title: String, price: String, period: String, sub: String
    ) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            Haptics.light()
            withAnimation(Motion.tap) { selectedPlan = plan }
        } label: {
            VStack(spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(price)
                        .font(.custom("Fraunces72pt-SemiBold", size: 17))
                        .foregroundStyle(Palette.textPrimary)
                    Text(period)
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.textSecondary)
                }
                Text(sub)
                    .font(.system(size: 9))
                    .foregroundStyle(Palette.textSecondary.opacity(0.8))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Palette.bgElevated.opacity(isSelected ? 1 : 0.45))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(
                                isSelected ? Palette.bgInverse : Palette.textSecondary.opacity(0.12),
                                lineWidth: isSelected ? 1.5 : 0.5
                            )
                    )
            )
            .overlay(alignment: .topTrailing) {
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.bgInverse)
                        .background(Palette.bgElevated, in: Circle())
                        .offset(x: 5, y: -5)
                }
            }
        }
        .buttonStyle(.plain)
    }

    /// Compact two-line footer combining the trust microline and the
    /// terms · privacy legal links. Saves ~16pt over rendering both
    /// as separate sections.
    // v4.5 (2026-06-11) — fear-cohort closing line. The psychometric
    // yes-flags (cases 171-173) finally cash out: the last line she
    // reads before the CTA speaks to the fear she named. Falls back
    // to the generic data line when no fear was surfaced.
    @AppStorage("onb_fear_quickResults") private var fearQuickResults: String = ""
    @AppStorage("onb_fear_anotherDiet")  private var fearAnotherDiet: String = ""
    @AppStorage("onb_fear_priorAttempt") private var fearPriorAttempt: String = ""

    private var closingLine: String {
        if fearAnotherDiet == "yes"  { return "not another diet. a program that ends · no ads, ever" }
        if fearPriorAttempt == "yes" { return "built for the day you'd usually quit · no ads, ever" }
        if fearQuickResults == "yes" { return "no overnight promises. just a real pace · no ads, ever" }
        return "your data stays yours · no ads, ever"
    }

    private var trustAndLegalFooter: some View {
        // ZONE 3 stays Tiffany-clean - no sticker in the closing band.
        VStack(spacing: 4) {
            Text(closingLine)
                .font(.system(size: 10))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: 6) {
                Button("terms") { legalDoc = .terms }
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textSecondary.opacity(0.7))
                    .buttonStyle(.plain)
                Text("·")
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textSecondary.opacity(0.5))
                Button("privacy") { legalDoc = .privacy }
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textSecondary.opacity(0.7))
                    .buttonStyle(.plain)
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// 2026-06-27 - confident reassurance row, directly UNDER the CTA.
    /// Previously the lowest-contrast text on the screen; the money-back
    /// guarantee + cancel-anytime are the risk-reversal that closes the
    /// sale, so they now read legibly (textPrimary lead line, small
    /// shield icon). No trial copy - pay-upfront, billed today. Heart is
    /// dusty-rose terminal punctuation per the locked voice signal.
    private var reassuranceRow: some View {
        VStack(spacing: 5) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.accent)
                Text("billed today \u{00B7} cancel anytime")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
            }
            (Text("not happy? we offer a money-back guarantee ")
                .font(.system(size: 12))
                .foregroundStyle(Palette.textSecondary)
             + Text("\u{2665}\u{FE0E}")
                .font(.system(size: 12))
                .foregroundStyle(Palette.accent))
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    private var quarterlyPrice: String {
        quarterlyPriceText.replacingOccurrences(of: "/3 months", with: "")
    }

    /// Slot 8 — near-black CTA. Solid Palette.textPrimary (#3D2A2A), cream
    /// label, 14pt corners, 56pt tall. 2026 luxury convention (Hims/Hers,
    /// Glossier, Cal AI). Replaces the warm-red maroon pill (read as
    /// femtech 2020).
    private var ctaButtonV2: some View {
        Button {
            Haptics.light()
            working = true
            Task { await purchase() }
        } label: {
            ZStack {
                ctaText
                    .tracking(0.3)
                    .opacity(working ? 0 : 1)
                if working {
                    PulsingDots(color: Palette.textInverse)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 56)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.textPrimary)
            )
            // Barely-there inner top gloss - a single specular highlight
            // so the cocoa mass reads as a pressed, premium surface.
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.white.opacity(0.10), Color.white.opacity(0.0)],
                            startPoint: .top,
                            endPoint: .center
                        )
                    )
                    .allowsHitTesting(false)
            )
        }
        .buttonStyle(PressFeedbackStyle())
        .disabled(working)
        .accessibilityLabel(ctaPriceSuffix.map { "start my plan, \($0)" } ?? "start my plan")
    }

    // MARK: - Compact paywall helpers

    /// First-name extraction. Splits on whitespace and lowercases for
    /// the JeniFit voice — even a user typing "Sarah Smith" reads as
    /// "sarah" in peer voice. Falls back to "" so headlineParts
    /// gracefully drops the "hi {name}." prefix.
    private var displayFirstName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }
        return trimmed
            .split(separator: " ").first
            .map { String($0).lowercased() } ?? ""
    }

    // MARK: - Top bar (close + restore)

    private var topBar: some View {
        HStack {
            if dismissable {
                Button {
                    Haptics.light()
                    Analytics.track(.paywallDismissAttempted, properties: [
                        "time_on_paywall_ms": Int(Date().timeIntervalSince(viewOpenTime) * 1000)
                    ])
                    onDismiss()
                } label: {
                    // 44pt outer frame is the HIG-compliant tap target;
                    // the 32pt circle stays the visible chrome. Rageclick
                    // fix 2026-05-30: previous implementation used a 32pt
                    // outer frame + .tappableArea(), but that pattern
                    // wasn't producing the expected expanded hit area
                    // on every iOS version. Explicit 44pt closes the
                    // ambiguity (PostHog suspect #2 per #2 diagnostic).
                    ZStack {
                        Color.clear
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                        Image(systemName: "xmark")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(width: 32, height: 32)
                            .background(Palette.bgElevated, in: Circle())
                    }
                }
                .accessibilityLabel("Close paywall")
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 44, height: 44)
            }
            Spacer()
            Button {
                Haptics.light()
                Task { await restore() }
            } label: {
                Text("Restore")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary.opacity(0.55))
            }
            .buttonStyle(.plain)
        }
    }

    private var offeringsLoadFailedRow: some View {
        HStack(spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12))
                .foregroundStyle(Palette.stateWarn)
            Text("Pricing didn't load. Tap to retry.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Palette.stateWarn.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .onTapGesture {
            Task { await loadOfferings() }
        }
    }

    // MARK: Sections

    /// Yearly card price ("$49.99"). Strips the "/year" suffix used by the
    /// legacy headline text — the card subtitle already carries the
    /// billing cadence so the price reads cleanly.
    private var yearlyPrice: String {
        if !debugMockPricing, let pkg = yearlyPackage {
            return pkg.storeProduct.localizedPriceString
        }
        return "$49.99"
    }

    private var weeklyPrice: String {
        if !debugMockPricing, let pkg = weeklyPackage {
            return pkg.storeProduct.localizedPriceString
        }
        return "$5.99"
    }

    // MARK: Offerings + Purchase

    private func loadOfferings() async {
        loadingOfferings = true
        offeringsLoadFailed = false
        do {
            let offerings = try await Purchases.shared.offerings()
            // 2026-05-30: DEBUG-only v1.0.7 preview offering override.
            // Founder creates a separate RC offering called
            // "v1_0_7_preview" with the new 3-tier packages
            // (jenifit_yearly_v2 / jenifit_quarterly / jenifit_weekly_v2)
            // for visual verification on the test build BEFORE flipping
            // the production `default` offering. Existing v1.0.6 users
            // keep seeing the legacy 2-tier `default` offering — only
            // the founder's DEBUG build sees the preview. When the
            // preview offering doesn't exist (or after the founder
            // promotes its packages into `default`), this falls through
            // cleanly to `offerings.current`.
            #if DEBUG
            if let preview = offerings.all[RevenueCatConfig.previewOfferingID] {
                offering = preview
                print("[Paywall] DEBUG: using preview offering '\(RevenueCatConfig.previewOfferingID)' with \(preview.availablePackages.count) packages")
            } else {
                offering = offerings.current
            }
            #else
            offering = offerings.current
            #endif
            if offering == nil {
                Analytics.trackException(
                    NSError(domain: "Paywall", code: 1, userInfo: [NSLocalizedDescriptionKey: "offerings.current is nil"]),
                    context: "paywall.offerings_nil",
                    properties: ["expected_offering_id": RevenueCatConfig.offeringID]
                )
                #if DEBUG
                print("[Paywall] offerings returned nil current — check RC dashboard offering '\(RevenueCatConfig.offeringID)' is marked current")
                #endif
                offeringsLoadFailed = true
            }
        } catch {
            Analytics.trackException(error, context: "paywall.offerings_load")
            #if DEBUG
            print("[Paywall] offerings load FAILED: \(error)")
            #endif
            offeringsLoadFailed = true
        }
        loadingOfferings = false
    }

    /// Real RevenueCat purchase. userCancelled → silent return, no UI.
    /// Successful purchase → onSubscribed() callback (the cover dismisses
    /// when PaymentService.hasProAccess flips via customerInfoStream
    /// regardless, but the callback gives the parent a chance to do
    /// post-purchase routing). Errors → friendly inline message + log.
    private func purchase() async {
        // 2026-05-30: re-entrancy guard removed. The CTA button now sets
        // `working = true` synchronously before spawning this Task, so by
        // the time we get here `working` is always true. The Button's
        // `.disabled(working)` modifier kicks in on the same frame,
        // closing the double-tap race that the old guard was patching.
        let timeOnPaywallMs = Int(Date().timeIntervalSince(viewOpenTime) * 1000)
        Analytics.track(.paywallCtaTapped, properties: [
            "plan": selectedPlan.rawValue,
            "time_on_paywall_ms": timeOnPaywallMs
        ])
        guard let package = selectedPackage else {
            errorMessage = "Couldn't load pricing. Check your connection and try again."
            working = false  // explicit reset since defer below won't run on this early return path
            return
        }
        errorMessage = nil
        defer { working = false }

        do {
            // Fire `purchase_sheet_shown` immediately before the await.
            // RevenueCat presents Apple's purchase sheet during this call;
            // logging here captures "we asked StoreKit to handoff" so the
            // funnel diff (paywall_cta_tapped → purchase_sheet_shown →
            // purchase_completed) makes any future Day-2-zero-class
            // regression visible at a glance.
            Analytics.track(.purchaseSheetShown, properties: [
                "plan": selectedPlan.rawValue,
                "product_id": package.storeProduct.productIdentifier
            ])
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                // User dismissed Apple's purchase sheet — surface the
                // downsell so they have a discounted path before falling
                // off entirely. Parent's onPurchaseCancelled is the
                // signal; this view doesn't know what to present.
                onPurchaseCancelled()
                return
            }
            let isActive = result.customerInfo
                .entitlements[RevenueCatConfig.entitlementID]?.isActive == true
            #if DEBUG
            print("[FUNNEL] paywall_purchase_completed | isActive=\(isActive) | productId=\(package.storeProduct.productIdentifier)")
            #endif
            if isActive {
                Haptics.success()
                onSubscribed()
            } else {
                errorMessage = "Purchase didn't activate Pro. Try again or contact support@jenifit.app."
            }
        } catch {
            Analytics.trackException(error, context: "paywall.purchase",
                                     properties: ["plan": selectedPlan.rawValue])
            #if DEBUG
            print("[Paywall] purchase FAILED: \(error)")
            #endif
            errorMessage = "Couldn't complete purchase. Try again in a moment."
        }
    }

    /// Restore an existing subscription. On success with an active
    /// entitlement → fires the parent's onSubscribed callback (the cover
    /// dismisses on hasProAccess flip). On success with no active sub →
    /// surfaces a friendly alert pointing the user to sign in to the
    /// right Apple ID.
    private func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            let isActive = info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
            if isActive {
                Haptics.success()
                // v1.1.1 — a restore by definition means a returning
                // paid user. Stamp the coach-intro idempotency key
                // BEFORE firing onSubscribed so the post-purchase
                // flow's `shouldShowOnPurchase` gate evaluates to
                // false even when local SwiftData hasn't hydrated
                // yet (fresh install + restore happens before
                // AppSync.onAuthChanged completes its hydrate). The
                // bug this prevents: a returning user who restored
                // on a fresh device was seeing the "DAY 1 WITH JENI"
                // coach intro again because the local activity check
                // returned false against an empty store.
                CoachIntroState.markShown()
                // PaywallView owns the restore call now (was: parent's
                // onRestore callback). On a successful restore that
                // activates Pro, fire onSubscribed so the parent
                // dismisses + handles post-purchase routing the same
                // way it does after a purchase.
                onSubscribed()
            } else {
                restoreAlert = RestoreAlert(
                    title: "No active subscription found",
                    message: "Sign in to the Apple ID with your purchase to restore."
                )
            }
        } catch {
            Analytics.trackException(error, context: "paywall.restore")
            #if DEBUG
            print("[Paywall] restore FAILED: \(error)")
            #endif
            restoreAlert = RestoreAlert(
                title: "Couldn't restore",
                message: "Something went wrong checking your subscription. Try again in a moment."
            )
        }
    }
}

// MARK: - PaywallBecomingChart (2026-06-29 projection-as-becoming hero)
//
// The paywall's emotional peak. Reuses the canonical BecomingCurveShape /
// BecomingCurveFillShape (so the curve matches the onboarding reveal) but
// composes a richer hero treatment for the money screen:
//   • soft rose AREA fill under the curve, fading to nothing at baseline
//   • the stroke DRAWS ON over ~700ms ease-out from today → arrival
//   • a small hollow "today" dot anchors the start
//   • the arrival BLOOMS LAST - a glossy sticker that springs in, marking
//     "her"; the goal weight rides a small pill anchored above the
//     terminus (DEMOTED, never the biggest element)
//
// Numbers are never faked: the goal pill is her own entered goal, the
// curve shape is the shared projection curve. Reduce-Motion snaps to the
// fully drawn + bloomed state (no draw-on, no spring).
private struct PaywallBecomingChart: View {
    /// Her entered goal weight as a display string ("151 lb").
    let goalLabel: String
    var height: CGFloat = 84

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var drawn = false
    @State private var bloom = false

    var body: some View {
        GeometryReader { geo in
            // Terminus matches BecomingCurveShape's internal insets
            // (rightX = maxX - 24, bottomY = maxY - 14).
            let endX = geo.size.width - 24
            let endY = geo.size.height - 14

            ZStack(alignment: .topLeading) {
                BecomingCurveFillShape()
                    .fill(
                        LinearGradient(
                            colors: [
                                Palette.accent.opacity(0.12),
                                Palette.accent.opacity(0.0)
                            ],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .opacity(drawn ? 1 : 0)

                BecomingCurveShape()
                    .trim(from: 0, to: drawn ? 1 : 0)
                    .stroke(
                        Palette.accent,
                        style: StrokeStyle(lineWidth: 2.5, lineCap: .round)
                    )

                // hollow "today" dot - the line leaves from "now"
                Circle()
                    .fill(Palette.bgElevated)
                    .overlay(Circle().stroke(Palette.cocoaSecondary, lineWidth: 1.5))
                    .frame(width: 9, height: 9)
                    .position(x: 4, y: 7)
                    .opacity(drawn ? 1 : 0)

                // goal weight anchored in a small pill above the terminus
                Text(goalLabel)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Palette.accentSubtle))
                    .fixedSize()
                    .position(x: endX - 10, y: max(14, endY - 30))
                    .opacity(bloom ? 1 : 0)

                // arrival bloom - the ONE glossy sticker marking "her"
                Image("sticker_flower_3d")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 30, height: 30)
                    .rotationEffect(.degrees(-6))
                    .scaleEffect(bloom ? 1 : 0.4)
                    .opacity(bloom ? 1 : 0)
                    .position(x: endX, y: endY)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("a gentle weight-loss curve from today to your goal of \(goalLabel)")
        .onAppear {
            if reduceMotion {
                drawn = true
                bloom = true
                return
            }
            withAnimation(.easeOut(duration: 0.7)) { drawn = true }
            // the endpoint blooms last, overlapping the end of the draw
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.62)) {
                bloom = true
            }
        }
    }
}
