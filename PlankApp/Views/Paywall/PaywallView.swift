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

    init(
        dismissable: Bool = true,
        onSubscribed: @escaping () -> Void,
        onRestore: @escaping () -> Void = {},
        onDismiss: @escaping () -> Void = {}
    ) {
        self.dismissable = dismissable
        self.onSubscribed = onSubscribed
        self.onRestore = onRestore
        self.onDismiss = onDismiss
    }

    // On-device fast-path mirror, written by handleOnboardingComplete +
    // EditProfileView.selectBodyFocus. Cross-device sync goes through
    // UserRecord (synced via SyncService.hydrateUser on sign-in); the
    // mirror lags by one EditProfile save. effectiveBodyFocus below
    // prefers UserRecord when present so a fresh device-B sign-in
    // shows the right personalized headline immediately.
    @AppStorage("bodyFocus") private var bodyFocusMirror: String = ""

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

    /// Personalized headline keyed off the bodyFocus.first answer from
    /// onboarding (Phase 4 multi-select, surfaced to AppStorage in
    /// PlankAIApp.handleOnboardingComplete). Returns the base + the italic
    /// fragments separately so the view can render with ItalicAccentText
    /// — italic Fraunces on the body-zone phrase or "30 days."
    private var headlineParts: (base: String, italic: [String]) {
        switch bodyFocus {
        case "flatBelly": return ("Define your flat belly in 30 days.",  ["flat belly"])
        case "tonedArms": return ("Sculpt your toned arms in 30 days.",  ["toned arms"])
        case "roundButt": return ("Build your round butt in 30 days.",   ["round butt"])
        case "slimLegs":  return ("Define your slim legs in 30 days.",   ["slim legs"])
        default:          return ("Become her in 30 days.",              ["30 days."])
        }
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

    /// Localized price for the yearly card ("$29.99/year" in en-US,
    /// equivalent in other locales). Falls back to a placeholder while
    /// offerings are loading or if the lookup misses.
    private var yearlyPriceText: String {
        if let pkg = yearlyPackage {
            return "\(pkg.storeProduct.localizedPriceString)/year"
        }
        return "$29.99/year"
    }

    /// Per-week math + savings %, both computed from the actual yearly
    /// and weekly storeProduct prices. Uses the yearly product's price
    /// formatter so the per-week amount shows in the same locale/currency.
    private var yearlyPerWeekText: String {
        guard let yearly = yearlyPackage else {
            return "Just $0.58/week · save 88%"
        }
        let yearlyPrice = yearly.storeProduct.price as NSDecimalNumber
        let perWeek = yearlyPrice.dividing(by: NSDecimalNumber(value: 52))
        let formatter = yearly.storeProduct.priceFormatter ?? defaultCurrencyFormatter
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

    private var defaultCurrencyFormatter: NumberFormatter {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }

    private var ctaLabel: String {
        switch selectedPlan {
        case .yearly: return "Start free trial"
        case .weekly: return "Subscribe — \(weeklyPriceText)"
        }
    }

    private var renewalDisclosure: String {
        switch selectedPlan {
        case .yearly:
            return "3 days free, then \(yearlyPriceText). Auto-renews. Cancel anytime in Settings."
        case .weekly:
            return "\(weeklyPriceText). Auto-renews. Cancel anytime in Settings."
        }
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.lg) {
                    // Reserve space for the floating top bar.
                    Spacer().frame(height: 48)

                    headerBlock

                    benefitsSection

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

    // MARK: - Header block (eyebrow + headline + subhead)

    private var headerBlock: some View {
        let parts = headlineParts
        return VStack(spacing: Space.sm) {
            Text("JENIFIT PREMIUM")
                .font(Typo.eyebrow)
                .tracking(1.5)
                .foregroundStyle(Palette.accent)

            ItalicAccentText(parts.base,
                             italic: parts.italic,
                             alignment: .center)
                .padding(.horizontal, Space.sm)

            Text("Unlock your full plan, your coach & the path to your strongest self.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.md)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity)
    }

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
                }
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

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            benefitRow(
                heading: "Unlimited custom workouts",
                detail: "Built around your goals & level"
            )
            benefitRow(
                heading: "Jeni, your personal coach",
                detail: "Form tips, swaps, and pep talks"
            )
            benefitRow(
                heading: "Progress tracking & check-ins",
                detail: "See your glow-up week by week"
            )
        }
    }

    private func benefitRow(heading: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: Space.sm) {
            ZStack {
                Circle()
                    .fill(Palette.accent.opacity(0.12))
                    .frame(width: 24, height: 24)
                Image(systemName: "checkmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Palette.accent)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(heading)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Text(detail)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 0)
        }
    }

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
                withAnimation(.easeOut(duration: 0.2)) { selectedPlan = .yearly }
            }
            .padding(.top, 10)  // room for the floating badge

            PricingCard(
                title: "Weekly",
                price: weeklyPrice,
                perWeekEquivalent: "Pay as you go",
                isSelected: selectedPlan == .weekly
            ) {
                Haptics.light()
                withAnimation(.easeOut(duration: 0.2)) { selectedPlan = .weekly }
            }
        }
    }

    /// Yearly card price ("$59.99"). Strips the "/year" suffix used by the
    /// legacy headline text — the card subtitle already carries the
    /// billing cadence so the price reads cleanly.
    private var yearlyPrice: String {
        if let pkg = yearlyPackage {
            return pkg.storeProduct.localizedPriceString
        }
        return "$59.99"
    }

    /// "$1.15/wk · billed $59.99/yr" — factual rate breakdown only.
    /// Savings % renders as its own element below the price (yearlySavings).
    private var yearlySubtitle: String {
        guard let yearly = yearlyPackage else {
            return "$1.15/wk · billed $59.99/yr"
        }
        let yearlyPriceDecimal = yearly.storeProduct.price as NSDecimalNumber
        let perWeek = yearlyPriceDecimal.dividing(by: NSDecimalNumber(value: 52))
        let formatter = yearly.storeProduct.priceFormatter ?? defaultCurrencyFormatter
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
            return yearlyPackage == nil && weeklyPackage == nil ? "save 77%" : nil
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
                print("[Paywall] offerings returned nil current — check RC dashboard offering '\(RevenueCatConfig.offeringID)' is marked current")
                offeringsLoadFailed = true
            }
        } catch {
            print("[Paywall] offerings load FAILED: \(error)")
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
                return
            }
            let isActive = result.customerInfo
                .entitlements[RevenueCatConfig.entitlementID]?.isActive == true
            if isActive {
                Haptics.success()
                onSubscribed()
            } else {
                errorMessage = "Purchase didn't activate Pro. Try again or contact support@jenifit.app."
            }
        } catch {
            print("[Paywall] purchase FAILED: \(error)")
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
            print("[Paywall] restore FAILED: \(error)")
            restoreAlert = RestoreAlert(
                title: "Couldn't restore",
                message: "Something went wrong checking your subscription. Try again in a moment."
            )
        }
    }
}
