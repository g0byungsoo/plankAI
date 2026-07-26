import SwiftUI
import SwiftData
import RevenueCat
import PlankFood
import PlankSync
import Auth

// MARK: - PaywallView
//
// The no-trial KEEP wall (2026-07-07 conversion rebuild). The 48h
// post-trial-removal data: 26 paywall views → 6 CTA taps (23%, was 43%
// in the trial era) → 17 Apple sheets → 0 purchases, median 3s to
// cancel. Diagnosis: the price was visible but never CHOSEN — the
// yearly default put $47.99 on 15 of 17 sheets while the screen
// anchored "$0.14/day", so Apple's "billed today" read as a reveal,
// not a confirmation.
//
// The rebuild inverts the wall's job: the projection already happened
// one beat earlier (ProjectionPresentation), so the wall now hands her
// the keys instead of re-selling the outcome —
//   1. DAY ONE CARD — her real tomorrow (promise · protein floor ·
//      first snap), the dossier's sibling object. What she keeps.
//   2. THREE EQUAL TIER ROWS — an active choice, quarterly
//      pre-selected (the founder's 2026-06-27 pay-upfront anchor,
//      never shipped until now). Every card states its billed-TODAY
//      number; per-week equivalents render smaller (Apple 3.1.2c).
//   3. RECEIPT-CONFIRM — CTA opens an in-brand receipt (today /
//      covers / renews) so the exact charge is accepted in cream-and-
//      cocoa before StoreKit restates it in white.
//
// RevenueCat: offerings.current populates the rows by productIdentifier;
// storeProduct.localizedPriceString only — release builds NEVER render
// a hardcoded price (pre-rebuild they leaked the $49.99 mock when
// offerings failed, which could contradict the real sheet). Unresolved
// prices render skeletons and the CTA holds until pricing is real.

struct PaywallView: View {
    let dismissable: Bool
    let onSubscribed: () -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void
    /// Fired when she cancels the Apple sheet. Carries the abandoned
    /// plan raw value ("yearly" / "quarterly" / "weekly") + product id
    /// so the parent can route a tier-appropriate recovery and the
    /// abandonment event is finally tier-attributed in PostHog.
    let onPurchaseCancelled: (_ plan: String, _ productId: String?) -> Void
    /// Reopens the discounted-year sheet from the reclaim row. nil
    /// (e.g. the debug harness) hides the row entirely.
    let onReclaimDownsell: (() -> Void)?

    init(
        dismissable: Bool = true,
        onSubscribed: @escaping () -> Void,
        onRestore: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {},
        onPurchaseCancelled: @escaping (_ plan: String, _ productId: String?) -> Void = { _, _ in },
        onReclaimDownsell: (() -> Void)? = nil
    ) {
        self.dismissable = dismissable
        self.onSubscribed = onSubscribed
        self.onRestore = onRestore
        self.onDismiss = onDismiss
        self.onPurchaseCancelled = onPurchaseCancelled
        self.onReclaimDownsell = onReclaimDownsell
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
    // T2 (2026-06-29): weight trend + GLP-1 phase now move pacing.
    @AppStorage("onboarding_weight_trend") private var paywallWeightTrend: String = ""
    @AppStorage("onboarding_glp1_phase")   private var paywallGlp1Phase: String = ""
    // FIX 4 (2026-06-29): collected gender (case 130) -> BMR-formula sex.
    @AppStorage("onboardingGender")        private var paywallGender: String = ""

    // safety_screen_completed: true once she passed the pre-paywall
    // safety gate; surfaced as a quiet trust receipt near the money.
    @AppStorage("safety_screen_completed") private var safetyScreenCompleted: Bool = false
    /// True once the discounted-year sheet has auto-shown (WallView
    /// writes it). Unlocks the reclaim row — the offer is a state,
    /// not a one-shot popup.
    @AppStorage("downsellShownOnce") private var downsellUnlocked: Bool = false

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

    // Quarterly is the pre-selected tier (the founder's 2026-06-27
    // pay-upfront anchor: $24.99 billed today halves the sheet shock of
    // the $47.99 yearly default that rode 15 of 17 abandoned sheets).
    // `.task` falls back to yearly if the quarterly SKU ever leaves the
    // offering (self-gating, same rule as the card itself).
    // v6.4 (founder-directed two-plan anchor structure): yearly is
    // the designed default — pre-selected, badged, per-week framed.
    @State private var selectedPlan: Plan = .yearly
    @State private var working = false
    @State private var errorMessage: String?
    @State private var legalDoc: LegalDoc?
    @State private var offering: Offering?
    @State private var loadingOfferings = true
    @State private var offeringsLoadFailed = false
    @State private var restoreAlert: RestoreAlert?
    /// Identity-recovery (2026-07-25) — the fresh wall's sign-in door.
    /// A reinstalled payer loses wasEverEntitled with the container, so
    /// she lands HERE (not the expired wall) with her subscription
    /// attached to her old account. Presents the reusable
    /// SignInPromptView; a completed sign-in flows through the existing
    /// onAuthChanged pipeline (re-key + hydration) and opens
    /// PaymentService's interactive-sign-in recovery window so the
    /// receipt re-attaches silently.
    @State private var showingSignIn = false

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
        // isn't available from RC (offline sim, missing StoreKit
        // config). Keeps --debug-paywall rendering the full design.
        //
        // `--uitest-pricing-fail` suppresses the mock too: that harness
        // exists to photograph the REAL unresolved states (skeleton
        // pulses, failure row, retry CTA), which mock prices would
        // paper over.
        if ProcessInfo.processInfo.arguments.contains("--uitest-pricing-fail") { return false }
        return quarterlyPackage == nil
    }
    #else
    private var debugMockPricing: Bool { false }
    #endif

