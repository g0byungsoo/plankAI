import SwiftUI
import SwiftData
import RevenueCat
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

    private enum Plan: Equatable { case yearly, weekly }

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
        if first.isEmpty {
            return ("your 5-min becoming ritual starts today.", ["becoming"])
        }
        return ("hi \(first). your 5-min becoming ritual starts today.", ["becoming"])
    }

    // MARK: RevenueCat package lookup

    private var yearlyPackage: Package? {
        offering?.availablePackages.first {
            $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.yearly
        }
    }

    private var weeklyPackage: Package? {
        offering?.availablePackages.first {
            $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.weekly
        }
    }

    private var selectedPackage: Package? {
        selectedPlan == .yearly ? yearlyPackage : weeklyPackage
    }

    // MARK: Pricing display

    /// Localized price for the yearly card ("$69.99/year" in en-US,
    /// equivalent in other locales). Falls back to a placeholder while
    /// offerings are loading or if the lookup misses.
    private var yearlyPriceText: String {
        if let pkg = yearlyPackage {
            return "\(pkg.storeProduct.localizedPriceString)/year"
        }
        return "$69.99/year"
    }

    /// Per-week math + savings %, both computed from the actual yearly
    /// and weekly storeProduct prices. Uses the yearly product's price
    /// formatter so the per-week amount shows in the same locale/currency.
    private var yearlyPerWeekText: String {
        guard let yearly = yearlyPackage else {
            return "Just $1.35/week · save 73%"
        }
        let yearlyPrice = yearly.storeProduct.price as NSDecimalNumber
        let perWeek = yearlyPrice.dividing(by: NSDecimalNumber(value: 52))
        let formatter = yearly.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
        let perWeekStr = formatter.string(from: perWeek) ?? "\(perWeek)"

        guard let weekly = weeklyPackage else {
            return "Just \(perWeekStr)/week"
        }
        let weeklyPrice = weekly.storeProduct.price as NSDecimalNumber
        guard weeklyPrice.doubleValue > 0 else {
            return "Just \(perWeekStr)/week"
        }
        let ratio = perWeek.dividing(by: weeklyPrice).doubleValue
        let savingsPercent = Int(((1.0 - ratio) * 100).rounded())
        guard savingsPercent > 0 else {
            return "Just \(perWeekStr)/week"
        }
        return "Just \(perWeekStr)/week · save \(savingsPercent)%"
    }

    private var weeklyPriceText: String {
        if let pkg = weeklyPackage {
            return "\(pkg.storeProduct.localizedPriceString)/week"
        }
        return "$4.99/week"
    }

    private static let defaultCurrencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    /// 2026 research: lowercase "continue" beat "start free trial" by
    /// +31% install-to-trial in the documented Adapty case (Berylo /
    /// RevenueCat redesign teardowns). The trial promise lives in the
    /// disclosure below + the timeline card — not in the button shout.
    /// Also de-risks Apple Guideline 3.1.2: Apple wants disclosure,
    /// not button-shouting.
    private var ctaLabel: String {
        switch selectedPlan {
        case .yearly: return "continue"
        case .weekly: return "subscribe — \(weeklyPriceText)"
        }
    }

    private var renewalDisclosure: String {
        switch selectedPlan {
        case .yearly:
            return "$0 today. \(yearlyPriceText) billed \(chargeDateText) unless you cancel. auto-renews yearly."
        case .weekly:
            return "\(weeklyPriceText). auto-renews. cancel anytime in settings."
        }
    }

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

            // Sticker scatter — LIGHT (4 stickers, edge-only). Brand
            // cue without crowding the dense pricing decision zone.
            StickerScatter(placements: Self.paywallPlacements)

            // 2026 research-led order: hero → 3-row trial timeline
            // card (trust before decision) → pricing → CTA → renewal
            // disclosure with literal charge date → trust strip
            // (research + anti-shame) → legal.
            //
            // Why timeline before pricing: Blinkist + Cal AI documented
            // pattern — clarity about WHEN money changes hands lowers
            // the perceived risk, so the price reads as the next step
            // rather than a surprise (Cal AI +30% trial-to-paid).
            ScrollView {
                VStack(spacing: Space.lg) {
                    Spacer().frame(height: 56)  // floating top bar reserve

                    headerBlock

                    trialTimelineCard

                    pricingSection
                    if offeringsLoadFailed {
                        offeringsLoadFailedRow
                    }

                    ctaButton
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.stateBad)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    renewalText

                    trustStrip

                    legalFooter
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
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
            await loadOfferings()
        }
    }

    // MARK: - Hero block (product-forward, no avatar)
    //
    // 2026 research call: illustrated coach portraits on a paywall hero
    // trigger the AI-slop pattern-match for women 22-35 (Tandfonline
    // Gen-Z femvertising 2024). Jeni earns trust on case 250's preview
    // screen; the paywall itself stays product-forward. The hero is now:
    // eyebrow → headline (with name + becoming-ritual frame) → simple
    // trial disclosure subhead.

    private var headerBlock: some View {
        let parts = headlineParts

        return VStack(spacing: Space.sm) {
            Text("JENIFIT PREMIUM")
                .font(Typo.eyebrow)
                .tracking(1.8)
                .foregroundStyle(Palette.accent)

            ItalicAccentText(parts.base,
                             italic: parts.italic,
                             baseFont: .custom("Fraunces72pt-SemiBold", size: 28),
                             italicFont: .custom("Fraunces72pt-SemiBoldItalic", size: 28),
                             alignment: .center)
                .padding(.horizontal, Space.sm)
                .fixedSize(horizontal: false, vertical: true)

            // Subhead — trial disclosure in plain language. No
            // personalization recap (the personalization lives in the
            // headline's name + "becoming ritual" frame). Lowercase,
            // peer voice.
            Text("3 days free. cancel anytime in settings.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.md)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

    /// 3-row trial timeline card. Blinkist + Cal AI documented winner —
    /// "today / day 2 / day 3" with explicit reminder promise. Drives
    /// +10-15% trial-to-paid AND lowers refund rate (RevenueFlo) by
    /// removing the "when am i charged?" friction. Also satisfies
    /// Apple Guideline 3.1.2 "trial length must be clear" check.
    ///
    /// Placed BEFORE pricing in the body — trust before the decision.
    private var trialTimelineCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("YOUR 3 FREE DAYS")
                .font(Typo.eyebrow)
                .tracking(2)
                .foregroundStyle(Palette.accent)
                .padding(.bottom, Space.sm)

            timelineRow(label: "today",
                        text: "unlock jeni's ritual + your full plan",
                        isFirst: true, isLast: false)
            timelineRow(label: "day 2",
                        text: "i'll text you before anything changes",
                        isFirst: false, isLast: false)
            timelineRow(label: "day 3",
                        text: "trial converts unless you cancel",
                        isFirst: false, isLast: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Space.md)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(Palette.divider, lineWidth: 1)
                )
        )
    }

    private func timelineRow(label: String, text: String, isFirst: Bool, isLast: Bool) -> some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(spacing: 0) {
                Rectangle()
                    .fill(isFirst ? Color.clear : Palette.accent.opacity(0.3))
                    .frame(width: 1, height: 6)
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 8, height: 8)
                Rectangle()
                    .fill(isLast ? Color.clear : Palette.accent.opacity(0.3))
                    .frame(width: 1)
                    .frame(maxHeight: .infinity)
            }
            .frame(width: 8)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(label)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 14))
                    .foregroundStyle(Palette.accent)
                    .frame(width: 50, alignment: .leading)
                Text(text)
                    .font(.system(size: 13))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            Spacer(minLength: 0)
        }
        .padding(.bottom, isLast ? 0 : 6)
    }

    /// Consolidated trust strip — research citations + anti-shame line
    /// in two compact lines. Replaces the separate citation footer +
    /// the removed coach-promise card's anti-shame disclaimer. Single
    /// strongest differentiator for the anti-femvertising audience
    /// (Drake & Salinas 2024).
    private var trustStrip: some View {
        VStack(spacing: 4) {
            Text("built on mcgill plank research + 3-month habit science.")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
            Text("no scales. no before-afters. just 5 minutes a day.")
                .font(.system(size: 11))
                .italic()
                .foregroundStyle(Palette.textSecondary.opacity(0.85))
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, Space.md)
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

    /// 4-sticker LIGHT scatter for the paywall. Edge-only so the dense
    /// pricing zone stays uncluttered. Matches the consent + method
    /// preview scatter language for visual consistency across the
    /// onboarding endgame.
    private static let paywallPlacements: [StickerPlacement] = [
        StickerPlacement(sticker: .sparkleGlossy,
                         position: CGPoint(x: 0.08, y: 0.07),
                         size: 28, rotation: -12, phaseDelay: 0.00),
        StickerPlacement(sticker: .bowIridescent,
                         position: CGPoint(x: 0.93, y: 0.08),
                         size: 32, rotation: 14, phaseDelay: 0.30),
        StickerPlacement(sticker: .heartGlossy,
                         position: CGPoint(x: 0.07, y: 0.94),
                         size: 28, rotation: 11, phaseDelay: 0.60),
        StickerPlacement(sticker: .starLineart,
                         position: CGPoint(x: 0.93, y: 0.95),
                         size: 26, rotation: -10, phaseDelay: 0.85),
    ]

    // MARK: - Top bar (close + restore)

    private var topBar: some View {
        HStack {
            if dismissable {
                Button {
                    Haptics.light()
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Palette.bgElevated, in: Circle())
                        .tappableArea()
                }
                .accessibilityLabel("Close paywall")
                .buttonStyle(.plain)
            } else {
                Color.clear.frame(width: 32, height: 32)
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

    private var pricingSection: some View {
        VStack(spacing: 14) {
            PricingCard(
                title: "Yearly",
                price: yearlyPrice,
                perWeekEquivalent: yearlySubtitle,
                savings: yearlySavings,
                badge: "3-DAY FREE TRIAL",
                isSelected: selectedPlan == .yearly
            ) {
                Haptics.light()
                withAnimation(Motion.tap) { selectedPlan = .yearly }
            }
            .padding(.top, 10)  // room for the floating badge

            PricingCard(
                title: "Weekly",
                price: weeklyPrice,
                perWeekEquivalent: "Pay as you go",
                isSelected: selectedPlan == .weekly
            ) {
                Haptics.light()
                withAnimation(Motion.tap) { selectedPlan = .weekly }
            }
        }
    }

    /// Yearly card price ("$69.99"). Strips the "/year" suffix used by the
    /// legacy headline text — the card subtitle already carries the
    /// billing cadence so the price reads cleanly.
    private var yearlyPrice: String {
        if let pkg = yearlyPackage {
            return pkg.storeProduct.localizedPriceString
        }
        return "$69.99"
    }

    /// "$1.35/wk · billed $69.99/yr" — factual rate breakdown only.
    /// Savings % renders as its own element below the price (yearlySavings).
    private var yearlySubtitle: String {
        guard let yearly = yearlyPackage else {
            return "$1.35/wk · billed $69.99/yr"
        }
        let yearlyPriceDecimal = yearly.storeProduct.price as NSDecimalNumber
        let perWeek = yearlyPriceDecimal.dividing(by: NSDecimalNumber(value: 52))
        let formatter = yearly.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
        let perWeekStr = formatter.string(from: perWeek) ?? "\(perWeek)"
        let yearlyStr = yearly.storeProduct.localizedPriceString
        return "\(perWeekStr)/wk · billed \(yearlyStr)/yr"
    }

    /// Savings % vs. the weekly plan, derived from the live RC prices when
    /// available. Returns nil when offerings haven't loaded the weekly
    /// package or when the math would round to ≤0% (don't surface a
    /// non-savings claim). Falls back to the spec default when both
    /// packages haven't synced.
    private var yearlySavings: String? {
        guard let yearly = yearlyPackage, let weekly = weeklyPackage else {
            return yearlyPackage == nil && weeklyPackage == nil ? "save 73%" : nil
        }
        let yearlyPriceDecimal = yearly.storeProduct.price as NSDecimalNumber
        let weeklyPriceDecimal = weekly.storeProduct.price as NSDecimalNumber
        guard weeklyPriceDecimal.doubleValue > 0 else { return nil }
        let perWeek = yearlyPriceDecimal.dividing(by: NSDecimalNumber(value: 52))
        let ratio = perWeek.dividing(by: weeklyPriceDecimal).doubleValue
        let savings = Int(((1.0 - ratio) * 100).rounded())
        guard savings > 0 else { return nil }
        return "save \(savings)%"
    }

    private var weeklyPrice: String {
        if let pkg = weeklyPackage {
            return pkg.storeProduct.localizedPriceString
        }
        return "$4.99"
    }

    private var ctaButton: some View {
        Button {
            Haptics.light()
            Task { await purchase() }
        } label: {
            ZStack {
                Text(ctaLabel)
                    .font(.system(size: 16, weight: .bold))
                    .foregroundStyle(Palette.textInverse)
                    .opacity(working ? 0 : 1)
                if working {
                    PulsingDots(color: Palette.textInverse)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(Palette.accent)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
        }
        .buttonStyle(PressFeedbackStyle())
        .disabled(working)
    }

    private var renewalText: some View {
        Text(renewalDisclosure)
            .font(Typo.caption)
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var legalFooter: some View {
        HStack(spacing: 6) {
            Button("Terms") { legalDoc = .terms }
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .buttonStyle(.plain)
            Text("·")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
            Button("Privacy") { legalDoc = .privacy }
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    // MARK: Offerings + Purchase

    private func loadOfferings() async {
        loadingOfferings = true
        offeringsLoadFailed = false
        do {
            let offerings = try await Purchases.shared.offerings()
            offering = offerings.current
            if offering == nil {
                #if DEBUG
                print("[Paywall] offerings returned nil current — check RC dashboard offering '\(RevenueCatConfig.offeringID)' is marked current")
                #endif
                offeringsLoadFailed = true
            }
        } catch {
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
        // Re-entrancy guard. The Button's `.disabled(working)` modifier
        // catches most double-taps, but the gap between tap and the
        // working=true assignment below can race — observed in production
        // logs as the same purchase firing twice for one user tap. This
        // guard makes the function strictly idempotent per call site.
        guard !working else {
            #if DEBUG
            print("[FUNNEL] paywall_purchase_DUPLICATE_SUPPRESSED | already in flight")
            #endif
            return
        }
        guard let package = selectedPackage else {
            errorMessage = "Couldn't load pricing. Check your connection and try again."
            return
        }
        working = true
        errorMessage = nil
        defer { working = false }

        do {
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
