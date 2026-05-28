import SwiftUI
import RevenueCat

// MARK: - DownsellPaywallView
//
// Last-chance discount, presented as a .sheet over PaywallView. Auto-triggers
// after the user dwells on the paywall for ~8s, or immediately on X tap.
// Sheet dismiss returns the user to the paywall (cover stays up; hard
// paywall model). Pricing comes from the RC offering identified by
// `RevenueCatConfig.discountOfferingID`; if that lookup fails the view
// surfaces "Pricing didn't load" and disables the CTA so the user can't
// be charged the wrong product.
//
// Visual model: heart hero + sparkle burst on appear (mirrors plan reveal),
// strikethrough comparison card with scrapbook chrome (24pt corner, 1.5pt
// accent border, hard offset shadow per CLAUDE.md design notes), italic
// Fraunces on the punch word in the headline (JeniFit voice signal),
// single accent CTA + tiny "maybe later" dismiss.

struct DownsellPaywallView: View {
    let onSubscribed: () -> Void
    let onDismiss: () -> Void

    @State private var working = false
    @State private var errorMessage: String?
    @State private var offering: Offering?
    @State private var defaultOffering: Offering?
    @State private var offeringsLoadFailed = false
    @State private var legalDoc: LegalDoc?

    // Entrance animation flags — stagger heart → sparkles → headline → card → CTA.
    @State private var heartVisible = false
    @State private var sparkleBurstActive = false
    @State private var sparkleBurstVisible = false
    @State private var eyebrowVisible = false
    @State private var headlineVisible = false
    @State private var cardVisible = false
    @State private var ctaVisible = false

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

    // MARK: Package lookup (strict — no fallbacks, lets the "load failed"
    // row surface so the user is never offered the wrong price/product).

    private var discountPackage: Package? {
        offering?.availablePackages.first {
            $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.yearlyDiscount
        }
    }

    private var standardYearlyPackage: Package? {
        defaultOffering?.availablePackages.first {
            $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.yearly
        }
    }

    // MARK: Pricing text

    private var discountPriceText: String {
        discountPackage?.storeProduct.localizedPriceString ?? "—"
    }

    /// Strikethrough comparison price. Pulled live from the default offering's
    /// yearly so the comparison stays accurate if pricing changes.
    private var standardPriceText: String {
        standardYearlyPackage?.storeProduct.localizedPriceString ?? "$69.99"
    }

    /// Per-week math + savings amount, both derived from live storeProduct
    /// prices. Returns "" if discount package hasn't loaded so the UI shows
    /// nothing rather than a fabricated number.
    private var perWeekText: String {
        guard let pkg = discountPackage else { return "" }
        let yearly = pkg.storeProduct.price as NSDecimalNumber
        let perWeek = yearly.dividing(by: NSDecimalNumber(value: 52))
        let formatter = pkg.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
        let perWeekStr = formatter.string(from: perWeek) ?? "\(perWeek)"
        return "Just \(perWeekStr)/week"
    }

    private var savingsAmountText: String? {
        guard let discount = discountPackage,
              let standard = standardYearlyPackage else { return nil }
        let discountPrice = discount.storeProduct.price as NSDecimalNumber
        let standardPrice = standard.storeProduct.price as NSDecimalNumber
        let saved = standardPrice.subtracting(discountPrice)
        guard saved.doubleValue > 0 else { return nil }
        let formatter = standard.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
        let savedStr = formatter.string(from: saved) ?? "\(saved)"
        return "you save \(savedStr)"
    }

    private static let defaultCurrencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    private var renewalDisclosure: String {
        guard discountPackage != nil else { return "" }
        return "\(discountPriceText)/year. Auto-renews. Cancel anytime in Settings."
    }

    // MARK: Sparkle burst placements (mirrors the plan-reveal pattern)

    private static let sparkleBurst: [(CGSize, CGFloat)] = [
        (CGSize(width: -64, height: -38), 22),
        (CGSize(width:  62, height: -42), 18),
        (CGSize(width: -70, height:  28), 16),
        (CGSize(width:  70, height:  34), 20),
        (CGSize(width:   0, height: -68), 14),
        (CGSize(width: -22, height:  60), 12),
    ]