    /// 2026-06-29 - DEBUG-only one-screen-redesign preview. When the app
    /// is launched with `--debug-paywall` (no RC packages, no UserRecord
    /// hydrated in-sim), the projection hero + per-day + anchor copy all
    /// read from real fields that are empty, so the screen would render
    /// half-built. This flag lets those computed properties fall back to
    /// representative mock values so the FULL layout renders for visual
    /// verification. Never true in release builds; never alters a real
    /// user's screen (it only fires when the launch arg is present AND
    /// the real source field is empty).
    #if DEBUG
    private var debugPaywallPreview: Bool {
        ProcessInfo.processInfo.arguments.contains("--debug-paywall")
    }
    #else
    private var debugPaywallPreview: Bool { false }
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

    /// One headline, outcome-first (founder call, 2026-07-07: "sell the
    /// promise of losing weight"). "{name}, your plan to 151 lb." — the
    /// goal is HER typed number (provenance-clean, not a claim; the
    /// chart below hedges with "on track for"). Falls back to the
    /// ownership line for maintenance / no-goal users. The retired
    /// food-first / timeline experiment variants (FoodFlags) are gone:
    /// one headline, her outcome.
    private var headlineParts: (base: String, italic: [String]) {
        let first = displayFirstName
        let namePrefix = first.isEmpty ? "" : "\(first), "
        if let goal = goalWeightPunch {
            return ("\(namePrefix)your plan to \(goal).", [goal])
        }
        let punch = "ready"
        return ("\(namePrefix)your plan is \(punch).", [punch])
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
        if debugPaywallPreview, currentUserRecord == nil { return 56 }
        guard let tier = IntensityTier(rawValue: onboardingPickedTierRaw),
              let record = currentUserRecord,
              let current = record.onboardingCurrentWeightKg,
              let goal = record.onboardingGoalWeightKg,
              current > goal else { return nil }
        let window = ProgramGoalCalculator.compute(.init(
            currentWeightKg: current,
            goalWeightKg: goal,
            sex: ProgramGoalCalculator.sex(fromGenderKey: paywallGender),  // FIX 4
            age: nil,
            // v3 P11.2 (2026-06-10) — routed through engine-v2 helpers.
            // Note: paywall doesn't yet read sleep — adding it would
            // need a new @AppStorage on PaywallView. Skipping for
            // now since paywall only displays the day count, doesn't
            // alter the program; the actual program-shape decisions
            // happen upstream in PacePicker + ProgramSetupSubflow
            // (both of which now read sleep).
            isGLP1User:       ProgramGoalCalculator.isGLP1User(from: paywallGlp1Status),
            isPerimenopausal: ProgramGoalCalculator.isPerimenopausal(from: paywallHormonalStage),
            weightTrendKey:   paywallWeightTrend,
            glp1PhaseKey:     paywallGlp1Phase
        ))
        return window.weeks(for: tier) * 7
    }

    // MARK: Pricing display
    //
    // Every price string is Optional. nil = the package hasn't resolved,
    // and the row renders a skeleton pulse instead of a number. Release
    // builds NEVER print an invented price — the pre-rebuild fallback
    // ("$49.99" while offerings were down) could disagree with the real
    // Apple sheet, which is exactly the mismatch this wall exists to
    // kill. DEBUG keeps the mock path so --debug-paywall still renders.

    private func package(for plan: Plan) -> Package? {
        switch plan {
        case .yearly:    return yearlyPackage
        case .quarterly: return quarterlyPackage
        case .weekly:    return weeklyPackage
        }
    }

    /// Billed price for a plan ("$24.99"), localized by StoreKit.
    /// nil until the package resolves (skeleton), mock in DEBUG only.
    private func billedPrice(for plan: Plan) -> String? {
        if let pkg = package(for: plan), !debugMockPricing {
            return pkg.storeProduct.localizedPriceString
        }
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-pricing-fail") { return nil }
        #endif
        guard debugMockPricing || debugPaywallPreview else { return nil }
        switch plan {
        case .yearly:    return "$47.99"
        case .quarterly: return "$24.99"
        case .weekly:    return "$5.99"
        }
    }

    /// Per-week equivalent ("≈ $2.08/wk") for the yearly + quarterly
    /// rows — the common currency that makes three cadences comparable
    /// without a spreadsheet. Derived from the live price (÷52 / ÷13),
    /// rendered at 10pt vs the 20pt billed price (Apple 3.1.2c: the
    /// equivalent must stay subordinate to the actual charge). nil for
    /// weekly (its billed price IS the per-week) and pre-resolve.
    private func perWeekEquivalent(for plan: Plan) -> String? {
        let divisor: Int
        switch plan {
        case .yearly:    divisor = 52
        case .quarterly: divisor = 13
        case .weekly:    return nil
        }
        guard let pkg = package(for: plan) else {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitest-pricing-fail") { return nil }
            #endif
            guard debugPaywallPreview || debugMockPricing else { return nil }
            return plan == .yearly ? "≈ $0.92/wk" : "≈ $1.92/wk"
        }
        let price = pkg.storeProduct.price as NSDecimalNumber
        let formatter = pkg.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
        let perWeek = price.dividing(by: NSDecimalNumber(value: divisor))
        guard let s = formatter.string(from: perWeek) else { return nil }
        return "≈ \(s)/wk"
    }

    /// "save 87%" vs paying weekly all year — v6.4: the honest
    /// compare is the OTHER option on this screen, so the claim is
    /// checkable arithmetic on the two visible prices. Live prices
    /// only.
    private var yearlySavePct: Int? {
        guard let yearly = yearlyPackage, let weekly = weeklyPackage else {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitest-pricing-fail") { return nil }
            #endif
            return (debugPaywallPreview || debugMockPricing) ? 85 : nil
        }
        let y = (yearly.storeProduct.price as NSDecimalNumber).doubleValue
        let wAnnual = (weekly.storeProduct.price as NSDecimalNumber).doubleValue * 52
        guard wAnnual > 0, y > 0, wAnnual > y else { return nil }
        return Int(((wAnnual - y) / wAnnual * 100).rounded())
    }

