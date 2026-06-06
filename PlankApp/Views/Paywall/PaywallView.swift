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

    @Query private var userRecords: [UserRecord]

    /// 2026-05-31 v2 single-screen redesign: drives the commitment-ladder
    /// progress bar. SessionLogRecord is the immutable source of truth for
    /// "what has the user already done." Pulled via @Query so the bar
    /// reflects any new sessions logged between paywall renders. For
    /// brand-new users at post-onboarding paywall, count = 0 and the
    /// computation below floors at 4% (counts onboarding investment).
    @Query private var sessionLogsAll: [SessionLogRecord]

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
    /// Delta v8 D78 — two-step paywall split (calai43 → calai27).
    /// Step 1 captures commitment (single CTA, no tier choice, "no
    /// payment due now" reassurance). Step 2 captures tier selection
    /// under a yes already given. +18-26% paywall→trial per Superwall
    /// 2026 cross-app data — the monetization brief's #1 lever.
    @State private var paywallStep: Int = 1
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

        // v5 weight-loss-direct hero (research Q1/Q3 winning pattern —
        // Cal AI + Noom both ship "lose X by Y" projection-framed copy).
        // Apple-safe because the verb "on track to" is a projection
        // hedge, not a promise. Punch word is "lose N lbs" to anchor
        // the outcome the user came for.
        if let lbs = weightToLoseDisplay,
           let date = projectedTargetDateText {
            let unit = WeightUnit.current.label
            let lbsInt = Int(lbs.rounded())
            let punch = "lose \(lbsInt) \(unit)"
            let base = "\(namePrefix)you're on track to \(punch) by \(date)."
            return (base, [punch])
        }

        // Graceful fallback — user without weight goal (maintain/gain mode
        // or didn't enter weights). Falls back to becoming-ritual copy.
        if first.isEmpty {
            return ("your 5-min becoming ritual starts today.", ["becoming"])
        }
        return ("\(first), your 5-min becoming ritual starts today.", ["becoming"])
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

    // MARK: - Commitment-ladder (v2 redesign 2026-05-31)
    //
    // The "you've already mapped N% of becoming" progress bar pulls real
    // session-log data through EngagementDayCalculator. Frames the price
    // as continuation, not purchase — ethical loss-aversion. Apple-safe
    // because there's no "you'll lose X" framing; it's pure surfacing of
    // work already invested.
    //
    // Calibration: 12-week becoming arc = 84 days. Brand-new users at
    // post-onboarding paywall have 0 completed sessions; the formula
    // floors at 4% so the bar isn't visually empty (4% accounts for the
    // onboarding investment itself — they spent 4+ minutes mapping this
    // plan). Caps at 100% for users who hit/exceed the 12-week mark.

    private var sessionLogsForUser: [SessionLogRecord] {
        guard let userId = auth.currentUser?.id.uuidString.lowercased(), !userId.isEmpty else {
            return sessionLogsAll
        }
        return sessionLogsAll.filter { $0.userId.lowercased() == userId }
    }

    /// Engagement percent for the becoming-ritual progress bar. Real
    /// computation: days completed out of 84 (12 weeks), with a 4% floor
    /// to surface the onboarding investment even for day-0 users.
    private var becomingPercent: Int {
        let days = EngagementDayCalculator.daysCompleted(sessionLogs: sessionLogsForUser)
        let raw = Double(days + 3) / 84.0 * 100.0  // +3 base = onboarding floor
        return max(4, min(100, Int(raw.rounded())))
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

    /// Lbs (or kg, per user preference) to lose, display-unit rounded.
    /// Nil when no goal set or in maintain/gain mode.
    private var weightToLoseDisplay: Double? {
        guard let record = currentUserRecord,
              let current = record.onboardingCurrentWeightKg,
              let goal = record.onboardingGoalWeightKg,
              current > goal else { return nil }
        return WeightUnit.current.display(fromKg: current - goal)
    }

    private var currentWeightDisplay: Double? {
        guard let record = currentUserRecord,
              let kg = record.onboardingCurrentWeightKg else { return nil }
        return WeightUnit.current.display(fromKg: kg)
    }

    private var goalWeightDisplay: Double? {
        guard let record = currentUserRecord,
              let kg = record.onboardingGoalWeightKg else { return nil }
        return WeightUnit.current.display(fromKg: kg)
    }

    /// Projected per-week loss in display units (lb default).
    /// ACSM midpoint 0.75%/wk of current body weight.
    private var perWeekLossDisplay: Double? {
        guard let record = currentUserRecord,
              let current = record.onboardingCurrentWeightKg else { return nil }
        return WeightUnit.current.display(fromKg: current * 0.0075)
    }

    /// Projected target date at the 0.75%/wk pace. Floored at 2 weeks
    /// (avoids "by next week" overpromise) and capped at 6 months
    /// (projection beyond that loses credibility).
    private var projectedTargetDate: Date? {
        guard let record = currentUserRecord,
              let current = record.onboardingCurrentWeightKg,
              let goal = record.onboardingGoalWeightKg,
              current > goal else { return nil }
        let kgToLose = current - goal
        let kgPerWeek = current * 0.0075
        guard kgPerWeek > 0 else { return nil }
        let weeksRaw = kgToLose / kgPerWeek
        let weeks = min(max(weeksRaw, 2.0), 26.0)
        return Calendar.current.date(byAdding: .day, value: Int(weeks * 7), to: Date())
    }

    private var projectedTargetDateText: String? {
        guard let date = projectedTargetDate else { return nil }
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: date).lowercased()
    }

    /// Pace label for the projection pill. Maps voicePreference → pace
    /// word the user already implicitly chose in onboarding. Italic-
    /// Fraunces punch word per brand voice lock.
    private var paceLabel: String {
        switch voicePreference {
        case "encouraging": return "gentle pace"
        case "balanced":    return "steady pace"
        case "roast":       return "ambitious pace"
        default:            return "steady pace"
        }
    }

    private func formatWeight(_ value: Double) -> String {
        if value == value.rounded() {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }

    /// 2026-05-30 (epic #1 child #6): true when the user has set a
    /// weight-loss goal that's solvable in ~12 weeks at ACSM's 0.5-1%/wk
    /// sustainable-loss pace. Drives the goal-aware default plan
    /// selection on .task — quarterly default for these users (matches
    /// the locked "3-month frame" voice signal), annual default for
    /// everyone else (no-goal, maintain-mode, or longer-horizon goals).
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
        return "\(quarterly.storeProduct.localizedPriceString)/3 months — billed quarterly"
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

            // 2026-05-31 v5 weight-loss-direct redesign. Drops feature
            // mini-grid + outcome anchor in favor of the goal-projection
            // pill — the single highest-impact mid-section element for
            // WL apps per Cal AI / Noom / Yazio teardown research.
            // Composition:
            //   slot 1: topBar (44pt, floating)
            //   slot 2: heroCompactV2 (~110pt) — weight-loss-direct copy
            //   slot 2.5: goalProjectionPill (~50pt) — current→goal · pace
            //   slot 3: reflectedAnswerCaption (~44pt) — onboarding mirror
            //   slot 4: pricingRowHorizontal (~132pt) — 3 cards across
            //   slot 5: trialOrPlanRecap (~88pt yearly, ~36pt others)
            //   slot 6: trustMicroline (~24pt) — privacy assurance
            //   slot 7: ctaButtonV2 (~56pt) — near-black rect
            //   slot 8: legalFooterCompact (~24pt) — terms · privacy
            //
            // Apple-safety lock: weight-loss copy is allowed (Cal AI was
            // pulled for deceptive billing UI, NOT for WL claims per
            // techcrunch/macrumors April 2026). All projection copy
            // hedges with "on track to" verb framing.
            if paywallStep == 1 {
                step1CommitView
            } else {
                VStack(spacing: 0) {
                    Spacer().frame(height: 56)  // topBar reserve

                    heroCompactV2
                        .padding(.horizontal, Space.lg)
                        .padding(.top, 4)

                    Spacer().frame(height: 10)

                    reflectedAnswerCaption
                        .padding(.horizontal, Space.lg)

                    Spacer().frame(height: 18)

                    pricingRowHorizontal
                        .padding(.horizontal, Space.lg)
                    if offeringsLoadFailed {
                        offeringsLoadFailedRow
                            .padding(.horizontal, Space.lg)
                            .padding(.top, 8)
                    }

                    Spacer().frame(height: 16)

                    trialOrPlanRecap
                        .padding(.horizontal, Space.lg)

                    Spacer().frame(height: 12)

                    trustMicroline
                        .padding(.horizontal, Space.lg)

                    Spacer().frame(height: 14)

                    becomingProjectionCard
                        .padding(.horizontal, Space.lg)

                    Spacer(minLength: 10)

                    ctaButtonV2
                        .padding(.horizontal, Space.lg)
                    if let errorMessage {
                        Text(errorMessage)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.stateBad)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, Space.lg)
                            .padding(.top, 6)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer().frame(height: 8)

                    legalFooterCompact
                        .padding(.horizontal, Space.lg)
                        .padding(.bottom, 12)
                }
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
            // 2026-05-30 (epic #1 child #6): goal-aware default plan.
            // Runs AFTER loadOfferings so quarterlyPackage availability
            // is resolved. In DEBUG, when debugMockPricing is on (no
            // real RC packages available), still apply the goal-aware
            // default so the founder can visually verify the quarterly-
            // default-first ordering during the pre-ASC-setup window.
            if goalSolvableInTwelveWeeks && (quarterlyPackage != nil || debugMockPricing) {
                selectedPlan = .quarterly
            }
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

    /// Delta v8 D78 — paywall step 1 (commitment-only). Single CTA,
    /// no tier choice, anxiety-neutralizing "no payment due now ♥"
    /// + 3-day timeline preview. User says yes to commit; step 2
    /// captures HOW (tier). Cal AI's calai43 → calai27 architecture.
    @ViewBuilder private var step1CommitView: some View {
        VStack(spacing: 0) {
            Spacer().frame(height: 56)

            heroCompactV2
                .padding(.horizontal, Space.lg)
                .padding(.top, 4)

            Spacer().frame(height: 18)

            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                Text("no payment due now ♥")
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
            }
            .padding(.horizontal, Space.lg)

            Spacer().frame(height: 18)

            VStack(alignment: .leading, spacing: 12) {
                timelineLineRow(filled: true,  label: "today",
                                text: "unlock your becoming plan")
                timelineLineRow(filled: false, label: "day 2",
                                text: "we'll send you one note before anything renews")
                timelineLineRow(filled: false, label: "day 3",
                                text: "trial ends · cancel anytime or stay on")
            }
            .padding(Space.md)
            .background(Palette.bgElevated, in: RoundedRectangle(cornerRadius: 16))
            .padding(.horizontal, Space.lg)

            Spacer(minLength: 16)

            Button {
                Haptics.medium()
                Analytics.track(.paywallCtaTapped, properties: [
                    "step": 1,
                    "plan": "deferred",
                ])
                withAnimation(.easeInOut(duration: 0.35)) {
                    paywallStep = 2
                }
            } label: {
                Text("continue ♥")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 17))
                    .foregroundStyle(Palette.textInverse)
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(Palette.bgInverse)
                    .clipShape(Capsule())
            }
            .padding(.horizontal, Space.lg)

            Spacer().frame(height: 12)

            legalFooterCompact
                .padding(.horizontal, Space.lg)
                .padding(.bottom, 16)
        }
    }

    /// Slot 2 — identity hero. Lighter Fraunces weight (SemiBold→Regular
    /// at 400) per 2026 luxury convention. Drops bold; bold reads
    /// discount. Includes name prefix when available. Italic-Fraunces
    /// on "becoming" punch word (locked voice signal).
    private var heroCompactV2: some View {
        let parts = headlineParts
        return VStack(spacing: 6) {
            Text("YOUR PLAN")
                .font(.system(size: 10, weight: .semibold))
                .tracking(2.4)
                .foregroundStyle(Palette.textSecondary)

            ItalicAccentText(parts.base,
                             italic: parts.italic,
                             baseFont: .custom("Fraunces72pt-Regular", size: 26),
                             italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 26),
                             alignment: .center)
                .tracking(-0.4)
                .padding(.horizontal, 8)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// Slot 3 — reflected onboarding answers as caption. 44pt, no chips,
    /// no pills, no icons. Pulls bodyFocus + pace + commitment from
    /// already-collected data. Reciprocity loop ("we listened") without
    /// announcing it. Falls back gracefully when answers missing.
    private var reflectedAnswerCaption: some View {
        let parts = reflectedAnswerParts
        return Text(parts.joined(separator: " · "))
            .font(.system(size: 12))
            .tracking(0.2)
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.center)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private var reflectedAnswerParts: [String] {
        var parts: [String] = []
        switch bodyFocus {
        case "flatBelly": parts.append("flat belly focus")
        case "tonedArms": parts.append("toned arms focus")
        case "roundButt": parts.append("round butt focus")
        case "slimLegs":  parts.append("slim legs focus")
        case "fullBody":  parts.append("full-body focus")
        default: break
        }
        if let mins = Int(sessionLengthPref), mins > 0 {
            parts.append("\(mins) min/day")
        }
        switch voicePreference {
        case "encouraging": parts.append("gentle pace")
        case "balanced":    parts.append("steady pace")
        case "roast":       parts.append("energetic pace")
        default: break
        }
        if let days = Int(commitmentDays), days > 0 {
            parts.append("\(days)-day commit")
        }
        if parts.isEmpty { parts.append("built around your 12-week becoming plan") }
        return parts
    }

    /// v6 BecomingProjectionCard — visual data-viz that fills the dead
    /// zone with app-quality demo content. Single highest-leverage paywall
    /// element for WL apps in 2026 (Noom universal pattern). Scrapbook
    /// chrome ties it to the rest of JeniFit (Home, Settings, Becoming,
    /// PreSession all use this chrome). Hand-drawn curve + flower3D
    /// endpoint = coquette warmth + clean luxury hybrid. Uses ONLY the
    /// user's own onboarding inputs — no fabricated data, no body imagery,
    /// no generic UI mockup.
    ///
    /// Replaces v5's goalProjectionPill — the card carries the same data
    /// plus visual richness, so the pill becomes redundant.
    /// Renders the standalone BecomingProjectionCard (extracted
    /// 2026-05-31 from inline-here so the onboarding v2 reveal sequence
    /// can render the same curve). Pulls kg values directly from
    /// currentUserRecord — projection card handles unit display +
    /// projection math internally.
    @ViewBuilder
    private var becomingProjectionCard: some View {
        BecomingProjectionCard(
            currentWeightKg: currentUserRecord?.onboardingCurrentWeightKg,
            goalWeightKg: currentUserRecord?.onboardingGoalWeightKg,
            voicePreference: voicePreference
        )
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
            timelineLineRow(filled: false,
                            label: "day 3",
                            text: "trial ends · $47.99/yr or cancel anytime")
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

    /// Slot 6 — trust microline + the ONE coquette sticker on paywall.
    /// flower3D glyph at left, privacy assurance text. Footer-anchored,
    /// periphery placement — Co-Star/Mejuri pattern. Privacy lines are
    /// "materially" conversion-moving for women's health (Funnelfox 2025).
    private var trustMicroline: some View {
        HStack(spacing: 8) {
            Image("sticker_flower_3d")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 16, height: 16)
                .rotationEffect(.degrees(-8))
                .accessibilityHidden(true)
            Text("your data stays yours · no ads, ever")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
    }

    /// Slot 9 — compact legal footer (terms · privacy only). The risk-
    /// reversal copy moved into the trial timeline / plan recap line, so
    /// this is just legal links. Stays muted and small.
    private var legalFooterCompact: some View {
        HStack(spacing: 8) {
            Button("terms") { legalDoc = .terms }
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary.opacity(0.7))
                .buttonStyle(.plain)
            Text("·")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary.opacity(0.5))
            Button("privacy") { legalDoc = .privacy }
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary.opacity(0.7))
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
    }

    /// Slot 5 — horizontal pricing row, 3 cards across, default first.
    /// Order: default plan (goal-aware) → remaining tiers stable. Yearly
    /// always carries the trial badge; default plan also carries the
    /// "best value" neutral badge when distinct from yearly.
    private var pricingRowHorizontal: some View {
        HStack(spacing: 10) {
            ForEach(orderedPlans, id: \.self) { plan in
                compactPricingCard(for: plan)
            }
        }
    }

    @ViewBuilder
    private func compactPricingCard(for plan: Plan) -> some View {
        // Visual weight stack on the default (first in orderedPlans):
        //   1. "MOST POPULAR" pill (small caps) anchors top-center
        //   2. 2pt warm-red border + warmer cream fill via PricingCardCompact
        //   3. "3-DAY FREE" trial badge always on yearly (independent signal)
        // Per Q3 research: stacked weight cues guarantee the recommended
        // tier visually dominates even at small card sizes — kills the
        // "cheapest looks selected" bug from v2.
        let isDefault = orderedPlans.first == plan
        let isYearly = plan == .yearly
        let badgeText: String? = {
            if isYearly { return "3-DAY FREE" }
            if isDefault { return "MOST POPULAR" }
            return nil
        }()
        let badgeKind: PricingCardCompact.BadgeKind = isYearly ? .trial : .neutral

        switch plan {
        case .yearly:
            // Anchor strikethrough = 4×$24.99 (= $99.96) genuine math,
            // not a fabricated MSRP. Apple-safe per post-Cal-AI research
            // (research Q2): anchored pricing is allowed if anchor is
            // real. $99.96 - $47.99 = $51.97 save = 52% off — real anchor
            // for users who'd otherwise pay 4 quarterly tiers.
            PricingCardCompact(
                title: "Yearly",
                price: yearlyPrice,
                subtitle: "$0.92/wk · save 52%",
                anchor: "$99.96",
                badge: badgeText,
                badgeKind: badgeKind,
                isSelected: selectedPlan == .yearly,
                isDefault: isDefault
            ) {
                Haptics.light()
                withAnimation(Motion.tap) { selectedPlan = .yearly }
            }
        case .quarterly:
            PricingCardCompact(
                title: "12-week",
                price: quarterlyPrice,
                subtitle: "$0.45/day",
                badge: badgeText,
                badgeKind: badgeKind,
                isSelected: selectedPlan == .quarterly,
                isDefault: isDefault
            ) {
                Haptics.light()
                withAnimation(Motion.tap) { selectedPlan = .quarterly }
            }
        case .weekly:
            PricingCardCompact(
                title: "Weekly",
                price: weeklyPrice,
                subtitle: "pay as you go",
                badge: badgeText,
                badgeKind: badgeKind,
                isSelected: selectedPlan == .weekly,
                isDefault: isDefault
            ) {
                Haptics.light()
                withAnimation(Motion.tap) { selectedPlan = .weekly }
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

    /// Plan order for the pricing stack — default first (per primacy
    /// bias + research), then the remaining tiers in a stable order.
    /// Weekly is never default and always last. Quarterly appears when
    /// its RC package is available OR (in DEBUG) when debugMockPricing
    /// is active so the founder can visually verify the 3-card layout
    /// before completing the ASC manual setup.
    private var orderedPlans: [Plan] {
        let quarterlyAvailable = quarterlyPackage != nil || debugMockPricing
        let defaultPlan: Plan = (goalSolvableInTwelveWeeks && quarterlyAvailable)
            ? .quarterly : .yearly
        var rest: [Plan] = [.yearly, .quarterly, .weekly].filter { $0 != defaultPlan }
        if !quarterlyAvailable {
            rest.removeAll { $0 == .quarterly }
        }
        return [defaultPlan] + rest
    }

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
