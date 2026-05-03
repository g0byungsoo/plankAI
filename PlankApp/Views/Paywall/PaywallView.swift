import SwiftUI
import RevenueCat

// MARK: - PaywallView
//
// Post-onboarding paywall. Cal AI structural moves (direct verb headline,
// benefit checklist before pricing, trust microcopy above CTA, dynamic
// CTA copy, plain-English auto-renewal disclosure, footer link triplet),
// translated into absmaxxing's voice (calm, confident, terracotta accent
// on warm cream, no preachy or all-caps emphasis).
//
// Phase D wires RevenueCat: offerings.current populates the cards by
// productIdentifier; storeProduct.priceFormatter formats prices in the
// user's locale; CTA calls Purchases.shared.purchase(package:); savings
// math is computed dynamically from the actual yearly + weekly prices.

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

    @AppStorage("focusArea") private var focusArea: String = ""

    @State private var selectedPlan: Plan = .yearly
    @State private var working = false
    @State private var errorMessage: String?
    @State private var legalDoc: LegalDoc?
    @State private var offering: Offering?
    @State private var loadingOfferings = true
    @State private var offeringsLoadFailed = false

    private enum Plan: Equatable { case yearly, weekly }

    private enum LegalDoc: String, Identifiable {
        case terms, privacy
        var id: String { rawValue }
        var url: URL {
            switch self {
            case .terms: return URL(string: "https://absmaxxing.com/terms")!
            case .privacy: return URL(string: "https://absmaxxing.com/privacy")!
            }
        }
    }

    // MARK: Copy

    /// Headline switches on the focusArea answer from onboarding. The
    /// user's commitment from the quiz earns a personalized headline —
    /// "their plan", not a generic offer. Falls back to the default
    /// "Core Reset" line for fullCore or unset.
    private var headline: String {
        switch focusArea {
        case "abs":       return "Define your abs in 30 days."
        case "obliques":  return "Sculpt your waistline in 30 days."
        case "lowerBack": return "Build your core foundation in 30 days."
        default:          return "Start your 30-day Core Reset."
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
        case .yearly: return "Start your 3-day free trial"
        case .weekly: return "Subscribe — \(weeklyPriceText)"
        }
    }

    private var renewalDisclosure: String {
        switch selectedPlan {
        case .yearly:
            return "3 days free, then \(yearlyPriceText). Plan auto-renews unless you cancel at least 24 hours before the period ends. Manage in iOS Settings."
        case .weekly:
            return "Subscribed at \(weeklyPriceText). Plan auto-renews unless you cancel at least 24 hours before the period ends. Manage in iOS Settings."
        }
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .topLeading) {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: Space.lg) {
                    Spacer().frame(height: dismissable ? 40 : 24)

                    Text(headline)
                        .font(Typo.title)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    benefitsSection
                    pricingSection
                    if offeringsLoadFailed {
                        offeringsLoadFailedRow
                    }
                    trustMicroCopy
                    ctaButton
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.stateBad)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    restoreLink
                    renewalText
                    legalFooter
                }
                .padding(.horizontal, Space.lg)
                .padding(.bottom, Space.xl)
            }

            if dismissable {
                closeButton
                    .padding(.leading, Space.lg)
                    .padding(.top, Space.sm)
            }
        }
        .sheet(item: $legalDoc) { doc in
            SafariView(url: doc.url).ignoresSafeArea()
        }
        .task {
            await loadOfferings()
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

    private var closeButton: some View {
        Button {
            Haptics.light()
            onDismiss()
        } label: {
            Image(systemName: "xmark")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .frame(width: 32, height: 32)
                .background(Palette.bgElevated)
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    private var benefitsSection: some View {
        VStack(alignment: .leading, spacing: Space.md) {
            benefitRow(
                heading: "AI form coaching",
                detail: "Real-time feedback on every plank, every second."
            )
            benefitRow(
                heading: "5-minute daily routines",
                detail: "No gym, no equipment, no excuses."
            )
            benefitRow(
                heading: "Reminder before billing",
                detail: "We'll let you know 24 hours ahead. Cancel with one tap."
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
        VStack(spacing: 12) {
            yearlyCard
            weeklyCard
        }
    }

    private var yearlyCard: some View {
        let isSelected = selectedPlan == .yearly
        return Button {
            Haptics.light()
            withAnimation(.easeOut(duration: 0.2)) { selectedPlan = .yearly }
        } label: {
            VStack(alignment: .leading, spacing: Space.sm) {
                HStack(alignment: .center) {
                    Text("3-DAY FREE TRIAL")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Palette.textInverse)
                        .tracking(1.5)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Palette.accent)
                        .clipShape(Capsule())
                    Spacer()
                    selectionIndicator(isSelected: isSelected)
                }
                Text(yearlyPriceText)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(Palette.textPrimary)
                Text(yearlyPerWeekText)
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(isSelected ? Palette.accent : Palette.divider, lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private var weeklyCard: some View {
        let isSelected = selectedPlan == .weekly
        return Button {
            Haptics.light()
            withAnimation(.easeOut(duration: 0.2)) { selectedPlan = .weekly }
        } label: {
            HStack {
                Text(weeklyPriceText)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(Palette.textPrimary)
                Spacer()
                selectionIndicator(isSelected: isSelected)
            }
            .padding(Space.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Palette.bgElevated)
            .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.md, style: .continuous)
                    .stroke(isSelected ? Palette.accent : Palette.divider, lineWidth: isSelected ? 2 : 1)
            )
            .scaleEffect(isSelected ? 1.02 : 1.0)
            .animation(.easeOut(duration: 0.2), value: isSelected)
        }
        .buttonStyle(.plain)
    }

    private func selectionIndicator(isSelected: Bool) -> some View {
        ZStack {
            Circle()
                .stroke(isSelected ? Palette.accent : Palette.textSecondary.opacity(0.4), lineWidth: 1.5)
                .frame(width: 22, height: 22)
            if isSelected {
                Circle()
                    .fill(Palette.accent)
                    .frame(width: 14, height: 14)
                    .transition(.scale.combined(with: .opacity))
            }
        }
        .animation(.easeOut(duration: 0.2), value: isSelected)
    }

    private var trustMicroCopy: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(Palette.textPrimary)
            Text("Cancel anytime in iOS Settings")
                .font(Typo.caption)
                .foregroundStyle(Palette.textPrimary)
        }
        .frame(maxWidth: .infinity, alignment: .center)
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

    private var restoreLink: some View {
        HStack(spacing: 4) {
            Text("Already subscribed?")
                .font(Typo.caption)
                .foregroundStyle(Palette.textSecondary)
            Button {
                Haptics.light()
                onRestore()
            } label: {
                Text("Restore")
                    .font(Typo.caption.weight(.semibold))
                    .foregroundStyle(Palette.accent)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var renewalText: some View {
        Text(renewalDisclosure)
            .font(.system(size: 11))
            .foregroundStyle(Palette.textSecondary)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var legalFooter: some View {
        HStack(spacing: 8) {
            Button("Terms") { legalDoc = .terms }
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
                .buttonStyle(.plain)
            Text("·")
                .font(.system(size: 11))
                .foregroundStyle(Palette.textSecondary)
            Button("Privacy") { legalDoc = .privacy }
                .font(.system(size: 11))
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
                errorMessage = "Purchase didn't activate Pro. Try again or contact support@absmaxxing.com."
            }
        } catch {
            print("[Paywall] purchase FAILED: \(error)")
            errorMessage = "Couldn't complete purchase. Try again in a moment."
        }
    }
}