    private static let defaultCurrencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    /// Renewal date for a plan if she bought right now ("oct 6") —
    /// plain arithmetic on today's date, shown so the renewal is an
    /// expectation, never a surprise. The honest-terms row + the
    /// receipt-confirm both read it.
    private func renewalDateText(for plan: Plan) -> String {
        let component: Calendar.Component
        let value: Int
        switch plan {
        case .yearly:    component = .year;  value = 1
        case .quarterly: component = .month; value = 3
        case .weekly:    component = .day;   value = 7
        }
        let date = Calendar.current.date(byAdding: component, value: value, to: Date()) ?? Date()
        let f = DateFormatter()
        f.setLocalizedDateFormatFromTemplate("MMM d")
        return f.string(from: date).lowercased()
    }

    /// CTA label — "keep my plan · $24.99 today". The verb is the
    /// endowment ("keep" what she built, not "start" something new) and
    /// the billed-TODAY number rides the button at full contrast so the
    /// receipt-confirm and the Apple sheet only ever repeat it.
    private var ctaText: Text {
        guard let price = billedPrice(for: selectedPlan) else {
            return Text(offeringsLoadFailed ? "try pricing again" : "loading your pricing…")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.textInverse.opacity(0.85))
        }
        return Text("keep my plan")
            .font(.system(size: 17, weight: .semibold))
            .foregroundStyle(Palette.textInverse)
            + Text("  \u{00B7}  \(price) today")
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(Palette.textInverse.opacity(0.88))
    }

    // MARK: - Adaptive density (2026-06-30 real-device fit)
    //
    // The 59b2558 3-tier layout fit on a 6.3" 17 Pro but overflowed on
    // the founder's smaller phone: the secondary 12-week/Weekly pair fell
    // below the fold so only the Yearly hero showed. The value zone is now
    // sized off the available (safe-area) height so all three tiers + the
    // docked CTA + guarantee clear the fold WITHOUT scrolling on a 6.1"
    // (iPhone 16) AND on the smallest current phone (iPhone SE, ~647pt
    // usable). The hero headline + projection chart are the two heaviest
    // elements, so they take the deepest cut on the short buckets; the
    // headline font is now an explicit size (not Dynamic-Type-relative) so
    // a large accessibility text setting can't silently re-overflow it.
    private struct Metrics {
        let topReserve: CGFloat
        let headlineSize: CGFloat
        let heroTop: CGFloat
        let chartTop: CGFloat
        /// Drawn height of the promise curve itself (the card adds axis
        /// + caption + padding around it).
        let chartHeight: CGFloat
        let tiersTop: CGFloat
        /// Vertical padding inside each tier row.
        let tierVPad: CGFloat
        let tierGap: CGFloat
        /// Billed-price type size on the tier rows — one step down on
        /// SE so "$24.99 today" never wraps inside the selected border.
        let tierPriceSize: CGFloat
        let footerTop: CGFloat
        /// her75 negative leading tracks the type size (≈ -0.5×size per the
        /// JeniHeroSerif spec) so the tight hero cadence holds at any bucket.
        var headlineLineGap: CGFloat { -0.5 * headlineSize }
    }

    /// Maps the usable (safe-area) height to a density bucket. iPhone SE
    /// (~647pt) → tiny; smaller notched / mini (~700-755) → compact;
    /// iPhone 16 (~759) + 17 Pro (~778) + larger → regular. Buckets are
    /// tuned so headline + promise chart + all THREE tier rows + the
    /// docked close clear the fold on first paint inside each viewport.
    private func metrics(forHeight h: CGFloat) -> Metrics {
        // topReserve clears the 44pt X / Restore bar on every bucket —
        // the hero must never share a line with chrome. The goal-variant
        // headline ("maya, your plan to 151 lb.") wraps to two lines, so
        // it takes a size step down vs the one-line fallback; chart
        // heights are budgeted against the 2-line case so the authority
        // line + legal always clear the fold.
        // 2026-07-07 rebalance (founder call): the chart is a compact
        // proof strip; the PRICING ROWS are the screen's dominant band —
        // the decision surface gets the visual weight.
        let hasGoalHeadline = goalWeightPunch != nil
        if h < 700 {            // iPhone SE (3rd gen) and smaller
            return Metrics(topReserve: 40, headlineSize: hasGoalHeadline ? 22 : 25, heroTop: 2,
                           chartTop: 8, chartHeight: 56,
                           tiersTop: 10, tierVPad: 11, tierGap: 7,
                           tierPriceSize: 19, footerTop: 6)
        } else if h < 755 {     // compact 6.1" / 13-mini class
            return Metrics(topReserve: 46, headlineSize: hasGoalHeadline ? 26 : 29, heroTop: 3,
                           chartTop: 10, chartHeight: 68,
                           tiersTop: 12, tierVPad: 13, tierGap: 8,
                           tierPriceSize: 21, footerTop: 8)
        } else {                // iPhone 16 / 15 / 17 Pro / Max
            // v6.5: quarterly returns → three tiers again, so the chart
            // gives back the 20pt the two-plan wall had borrowed and the
            // tier metrics return to the known-good 3-tier fold values
            // (commit 26c79a8) so all three rows + the docked CTA clear
            // the fold on first paint.
            return Metrics(topReserve: 52, headlineSize: hasGoalHeadline ? 29 : 32, heroTop: 4,
                           chartTop: 12, chartHeight: 80,
                           tiersTop: 14, tierVPad: 15, tierGap: 9,
                           tierPriceSize: 21, footerTop: 10)
        }
    }

    // MARK: Body

    var body: some View {
      GeometryReader { geo in
        let m = metrics(forHeight: geo.size.height)
        ZStack(alignment: .top) {
            Palette.bgPrimary.ignoresSafeArea()

            // 2026-07-07 keep-wall composition (founder-steered: the
            // hero sells the OUTCOME). Three bands, one job each:
            //   BAND 1 (the promise) — "{name}, your plan to 151 lb." +
            //     THE PROMISE CHART: her curve from today's weight to
            //     her goal, arrival date at the terminus, honesty pace
            //     caption. Her own numbers, hedged as a projection.
            //   BAND 2 (the choice) — the year (badged + pre-selected) →
            //     the quarter → one week, a descending per-week ladder.
            //     Billed-TODAY on every row; per-week equivalents smaller
            //     (3.1.2c). Choosing is consenting.
            //   BAND 3 (the close, docked) — honest terms (renews when ·
            //     cancel how · guarantee) + the keep CTA carrying the
            //     same billed-today number the receipt-confirm and the
            //     Apple sheet will repeat.
            VStack(spacing: 0) {
                ScrollView(showsIndicators: false) {
                    VStack(spacing: 0) {
                        // Status bar + topBar (Restore) reserve so the
                        // hero always clears the Dynamic Island. Scaled by
                        // density so short phones reclaim the headroom.
                        Spacer().frame(height: m.topReserve)

                        heroBlock(m)
                            .overlay(alignment: .topTrailing) { headlineSticker }
                            .padding(.horizontal, Space.lg)
                            .padding(.top, m.heroTop)

                        promiseChartSection(m)
                            .padding(.horizontal, Space.lg)
                            .padding(.top, m.chartTop)

                        tierSection(m)
                            .padding(.horizontal, Space.lg)
                            .padding(.top, m.tiersTop)

                        if downsellUnlocked, let onReclaimDownsell {
                            reclaimRow(onReclaimDownsell)
                                .padding(.horizontal, Space.lg)
                                .padding(.top, 10)
                        }

                        if offeringsLoadFailed {
                            offeringsLoadFailedRow
                                .padding(.horizontal, Space.lg)
                                .padding(.top, 10)
                        }

                        trustAndLegalFooter
                            .padding(.horizontal, Space.lg)
                            .padding(.top, m.footerTop)
                            .padding(.bottom, 14)
                    }
                }

                // Docked close — terms + CTA always visible, never
                // clipped. A hairline marks the boundary so content
                // scrolling beneath reads as a deliberate layer.
                VStack(spacing: 0) {
                    Rectangle()
                        .fill(Palette.hairlineCocoa)
                        .frame(height: 0.5)
                        .frame(maxWidth: .infinity)
                    honestTermsLine
                        .padding(.horizontal, Space.lg)
                        .padding(.top, 10)
                    ctaButton
                        .padding(.horizontal, Space.lg)
                        .padding(.top, 8)
                    // The Apple-sheet bridge: the register-shift to
                    // StoreKit's chrome is where 60-75% still abandon —
                    // pre-naming it keeps jeni in the room.
                    if billedPrice(for: selectedPlan) != nil {
                        Text("apple will ask to confirm \u{00B7} that's the whole plan, i'll be right here \u{2665}\u{FE0E}")
                            .font(.system(size: 10.5))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .padding(.top, 6)
                    }
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
        .sheet(isPresented: $showingSignIn) {
            // Same reusable surface AccountView + the expired wall
            // present. onContinue fires on success AND on cancel —
            // the isAnonymous check separates the two: only a real
            // sign-in opens the recovery window.
            NavigationStack {
                SignInPromptView(
                    onContinue: {
                        showingSignIn = false
                        if !AuthService.shared.isAnonymous {
                            PaymentService.shared.noteInteractiveSignIn(
                                signedInUserID: AuthService.shared.currentUser?.id.uuidString
                            )
                        }
                    },
                    mode: .signIn
                )
                .background(Palette.programEraBg)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button {
                            showingSignIn = false
                        } label: {
                            Image(systemName: "xmark")
                                .font(.system(size: 14, weight: .medium))
                                .foregroundStyle(Palette.textSecondary)
                                .frame(width: 30, height: 30)
                                .background(Palette.bgElevated)
                                .clipShape(Circle())
                                .tappableArea()
                        }
                        .accessibilityLabel("Close sign in")
                    }
                }
            }
        }
        .alert(item: $restoreAlert) { alert in
            Alert(title: Text(alert.title), message: Text(alert.message),
                  dismissButton: .default(Text("OK")))
        }
        .task {
            Analytics.captureScreen("Paywall")
            viewOpenTime = Date()
            await loadOfferings()
            // Default: the year — badged "most popular", pre-selected
            // (round 6 founder call). The quarter rejoins as the middle
            // option but doesn't take the default; it's the step-down
            // for someone the year scares, not the anchor. Defensive
            // no-op guard kept in case the default ever moves off a row
            // whose SKU isn't in the offering.
            if selectedPlan == .quarterly, quarterlyPackage == nil,
               yearlyPackage != nil, !debugMockPricing {
                selectedPlan = .yearly
            }
        }
      }
    }

    // MARK: - Keep-wall sections (2026-07-07)

    /// Outcome hero — one headline, nothing above it (the identity
    /// prime line was cut 2026-07-07, founder call: at the money moment
    /// she cares about the outcome, not the adjective). Fixed sizes
    /// (not Dynamic-Type-relative) keep the fold math deterministic —
    /// the screen's shipped convention.
    private func heroBlock(_ m: Metrics) -> some View {
        let parts = headlineParts
        return ItalicAccentText(
            parts.base,
            italic: parts.italic,
            baseFont: .custom("JeniHeroSerif-Regular", size: m.headlineSize),
            italicFont: .custom("JeniHeroSerif-Italic", size: m.headlineSize),
            alignment: .center
        )
        .lineSpacing(m.headlineLineGap)
        .tracking(-0.4)
        .padding(.horizontal, 8)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
    }

    /// THE PROMISE CHART — the wall's hero (founder call: sell the
    /// outcome). Her weight-loss curve drawn big: today's weight at the
    /// start dot, her goal weight + arrival date blooming at the
    /// terminus, the honesty pace caption underneath. Every number is
    /// hers (entered weights, picked pace, ProjectionMath's date) and
    /// the "on track for" hedge keeps it a projection, not a promise.
    /// Maintenance / no-goal users skip the chart cleanly (ViewBuilder
    /// omits — the wall falls back to headline → tiers).
    @ViewBuilder
    private func promiseChartSection(_ m: Metrics) -> some View {
        if let goal = goalWeightPunch, let date = arrivalDatePunch {
            VStack(spacing: 5) {
                PaywallPromiseChart(
                    startLabel: currentWeightPunch,
                    goalLabel: goal,
                    height: m.chartHeight
                )

                // One axis row carries the whole story: you today →
                // the honesty pace hedge → her, on the date.
                HStack(alignment: .firstTextBaseline) {
                    (Text("you, ")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                     + Text("today")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(Palette.textPrimary))
                    Spacer(minLength: 8)
                    if let caption = paceCaption {
                        Text(caption)
                            .font(.system(size: 9))
                            .foregroundStyle(Palette.textSecondary)
                            .lineLimit(1)
                    }
                    Spacer(minLength: 8)
                    (Text("her, ")
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.textSecondary)
                     + Text(date)
                        .font(.custom("JeniHeroSerif-Italic", size: 18))
                        .foregroundStyle(Palette.accent))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 20, style: .continuous)
                    .fill(Palette.bgElevated)
            )
            .shadow(color: Palette.cocoaPrimary.opacity(0.08), radius: 20, x: 0, y: 6)
            .accessibilityElement(children: .combine)
        }
    }

    /// "168 lb" — her entered current weight, shown at the curve's
    /// start dot so the distance reads as HER distance. nil hides the
    /// start label (curve still draws).
    private var currentWeightPunch: String? {
        guard let currentKg = currentUserRecord?.onboardingCurrentWeightKg else {
            if debugPaywallPreview { return "168 lb" }
            return nil
        }
        let unit = WeightUnit.current
        let v = unit.display(fromKg: currentKg)
        let s = (v == v.rounded()) ? String(format: "%.0f", v) : String(format: "%.1f", v)
        return "\(s) \(unit.label)"
    }

    /// Goal weight as a display punch ("151 lb"). Her own entered goal —
    /// a fact, not a projection. Nil when no loss goal set.
    private var goalWeightPunch: String? {
        guard let goalKg = currentUserRecord?.onboardingGoalWeightKg,
              let currentKg = currentUserRecord?.onboardingCurrentWeightKg,
              currentKg > goalKg else {
            if debugPaywallPreview { return "151 lb" }
            return nil
        }
        let unit = WeightUnit.current
        let v = unit.display(fromKg: goalKg)
        let s = (v == v.rounded()) ? String(format: "%.0f", v) : String(format: "%.1f", v)
        return "\(s) \(unit.label)"
    }

    /// "~1.2 lb/wk · steady pace" — derived from her own current weight
    /// + picked pace via the canonical ProjectionMath. The honesty hedge
    /// that frames the curve as a projection, never a promise.
    private var paceCaption: String? {
        guard let currentKg = currentUserRecord?.onboardingCurrentWeightKg,
              let goalKg = currentUserRecord?.onboardingGoalWeightKg,
              currentKg > goalKg else {
            if debugPaywallPreview { return "~1.1 lb/wk \u{00B7} steady pace" }
            return nil
        }
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
            .frame(width: 28, height: 28)
            .rotationEffect(.degrees(10))
            // Floats above the headline's trailing end — the one-line
            // goal headline runs wide, so the bow must never sit ON the
            // text (it clipped the terminal period in the 07-07 walk),
            // and -10 keeps it under the Restore label on SE.
            .offset(x: 2, y: -10)
            .accessibilityHidden(true)
    }

    /// The choice band — v6.5 THREE-tier anchor structure (founder
    /// call 2026-07-17: quarterly returns to the wall). A descending
    /// per-week ladder — the year (badged + pre-selected) → the
    /// quarter (the middle commitment) → one week (the honest trial) —
    /// so the year reads as the obvious value against the two rows
    /// beneath it. The quarter self-gates: it renders only when its
    /// package resolves (or in a debug preview), so a build whose
    /// offering lacks `jenifit_quarterly` falls back cleanly to the
    /// two-plan wall. No fabricated strikethroughs: every number is a
    /// live StoreKit price or arithmetic on one.
    private func tierSection(_ m: Metrics) -> some View {
        VStack(spacing: m.tierGap) {
            HStack {
                Text("pick how you start")
                    .font(Typo.captionTracked)
                    .kerning(1.6)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer()
            }
            .padding(.bottom, 2)

            anchorTierRow(
                m, plan: .yearly, title: "the year",
                sub: yearlySubLine, tag: "most popular",
                perWeekLead: perWeekLead(for: .yearly),
                billedLine: billedPrice(for: .yearly).map { "\($0) per year, today" }
            )
            if showsQuarterlyTier {
                anchorTierRow(
                    m, plan: .quarterly, title: "the quarter",
                    sub: quarterlySubLine, tag: nil,
                    perWeekLead: perWeekLead(for: .quarterly),
                    billedLine: billedPrice(for: .quarterly).map { "\($0) per quarter, today" }
                )
            }
            anchorTierRow(
                m, plan: .weekly, title: "one week",
                sub: "just trying it? that's ok",
                tag: nil,
                perWeekLead: perWeekLead(for: .weekly),
                billedLine: weeklyAnnualTruth
            )

            // The authority the flow earned (ACSM band + the safety gate
            // she actually passed) sits with the money — a quiet
            // credential at the decision, not a loud claim.
            Text(safetyScreenCompleted
                 ? "paced to ACSM guidance \u{00B7} safety-screened before you started."
                 : "paced to ACSM guidance \u{00B7} built for sustainable loss.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.top, 4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var yearlySubLine: String {
        if let pct = yearlySavePct {
            return "your whole plan · save \(pct)%"
        }
        return "your whole plan, covered"
    }

    /// The quarter shows only when its package resolves — the same
    /// self-gating contract the tier has held since it was introduced
    /// (ship the code before the SKU exists / the offering carries it).
    /// A debug preview forces it on for visual verification.
    private var showsQuarterlyTier: Bool {
        quarterlyPackage != nil || debugPaywallPreview || debugMockPricing
    }

    private var quarterlySubLine: String {
        if let pct = quarterlySavePct {
            return "three months · save \(pct)%"
        }
        return "three months, one payment"
    }

    /// "save 68%" vs paying weekly for the same three months — checkable
    /// arithmetic on the two visible prices (quarterly ÷ 13 weeks vs the
    /// weekly rate). Live prices only; mock in preview.
    private var quarterlySavePct: Int? {
        guard let quarterly = quarterlyPackage, let weekly = weeklyPackage else {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("--uitest-pricing-fail") { return nil }
            #endif
            return (debugPaywallPreview || debugMockPricing) ? 68 : nil
        }
        let qPerWeek = (quarterly.storeProduct.price as NSDecimalNumber).doubleValue / 13
        let weeklyRate = (weekly.storeProduct.price as NSDecimalNumber).doubleValue
        guard weeklyRate > 0, qPerWeek > 0, weeklyRate > qPerWeek else { return nil }
        return Int(((weeklyRate - qPerWeek) / weeklyRate * 100).rounded())
    }

    /// The per-week rate as the LEAD numeral ("$0.96") — bare, no
    /// prefix. Yearly ÷52; weekly IS its own per-week. nil until the
    /// package resolves.
    private func perWeekLead(for plan: Plan) -> String? {
        switch plan {
        case .weekly:
            return billedPrice(for: .weekly)
        case .yearly:
            guard let pkg = package(for: .yearly) else {
                guard debugPaywallPreview || debugMockPricing else { return nil }
                return "$0.92"
            }
            let price = pkg.storeProduct.price as NSDecimalNumber
            let formatter = pkg.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
            return formatter.string(from: price.dividing(by: NSDecimalNumber(value: 52)))
        case .quarterly:
            guard let pkg = package(for: .quarterly) else {
                guard debugPaywallPreview || debugMockPricing else { return nil }
                return "$1.92"
            }
            let price = pkg.storeProduct.price as NSDecimalNumber
            let formatter = pkg.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
            return formatter.string(from: price.dividing(by: NSDecimalNumber(value: 13)))
        }
    }

    /// The weekly plan's annualized truth ("$415/year if billed
    /// weekly") — the same unit as the year, so nobody does math.
    /// Pure arithmetic on the live price, rounded to whole currency.
    private var weeklyAnnualTruth: String? {
        guard let pkg = package(for: .weekly) else {
            guard debugPaywallPreview || debugMockPricing else { return nil }
            return "$311/year if billed weekly"
        }
        let price = pkg.storeProduct.price as NSDecimalNumber
        let annual = price.multiplying(by: NSDecimalNumber(value: 52))
        let base = pkg.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
        let whole = (base.copy() as? NumberFormatter) ?? base
        whole.maximumFractionDigits = 0
        guard let s = whole.string(from: annual) else { return nil }
        return "\(s)/year if billed weekly"
    }

    /// One anchor tier row (v6.4). Anatomy: radio mark → title
    /// (+ badge) + sub → the per-week rate as the lead numeral with
    /// the billed reality in clear text beneath. The billed charge is
    /// always present and unambiguous (3.1.2 stays honest); the
    /// per-week unit is what makes the two rows comparable at a
    /// glance. Unresolved pricing renders a skeleton pulse — never an
    /// invented number.
    private func anchorTierRow(
        _ m: Metrics, plan: Plan, title: String, sub: String, tag: String?,
        perWeekLead: String?, billedLine: String?
    ) -> some View {
        let isSelected = selectedPlan == plan
        return Button {
            guard selectedPlan != plan else { return }
            Haptics.light()
            Analytics.track(.paywallTierSelected, properties: [
                "plan": plan.rawValue,
                "previous_plan": selectedPlan.rawValue
            ])
            withAnimation(Motion.tap) { selectedPlan = plan }
        } label: {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .stroke(isSelected ? Palette.bgInverse : Palette.textSecondary.opacity(0.35),
                                lineWidth: isSelected ? 0 : 1.5)
                        .frame(width: 22, height: 22)
                    if isSelected {
                        Circle().fill(Palette.bgInverse).frame(width: 22, height: 22)
                        Image(systemName: "checkmark")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(Palette.textInverse)
                    }
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(title)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .lineLimit(1)
                            .fixedSize()
                        if let tag {
                            Text(tag)
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundStyle(Palette.textPrimary)
                                .lineLimit(1)
                                .fixedSize()
                                .padding(.horizontal, 7)
                                .padding(.vertical, 2)
                                .background(Capsule().fill(Palette.accentSubtle))
                        }
                    }
                    Text(sub)
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                Spacer(minLength: 8)
                VStack(alignment: .trailing, spacing: 2) {
                    if let perWeekLead {
                        ((Text(perWeekLead)
                            .font(.custom("Fraunces72pt-SemiBold", size: m.tierPriceSize + 1))
                            .foregroundStyle(Palette.textPrimary)
                         + Text(" /wk")
                            .font(.system(size: 12))
                            .foregroundStyle(Palette.textSecondary)))
                            .lineLimit(1)
                            .fixedSize()
                    } else {
                        PricePulsePlaceholder()
                    }
                    if let billedLine {
                        Text(billedLine)
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.cocoaTertiary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.85)
                    }
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, m.tierVPad)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Palette.bgElevated.opacity(isSelected ? 1 : 0.55))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(
                                isSelected ? Palette.bgInverse : Palette.textSecondary.opacity(0.16),
                                lineWidth: isSelected ? 2 : 1
                            )
                    )
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(tierAccessibilityLabel(plan: plan, title: title, sub: sub))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private func tierAccessibilityLabel(plan: Plan, title: String, sub: String) -> String {
        var parts = [title, sub]
        if let price = billedPrice(for: plan) { parts.append("\(price) billed today") }
        if let perWeek = perWeekEquivalent(for: plan) { parts.append(perWeek) }
        return parts.joined(separator: ", ")
    }

    /// Picked pace - drives the arrival-date projection so the paywall
    /// date matches every other surface (single source of truth in
    /// ProjectionMath). Empty key anchors at steady (0.75%/wk).
    @AppStorage(ProjectionMath.paceDefaultsKey) private var paywallPaceChoice: String = ""

    /// Projected arrival date ("sep 14"), via the canonical ProjectionMath
    /// so it matches the projection beat she saw one screen ago. Nil
    /// when no loss goal set. Framed as "on track for" — a projection,
    /// never a promise.
    private var arrivalDatePunch: String? {
        guard let goalKg = currentUserRecord?.onboardingGoalWeightKg,
              let currentKg = currentUserRecord?.onboardingCurrentWeightKg,
              currentKg > goalKg else {
            if debugPaywallPreview {
                let d = Calendar.current.date(byAdding: .day, value: 84, to: Date()) ?? Date()
                let f = DateFormatter(); f.dateFormat = "MMM d"
                return f.string(from: d).lowercased()
            }
            return nil
        }
        return ProjectionMath.formattedShortDate(
            currentKg: currentKg, goalKg: goalKg, paceKey: paywallPaceChoice
        )
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

    /// The saved-offer reclaim row. Once the discounted year has been
    /// shown, the anchor is set — she will not un-see $34.99 — so the
    /// offer must stay reachable or the wall converts nobody. Quiet
    /// capsule, one line, always available after unlock.
    private func reclaimRow(_ action: @escaping () -> Void) -> some View {
        Button {
            Haptics.light()
            action()
        } label: {
            HStack(spacing: 8) {
                Text("\u{2665}\u{FE0E}")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.accent)
                Text("your discounted year is saved")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textPrimary)
                Spacer(minLength: 8)
                Text("open")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(Palette.accent)
                Image(systemName: "chevron.right")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(Palette.accent)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .background(Capsule().fill(Palette.accentSubtle))
        }
        .buttonStyle(PressFeedbackStyle())
        .accessibilityLabel("open your saved discounted year offer")
    }


    /// The reversibility receipt (v6.3, docs/app_v6/03_CONVERSION.md):
    /// pay-upfront's modal objection is IRREVERSIBILITY, not price —
    /// she reads "$X today" as prepaying for her own compliance after
    /// six apps' worth of quitting. So regret insurance leads, loud,
    /// and the renewal truth rides second. Promises only the real
    /// redemption paths.
    private var honestTermsLine: some View {
        VStack(spacing: 3) {
            HStack(spacing: 6) {
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.accent)
                Text("money-back guarantee \u{00B7} no forms, no guilt")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
            }
            Text(billedPrice(for: selectedPlan) != nil
                 ? "renews \(renewalDateText(for: selectedPlan)) unless you cancel \u{00B7} two taps in settings"
                 : "cancel anytime \u{00B7} two taps in settings")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
        }
        .frame(maxWidth: .infinity)
        .multilineTextAlignment(.center)
    }

    /// Near-black CTA. One button, three honest states: resolved →
    /// "keep my plan · $24.99 today" goes STRAIGHT to Apple's sheet
    /// (no interstitial — the billed-today number is already on the row,
    /// the button, and the terms line, so a fourth restatement was pure
    /// friction at peak intent); failed → "try pricing again" retries
    /// the offerings load; loading → disabled "loading your pricing…".
    /// Never purchasable without a real localized price on screen.
    private var ctaButton: some View {
        Button {
            if billedPrice(for: selectedPlan) != nil, selectedPackage != nil || debugMockPricing || debugPaywallPreview {
                Haptics.medium()
                startPurchase()
            } else if offeringsLoadFailed {
                Haptics.light()
                Task { await loadOfferings() }
            }
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
                    .opacity(ctaEnabled ? 1 : 0.55)
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
        .disabled(working || !ctaEnabled)
        .accessibilityLabel(
            billedPrice(for: selectedPlan).map { "keep my plan, \($0) billed today" }
                ?? (offeringsLoadFailed ? "try pricing again" : "loading pricing")
        )
    }

    private var ctaEnabled: Bool {
        if working { return false }
        if billedPrice(for: selectedPlan) != nil { return true }
        return offeringsLoadFailed   // failed state repurposes the CTA as retry
    }

    /// CTA tapped → straight to StoreKit. Fires paywall_cta_tapped
    /// (keeps its funnel position, comparable across builds), flips the
    /// spinner, and hands off to purchase() which presents Apple's
    /// sheet and fires purchase_sheet_shown.
    private func startPurchase() {
        Analytics.track(.paywallCtaTapped, properties: [
            "plan": selectedPlan.rawValue,
            "time_on_paywall_ms": Int(Date().timeIntervalSince(viewOpenTime) * 1000)
        ])
        working = true
        Task { await purchase() }
    }

    // MARK: - Compact paywall helpers

    /// First-name extraction. Splits on whitespace and lowercases for
    /// the JeniFit voice — even a user typing "Sarah Smith" reads as
    /// "sarah" in peer voice. Falls back to "" so headlineParts
    /// gracefully drops the "hi {name}." prefix.
    private var displayFirstName: String {
        let trimmed = userName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return debugPaywallPreview ? "jen" : "" }
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
            // The recovery pair (2026-07-25): sign-in door + restore,
            // together in the quiet top-bar idiom so neither competes
            // with the purchase CTA. The sign-in door is the reinstalled
            // payer's only way back to her account from the fresh wall.
            Button {
                Haptics.light()
                Analytics.track("paywall_sign_in_tapped")
                showingSignIn = true
            } label: {
                Text("already a member? sign in")
                    .font(.system(size: 11))
                    .foregroundStyle(Palette.textSecondary.opacity(0.55))
            }
            .buttonStyle(.plain)
            Text("\u{00B7}")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary.opacity(0.4))
                .padding(.horizontal, 4)
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
            Text("pricing didn't load. tap to try again. nothing is charged without it.")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Palette.stateWarn.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: Radius.sm, style: .continuous))
        .onTapGesture {
            Task { await loadOfferings() }
        }
    }

    // MARK: Offerings + Purchase

    private func loadOfferings() async {
        // QA harness: force the pricing-failure state so the retry CTA,
        // skeleton rows, and failure card are screenshot-able without
        // network manipulation. DEBUG builds only.
        #if DEBUG
        if ProcessInfo.processInfo.arguments.contains("--uitest-pricing-fail") {
            loadingOfferings = false
            offeringsLoadFailed = true
            return
        }
        #endif
        // RevenueCat hard-fatals if `offerings()` is called before
        // `Purchases.configure()`. In the normal flow PaymentService
        // configures it well before the paywall mounts, but the DEBUG
        // `--debug-paywall` preview harness mounts PaywallView directly
        // (bypassing RootView's payment bootstrap). Guard so the preview
        // renders on mock pricing instead of crashing; release builds are
        // always configured by the time the paywall presents.
        guard Purchases.isConfigured else {
            loadingOfferings = false
            return
        }
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

    /// Real RevenueCat purchase, reached ONLY through the receipt-
    /// confirm (paywall_cta_tapped + purchase_confirm_* fire there).
    /// userCancelled → onPurchaseCancelled(plan, productId) so the
    /// parent routes a tier-matched recovery. Successful purchase →
    /// onSubscribed() callback. Errors → friendly inline message + log.
    private func purchase() async {
        guard let package = selectedPackage else {
            // DEBUG design-preview mode has no real package; a confirm
            // tap should exercise the flow silently, not error.
            if debugMockPricing || debugPaywallPreview {
                working = false
                return
            }
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
            // funnel diff (purchase_confirm_accepted → purchase_sheet_shown
            // → purchase_completed) makes any regression visible at a
            // glance.
            Analytics.track(.purchaseSheetShown, properties: [
                "plan": selectedPlan.rawValue,
                "product_id": package.storeProduct.productIdentifier
            ])
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                // She dismissed Apple's sheet — hand the parent the
                // abandoned tier so the recovery can answer the actual
                // objection (yearly → quieter-price offer, quarterly →
                // smaller-step offer, weekly → warm exit).
                onPurchaseCancelled(
                    selectedPlan.rawValue,
                    package.storeProduct.productIdentifier
                )
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

// MARK: - PricePulsePlaceholder
//
// Skeleton for an unresolved price — a soft pulsing capsule where the
// number will land. Release builds render THIS (never an invented
// price) while offerings load; Reduce Motion holds a static tint.
private struct PricePulsePlaceholder: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var bright = false

    var body: some View {
        Capsule()
            .fill(Palette.textSecondary.opacity(bright ? 0.28 : 0.14))
            .frame(width: 64, height: 18)
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    bright = true
                }
            }
            .accessibilityLabel("price loading")
    }
}

