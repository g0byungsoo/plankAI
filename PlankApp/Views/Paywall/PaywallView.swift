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
            let punch = "weight-loss story"
            let base = "\(namePrefix)your \(punch) starts today."
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

    /// Localized price for the yearly card ("$47.99/year" in en-US,
    /// equivalent in other locales). Falls back to v1.0.7 mock pricing
    /// when no RC package is available (debugMockPricing path) or
    /// during initial offerings load.
    private var yearlyPriceText: String {
        if !debugMockPricing, let pkg = yearlyPackage {
            return "\(pkg.storeProduct.localizedPriceString)/year"
        }
        return "$47.99/year"
    }

    /// v1.1.1 (2026-06-19) — localized renewal-amount text used in
    /// the day-3 trial-end timeline row. Mirrors `yearlyPriceText`
    /// but in the "$XX.XX/yr" short form that fits the line. Falls
    /// back to the US mock when no package is loaded so the row
    /// always reads complete (never " trial ends · /yr").
    private var trialEndChargeText: String {
        if !debugMockPricing, let pkg = yearlyPackage {
            return "\(pkg.storeProduct.localizedPriceString)/yr"
        }
        return "$47.99/yr"
    }

    /// 2026-05-30 (epic #1 child #3): quarterly tier display strings.
    /// Mirrors the yearly pattern. Apple 2026 compliance: subtitle
    /// shows the actual amount charged in the period it's charged for,
    /// no per-week math on a quarterly card.
    private var quarterlyPriceText: String {
        if let pkg = quarterlyPackage {
            return "\(pkg.storeProduct.localizedPriceString)/3 months"
        }
        return "$24.99/3 months"
    }

    private var quarterlySubtitle: String {
        guard let quarterly = quarterlyPackage else { return "billed quarterly" }
        return "\(quarterly.storeProduct.localizedPriceString)/3 months · billed quarterly"
    }

    /// Delta v8 D84 — total-savings framing replaces weekly-equivalent
    /// display. Apple pulled Cal AI in April 2026 specifically for the
    /// "$0.92/wk · billed $47.99/yr" pattern. JeniFit was shipping the
    /// same pattern. Switched to "save vs quarterly" total framing
    /// which is post-pull compliant per RevenueCat 2026 legal review.
    /// Math: compares yearly annualized vs quarterly × 4.
    private var yearlyPerWeekText: String {
        guard let yearly = yearlyPackage else {
            return "save vs quarterly"
        }
        let yearlyPrice = yearly.storeProduct.price as NSDecimalNumber
        let formatter = yearly.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter

        guard let quarterly = quarterlyPackage else {
            return formatter.string(from: yearlyPrice).map { "billed \($0)/year" } ?? "billed yearly"
        }
        let quarterlyAnnualized = (quarterly.storeProduct.price as NSDecimalNumber)
            .multiplying(by: NSDecimalNumber(value: 4))
        guard quarterlyAnnualized.doubleValue > 0 else {
            return "billed yearly"
        }
        let savings = quarterlyAnnualized.subtracting(yearlyPrice)
        guard savings.doubleValue > 0 else {
            return "billed yearly"
        }
        let savingsStr = formatter.string(from: savings) ?? "\(savings)"
        return "save \(savingsStr) vs quarterly"
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

    /// 2026 research-led redesign: all three plans use the same plain
    /// "continue" CTA. The literal charge details live in the disclosure
    /// line + the trial timeline — never in the button shout. This is
    /// both the highest-converting pattern (Adapty Berylo case +31%
    /// install-to-trial) and the Apple Guideline 3.1.2 safe option (no
    /// button-text mismatches with the actual transaction).
    private var ctaLabel: String { "continue" }

    /// Literal charge date for the yearly trial — "may 28" style. Three
    /// days from today per the locked 3-day trial. Lowercased to match
    /// brand voice. Removes the "when am i charged?" friction that
    /// Cal AI + Blinkist documented as the highest-impact disclosure
    /// move (Superwall case study: +30% trial-to-paid).
    private var chargeDateText: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        let charge = Calendar.current.date(byAdding: .day, value: 3, to: Date()) ?? Date()
        return formatter.string(from: charge).lowercased()
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bgPrimary.ignoresSafeArea()

            // v4 2026-05-31 — low-opacity edge sticker scatter brings
            // JeniFit coquette warmth back without competing with content.
            // Sits behind everything in the ZStack so it never affects
            // layout. 4 stickers anchored to extreme corners + mid-edges
            // at 0.35 opacity — periphery only per coquette-luxury research
            // (Co-Star, Mejuri pattern: decoration lives at margins, never
            // floats across pricing logic).
            paywallEdgeScatter
                .allowsHitTesting(false)
                .accessibilityHidden(true)

            // 2026-06-06 single-screen v3 redesign. No scroll. Horizontal
            // 3-tier row with asymmetric center-stage scaling (Quarterly
            // is taller + cream-filled, lifted above the row silhouette).
            // Per founder direction + UX/Mon v3 briefs
            // (docs/paywall_research_*_v3_2026_06_06.md). Subhead dropped;
            // $99.96 strikethrough + savings copy lifted to row-anchor
            // line above the cards where it does the discount-story work
            // BEFORE the user picks. Projection chip restored (the
            // horizontal layout left enough headroom; cutting it had
            // made the screen feel empty).
            // Composition (v4 — benefits list added above tier row):
            //   slot 1: topBar (44pt)                   — Restore
            //   slot 2: heroPermission (~52pt)          — single-line hero
            //   slot 3: becomingProjectionChip (~110pt) — commitment device
            //   slot 4: paywallBenefits (~88pt)         — 4-row always-on
            //   slot 5: pricingRowAnchorLine (~24pt)    — strikethrough+save
            //   slot 6: tierRowHorizontal (~156pt)      — 3 cards, asymmetric
            //   slot 7: trialOrPlanRecap (~88pt yearly / ~36pt others)
            //   slot 8: ctaButtonV2 (~56pt)
            //   slot 9: trustAndLegalFooter (~32pt)
            VStack(spacing: 10) {
                Spacer().frame(height: 44)  // topBar reserve

                heroPermission
                    .padding(.horizontal, Space.lg)

                becomingProjectionChip
                    .padding(.horizontal, Space.lg)

                paywallBenefits
                    .padding(.horizontal, Space.lg)

                pricingRowAnchorLine
                    .padding(.horizontal, Space.lg)

                tierRowHorizontal
                    .padding(.horizontal, Space.lg)

                trialOrPlanRecap
                    .padding(.horizontal, Space.lg)
                if offeringsLoadFailed {
                    offeringsLoadFailedRow
                        .padding(.horizontal, Space.lg)
                }

                Spacer(minLength: 0)

                ctaButtonV2
                    .padding(.horizontal, Space.lg)
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.stateBad)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)
                        .fixedSize(horizontal: false, vertical: true)
                }

                trustAndLegalFooter
                    .padding(.horizontal, Space.lg)
                    .padding(.bottom, 12)
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

    /// Compressed BecomingProjectionCard. 2026-06-06 — restored after
    /// removal in the initial v3 layout. The horizontal tier row is
    /// only 156pt (vs vertical's 224pt) so we have ~70pt of reclaimed
    /// room; cutting the chart in addition was overkill. Acts as a
    /// commitment device — the user saw the full chart on plan-reveal
    /// one beat earlier, this is reinforcement of "this is what you're
    /// buying into" right above the pricing logic. chartHeight: 50
    /// keeps the chip ~110pt total.
    @ViewBuilder
    private var becomingProjectionChip: some View {
        BecomingProjectionCard(
            currentWeightKg: currentUserRecord?.onboardingCurrentWeightKg,
            goalWeightKg: currentUserRecord?.onboardingGoalWeightKg,
            chartHeight: 50
        )
    }

    /// v4 benefits list — 4 always-on rows sitting above the tier row.
    /// Per v4 expert briefs (docs/paywall_research_*_v4_benefits_2026_06_06.md):
    /// placement above the tier row keeps screen mass constant across tier
    /// selections, which solves the "empty when Quarterly/Weekly selected"
    /// complaint structurally instead of as a per-tier patch.
    /// Italic-Fraunces punch word per row; supporting line in muted 11pt.
    /// Food row uses the established "see what fits" voice from the
    /// existing food-first paywall headline variant — Cal-AI-trained US
    /// Gen-Z cohort pattern-matches the explicit photo-to-calories
    /// outcome without triggering AI-language locks.
    private var paywallBenefits: some View {
        VStack(alignment: .leading, spacing: 8) {
            benefitRow(punch: "workouts",
                       supporting: "plank, position-block flow · 5–30 min")
            benefitRow(punch: "becoming",
                       supporting: "weight trend, steps, breathwork")
            benefitRow(punch: "food",
                       supporting: "snap a meal, see what fits")
            benefitRow(punch: "jeni method",
                       supporting: "short reads, evidence-backed")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func benefitRow(punch: String, supporting: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 5, height: 5)
                .offset(y: -2)
            (Text(punch)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13))
                .foregroundStyle(Palette.textPrimary)
             + Text(" · \(supporting)")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    /// Row-anchor line — quarterly-annualized strikethrough + savings.
    /// 2026-06-15: both numbers derived from the live RC packages so any
    /// future ASC price change updates here without a code edit. Falls
    /// back silently if either package is missing (debug / pre-load).
    private var pricingRowAnchorLine: some View {
        Group {
            if let anchor = quarterlyAnchorCopy {
                HStack(spacing: 8) {
                    Text(anchor.strikethrough)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                        .strikethrough(true, color: Palette.textSecondary)
                    Text("save \(anchor.savings) ♥")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.accent)
                }
            } else {
                EmptyView()
            }
        }
        .frame(maxWidth: .infinity)
    }

    /// Derived strikethrough + savings copy for the anchor line. Returns
    /// nil when we can't compute (missing package, non-positive savings,
    /// debugMockPricing without packages). Reuses the same math as
    /// `yearlyPerWeekText` for consistency.
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

    /// 3-tier row — Annual + Quarterly hero + Weekly. 2026-06-15: the
    /// "recommended for 12-week goal" ribbon retired with the quarterly
    /// auto-default flip, but weekly stays on the primary paywall as
    /// the low-budget gateway pending the conversion-expert review on
    /// cannibalization-vs-incremental capture. RC mix is even 6/6/6
    /// since v2 launch — no plan is dominating — so dropping any tier
    /// before we know its incrementality is premature.
    private var tierRowHorizontal: some View {
        HStack(alignment: .bottom, spacing: 8) {
            tierCardAnnualCompact
            tierCardQuarterlyHero
            tierCardWeeklyCompact
        }
        .frame(maxWidth: .infinity)
    }

    private var tierCardAnnualCompact: some View {
        let isSelected = selectedPlan == .yearly
        return Button {
            Haptics.light()
            withAnimation(Motion.tap) { selectedPlan = .yearly }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Spacer().frame(height: 12)
                    Text("Yearly")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(yearlyPrice)
                        .font(.custom("Fraunces72pt-SemiBold", size: 20))
                        .foregroundStyle(Palette.textPrimary)
                    Text("/year")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: 4)
                    Text("3-day free trial ♥")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 10)
                }
                .frame(width: 104, height: 135)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isSelected ? Palette.bgInverse : Palette.textSecondary.opacity(0.15),
                                    lineWidth: isSelected ? 2 : 0.5
                                )
                        )
                )

                Text("BEST")
                    .font(.system(size: 8, weight: .bold))
                    .tracking(0.8)
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Palette.bgInverse, in: Capsule())
                    .offset(x: -6, y: 6)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.accent)
                        .background(Palette.bgElevated, in: Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var tierCardQuarterlyHero: some View {
        let isSelected = selectedPlan == .quarterly
        return Button {
            Haptics.light()
            withAnimation(Motion.tap) { selectedPlan = .quarterly }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Spacer().frame(height: 14)
                    Text("12-week")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(quarterlyPrice)
                        .font(.custom("Fraunces72pt-SemiBold", size: 24))
                        .foregroundStyle(Palette.textPrimary)
                    Text("/3 months")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: 4)
                    Text("$0.45/day · billed once")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 12)
                }
                .frame(width: 130, height: 150)
                .background(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Palette.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .stroke(
                                    isSelected ? Palette.bgInverse : Palette.accent.opacity(0.5),
                                    lineWidth: isSelected ? 2 : 1
                                )
                        )
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.accent)
                        .background(Palette.bgElevated, in: Circle())
                        .offset(x: 6, y: -6)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var tierCardWeeklyCompact: some View {
        let isSelected = selectedPlan == .weekly
        return Button {
            Haptics.light()
            withAnimation(Motion.tap) { selectedPlan = .weekly }
        } label: {
            ZStack(alignment: .topTrailing) {
                VStack(spacing: 4) {
                    Spacer().frame(height: 12)
                    Text("Weekly")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                    Text(weeklyPrice)
                        .font(.custom("Fraunces72pt-SemiBold", size: 20))
                        .foregroundStyle(Palette.textPrimary)
                    Text("/week")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary)
                    Spacer(minLength: 4)
                    Text("pay as you go")
                        .font(.system(size: 9))
                        .foregroundStyle(Palette.textSecondary)
                        .multilineTextAlignment(.center)
                    Spacer().frame(height: 10)
                }
                .frame(width: 104, height: 135)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Palette.bgElevated)
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(
                                    isSelected ? Palette.bgInverse : Palette.textSecondary.opacity(0.15),
                                    lineWidth: isSelected ? 2 : 0.5
                                )
                        )
                )

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(Palette.accent)
                        .background(Palette.bgElevated, in: Circle())
                        .offset(x: 6, y: -6)
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
        VStack(spacing: 4) {
            HStack(spacing: 6) {
                Image("sticker_flower_3d")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 14, height: 14)
                    .rotationEffect(.degrees(-8))
                    .accessibilityHidden(true)
                Text(closingLine)
                    .font(.system(size: 10))
                    .foregroundStyle(Palette.textSecondary)
            }
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

    /// Slot 5 — trial timeline (annual selected) or plan recap (other
    /// tiers). 88pt when trial visible, 36pt when collapsed. Apple-endorsed
    /// transparency pattern (kills "when am I charged?" anxiety — Cal AI
    /// +30% trial-to-paid per Superwall case study).
    @ViewBuilder
    private var trialOrPlanRecap: some View {
        if selectedPlan == .yearly {
            expandedTrialTimeline
        } else {
            planRecapLine
        }
    }

    private var expandedTrialTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Delta v8 D80 — "no payment due now" trust chip per Cal AI
            // verbatim adoption (calai43). Per the monetization brief +
            // culture brief, this is the strongest single trial-trust
            // copy in the category. Sits above the 3-row timeline.
            HStack(spacing: 6) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                Text("no payment due now ♥")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(.bottom, 2)

            timelineLineRow(filled: true,
                            label: "today",
                            text: "unlock your becoming plan")
            timelineLineRow(filled: false,
                            label: "day 2",
                            text: "we'll remind you before anything changes")
            // v1.1.1 (2026-06-19) — pull the actual localized renewal
            // amount from the RC package instead of hardcoding $47.99.
            // Cal AI was pulled under Apple Guideline 3.1.2(a) for
            // displaying a US-formatted renewal amount that didn't
            // match the user's localized charge. The other paywall
            // prices already derive from `localizedPriceString`; this
            // copy was the only one that hard-coded.
            timelineLineRow(filled: false,
                            label: "day 3",
                            text: "trial ends · \(trialEndChargeText) or cancel anytime")
        }
        .padding(.vertical, 2)
    }

    private func timelineLineRow(filled: Bool, label: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Circle()
                .fill(filled ? Palette.accent : Palette.accent.opacity(0.3))
                .frame(width: 6, height: 6)
                .offset(y: 1)
            Text(label)
                .font(.custom("Fraunces72pt-SemiBoldItalic", size: 12))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 42, alignment: .leading)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Palette.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
    }

    private var planRecapLine: some View {
        let text: String = {
            switch selectedPlan {
            case .quarterly:
                return "12 weeks of jeni · billed once today"
            case .weekly:
                return "$5.99 a week · cancel anytime in settings"
            case .yearly:
                return ""
            }
        }()
        return HStack(spacing: 8) {
            Circle()
                .fill(Palette.accent)
                .frame(width: 6, height: 6)
            Text(text)
                .font(.system(size: 12))
                .foregroundStyle(Palette.textPrimary)
            Spacer(minLength: 0)
        }
        .padding(.vertical, 10)
    }

    /// Decorative low-opacity edge scatter — coquette warmth without
    /// crowding. Static placements (no animation drift) so it reads as
    /// quiet brand wallpaper, not as content. 0.35 opacity keeps it
    /// from competing with text. 4 stickers, all at extreme edges (top
    /// corners + bottom corners).
    private var paywallEdgeScatter: some View {
        GeometryReader { geo in
            let w = geo.size.width
            let h = geo.size.height
            ZStack {
                Image("sticker_sparkle_glossy")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 28, height: 28)
                    .rotationEffect(.degrees(-12))
                    .opacity(0.35)
                    .position(x: w * 0.07, y: h * 0.18)

                Image("sticker_bow_iridescent")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 34, height: 34)
                    .rotationEffect(.degrees(14))
                    .opacity(0.35)
                    .position(x: w * 0.94, y: h * 0.20)

                Image("sticker_heart_glossy")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(11))
                    .opacity(0.30)
                    .position(x: w * 0.06, y: h * 0.78)

                Image("sticker_star_lineart")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 24, height: 24)
                    .rotationEffect(.degrees(-10))
                    .opacity(0.35)
                    .position(x: w * 0.94, y: h * 0.80)
            }
        }
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
                Text(ctaLabel)
                    .font(.system(size: 17, weight: .semibold))
                    .tracking(0.3)
                    .foregroundStyle(Palette.textInverse)
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
        }
        .buttonStyle(PressFeedbackStyle())
        .disabled(working)
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
                    .font(Typo.caption)
                    .fontWeight(.semibold)
                    .foregroundStyle(Palette.textSecondary)
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

    /// Yearly card price ("$47.99"). Strips the "/year" suffix used by the
    /// legacy headline text — the card subtitle already carries the
    /// billing cadence so the price reads cleanly.
    private var yearlyPrice: String {
        if !debugMockPricing, let pkg = yearlyPackage {
            return pkg.storeProduct.localizedPriceString
        }
        return "$47.99"
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
                    message: "Sign in to the Apple ID with your purchase, or start a free trial to continue."
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

// BecomingCurveShape + BecomingCurveFillShape extracted 2026-05-31 to
// Views/Onboarding/BecomingProjectionCard.swift so the onboarding v2
// reveal sequence can reuse them. PaywallView now uses the standalone
// BecomingProjectionCard view directly (see becomingProjectionCard
// computed property above).