    // MARK: Body

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: Space.lg) {
                    Spacer().frame(height: 56)

                    heroBlock
                        .padding(.top, Space.sm)

                    headlineBlock

                    priceCard
                        .padding(.horizontal, Space.sm)

                    if offeringsLoadFailed {
                        offeringsLoadFailedRow
                    }

                    ctaBlock

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.stateBad)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !renewalDisclosure.isEmpty {
                        Text(renewalDisclosure)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    legalFooter
                        .padding(.top, Space.xs)
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
        .task {
            await loadOfferings()
            runEntrance()
        }
    }

    // MARK: - Hero (heart sticker + halo + sparkle burst)

    private var heroBlock: some View {
        ZStack {
            ForEach(Self.sparkleBurst.indices, id: \.self) { i in
                let entry = Self.sparkleBurst[i]
                Image(StickerName.sparkleGlossy.assetName)
                    .resizable()
                    .scaledToFit()
                    .frame(width: entry.1, height: entry.1)
                    .opacity(sparkleBurstVisible ? 0.85 : 0)
                    .scaleEffect(sparkleBurstActive ? 1 : 0.4)
                    .offset(sparkleBurstActive ? entry.0 : .zero)
            }
            Circle()
                .fill(Palette.accent.opacity(0.10))
                .frame(width: 124, height: 124)
                .scaleEffect(heartVisible ? 1 : 0.5)
                .opacity(heartVisible ? 1 : 0)
            Image(StickerName.heartGlossy.assetName)
                .resizable()
                .scaledToFit()
                .frame(width: 86, height: 86)
                .scaleEffect(heartVisible ? 1 : 0.6)
                .opacity(heartVisible ? StickerName.heartGlossy.style.opacity : 0)
        }
        .animation(.spring(response: 0.55, dampingFraction: 0.65), value: heartVisible)
    }

    // MARK: - Headline (eyebrow + italic-accent title + subhead)

    private var headlineBlock: some View {
        VStack(spacing: Space.sm) {
            Text("LIMITED-TIME OFFER")
                .font(Typo.eyebrow)
                .tracking(1.5)
                .foregroundStyle(Palette.accent)
                .opacity(eyebrowVisible ? 1 : 0)
                .offset(y: eyebrowVisible ? 0 : 8)

            ItalicAccentText("Half off, just for you.",
                             italic: ["just for you."],
                             alignment: .center)
                .padding(.horizontal, Space.sm)
                .opacity(headlineVisible ? 1 : 0)
                .offset(y: headlineVisible ? 0 : 12)

            Text("One year of JeniFit at half price. Your plan, your coach, every workout.")
                .font(Typo.body)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.md)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(headlineVisible ? 1 : 0)
        }
    }

    // MARK: - Price card (scrapbook chrome + strikethrough + big discount price)

    private var priceCard: some View {
        let hasPricing = discountPackage != nil
        return ZStack(alignment: .topTrailing) {
            VStack(spacing: 8) {
                Text("YEARLY · BEST VALUE")
                    .font(Typo.eyebrow)
                    .tracking(1.5)
                    .foregroundStyle(Palette.textSecondary)

                if hasPricing {
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Text(standardPriceText)
                            .font(.system(size: 18, weight: .medium))
                            .foregroundStyle(Palette.textSecondary)
                            .strikethrough(true, color: Palette.textSecondary)
                        Text(discountPriceText)
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(Palette.accent)
                    }
                    .padding(.top, 2)

                    Text("per year")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)

                    if !perWeekText.isEmpty {
                        Text(perWeekText)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .padding(.top, Space.xs)
                    }

                    if let savings = savingsAmountText {
                        Text(savings)
                            .font(Typo.eyebrow)
                            .tracking(1.5)
                            .foregroundStyle(Palette.accent)
                            .padding(.horizontal, Space.md)
                            .padding(.vertical, 6)
                            .background(Palette.accent.opacity(0.12), in: Capsule())
                            .padding(.top, Space.xs)
                    }
                } else {
                    Text("—")  // voice-lint:allow — visual placeholder for missing price, not prose
                        .font(.system(size: 40, weight: .bold))
                        .foregroundStyle(Palette.textSecondary)
                    Text("pricing unavailable")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                }
            }
            .padding(.vertical, Space.lg)
            .padding(.horizontal, Space.lg)
            .frame(maxWidth: .infinity)
            .background(scrapbookChrome(tint: Palette.accent))

            if hasPricing {
                Text("50% OFF")
                    .font(Typo.eyebrow)
                    .tracking(1.5)
                    .foregroundStyle(Palette.textInverse)
                    .padding(.horizontal, Space.sm)
                    .padding(.vertical, 6)
                    .background(Palette.accent, in: Capsule())
                    .offset(x: -Space.md, y: -10)
            }
        }
        .scaleEffect(cardVisible ? 1 : 0.92)
        .opacity(cardVisible ? 1 : 0)
        .animation(.spring(response: 0.55, dampingFraction: 0.78), value: cardVisible)
    }

    // MARK: - Scrapbook chrome (24pt, 1.5pt accent border, hard offset shadow)

    private func scrapbookChrome(tint: Color) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(tint.opacity(0.15))
                .offset(x: 4, y: 4)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.bgElevated)
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(tint, lineWidth: 1.5)
        }
    }

    // MARK: - CTA + maybe later

    private var ctaBlock: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.medium()
                Task { await purchase() }
            } label: {
                ZStack {
                    Text("Claim 50% off")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(Palette.textInverse)
                        .opacity(working ? 0 : 1)
                    if working {
                        PulsingDots(color: Palette.textInverse)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Palette.accent)
                .clipShape(RoundedRectangle(cornerRadius: Radius.md, style: .continuous))
            }
            .buttonStyle(PressFeedbackStyle())
            .disabled(working || discountPackage == nil)
            .opacity(discountPackage == nil ? 0.5 : 1)

            Button {
                Haptics.light()
                onDismiss()
            } label: {
                Text("Maybe later")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(Palette.textSecondary)
                    .padding(.vertical, 6)
            }
            .buttonStyle(.plain)
        }
        .opacity(ctaVisible ? 1 : 0)
    }

    // MARK: - Top bar (X dismisses sheet, Restore pulls existing entitlement)

    private var topBar: some View {
        HStack {
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
            .accessibilityLabel("Close offer")
            .buttonStyle(.plain)
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

    // MARK: - Entrance choreography

    private func runEntrance() {
        Haptics.success()

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
        withAnimation(.spring(response: 0.55, dampingFraction: 0.78).delay(0.85)) {
            cardVisible = true
        }
        withAnimation(.easeOut(duration: 0.35).delay(1.10)) {
            ctaVisible = true
        }
    }

    // MARK: - Offerings + purchase

    private func loadOfferings() async {
        offeringsLoadFailed = false
        do {
            let offerings = try await Purchases.shared.offerings()
            offering = offerings.offering(identifier: RevenueCatConfig.discountOfferingID)
            defaultOffering = offerings.current
            #if DEBUG
            let allIDs = offerings.all.keys.sorted()
            let pkgIDs = offering?.availablePackages.map { $0.storeProduct.productIdentifier } ?? []
            print("[DownsellPaywall] offerings loaded — all=\(allIDs), discount-packages=\(pkgIDs)")
            #endif
            if offering == nil || discountPackage == nil {
                #if DEBUG
                print("[DownsellPaywall] discount offering or product missing — expected offering '\(RevenueCatConfig.discountOfferingID)' with product '\(RevenueCatConfig.ProductID.yearlyDiscount)'")
                #endif
                offeringsLoadFailed = true
            }
        } catch {
            #if DEBUG
            print("[DownsellPaywall] offerings load FAILED: \(error)")
            #endif
            offeringsLoadFailed = true
        }
    }

    private func purchase() async {
        // Re-entrancy guard mirroring PaywallView.purchase — prevents
        // the same purchase firing twice when a fast tap beats the
        // working=true assignment.
        guard !working else {
            #if DEBUG
            print("[DownsellPaywall] purchase_DUPLICATE_SUPPRESSED | already in flight")
            #endif
            return
        }
        guard let package = discountPackage else {
            errorMessage = "Couldn't load pricing. Check your connection and try again."
            return
        }
        working = true
        errorMessage = nil
        defer { working = false }

        do {
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled { return }
            let isActive = result.customerInfo
                .entitlements[RevenueCatConfig.entitlementID]?.isActive == true
            if isActive {
                Haptics.success()
                onSubscribed()
            } else {
                errorMessage = "Purchase didn't activate Pro. Try again or contact support@jenifit.app."
            }
        } catch {
            #if DEBUG
            print("[DownsellPaywall] purchase FAILED: \(error)")
            #endif
            errorMessage = "Couldn't complete purchase. Try again in a moment."
        }
    }

    private func restore() async {
        do {
            let info = try await Purchases.shared.restorePurchases()
            let isActive = info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
            if isActive {
                Haptics.success()
                onSubscribed()
            }
        } catch {
            #if DEBUG
            print("[DownsellPaywall] restore FAILED: \(error)")
            #endif
        }
    }
}