// MARK: - PaywallPromiseChart (2026-07-07 promise-as-hero)
//
// The wall's emotional peak, founder-steered: her weight-loss curve,
// drawn BIG. Reuses the canonical BecomingCurveShape /
// BecomingCurveFillShape (the same curve she saw at the projection
// beat) with the money-screen treatment:
//   • deep rose AREA fill fading to nothing at the baseline
//   • the stroke DRAWS ON over ~700ms ease-out from today → arrival
//   • start dot wearing her CURRENT weight ("168 lb")
//   • the arrival BLOOMS LAST — goal-weight pill + glossy flower at
//     the terminus, the one coquette accent on the card
// Numbers are never faked: both weights are her own entries; the curve
// is the shared projection shape. Reduce Motion snaps to the fully
// drawn + bloomed state.
private struct PaywallPromiseChart: View {
    /// Her entered current weight ("168 lb"); nil hides the start label.
    let startLabel: String?
    /// Her entered goal weight ("151 lb").
    let goalLabel: String
    var height: CGFloat = 120

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
                                Palette.accent.opacity(0.16),
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
                        style: StrokeStyle(lineWidth: 3, lineCap: .round)
                    )

                // hollow "today" dot + her current weight riding it
                Circle()
                    .fill(Palette.bgElevated)
                    .overlay(Circle().stroke(Palette.cocoaSecondary, lineWidth: 1.5))
                    .frame(width: 9, height: 9)
                    .position(x: 5, y: 7)
                    .opacity(drawn ? 1 : 0)
                if let startLabel {
                    Text(startLabel)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .fixedSize()
                        .position(x: 32, y: 20)
                        .opacity(drawn ? 1 : 0)
                }

                // her goal — the card's one big number, landing above
                // the terminus as the destination
                Text(goalLabel)
                    .font(.custom("Fraunces72pt-SemiBold", size: 16))
                    .foregroundStyle(Palette.textPrimary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Palette.accentSubtle))
                    .fixedSize()
                    .position(x: endX - 16, y: max(14, endY - 30))
                    .opacity(bloom ? 1 : 0)

                // arrival bloom — the ONE glossy sticker marking "her"
                Image("sticker_flower_3d")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: 26, height: 26)
                    .rotationEffect(.degrees(-6))
                    .scaleEffect(bloom ? 1 : 0.4)
                    .opacity(bloom ? 1 : 0)
                    .position(x: endX, y: endY)
                    .accessibilityHidden(true)
            }
        }
        .frame(height: height)
        .accessibilityElement()
        .accessibilityLabel("a gentle weight-loss curve from \(startLabel ?? "today") to your goal of \(goalLabel)")
        .onAppear {
            if reduceMotion {
                drawn = true
                bloom = true
                return
            }
            withAnimation(.easeOut(duration: 0.7)) { drawn = true }
            // the destination blooms last, overlapping the draw's end
            withAnimation(.spring(response: 0.5, dampingFraction: 0.7).delay(0.62)) {
                bloom = true
            }
        }
    }
}
