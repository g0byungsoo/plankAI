import SwiftUI
import RevenueCat

// MARK: - DownsellPaywallView
//
// The quieter-price recovery (2026-07-07 redesign), presented as a
// .sheet after a yearly Apple-sheet cancel or an X-dismiss. Pricing
// comes from the RC offering identified by
// `RevenueCatConfig.discountOfferingID`; if that lookup fails the view
// surfaces the failure row and disables the CTA so the user can't be
// charged the wrong product.
//
// Visual model — the keep-wall's receipt grammar, third appearance:
// defusal eyebrow ("nothing was charged") → serif headline carrying
// the live magnitude ("the year, 30% off.") → ONE receipt card
// (today with the struck standard price · covers · renews-at-this-
// price) with a single save-% marker → cocoa CTA restating the
// billed-today number → quiet decline. No stickers, no sparkle burst
// (a recovery moment is not an earned moment — scatter rule), no
// competing badges. The luxury is restraint; the honesty is the
// lever: this SKU renews at the discounted price every year, and the
// offer genuinely shows once per install — both said plainly.

struct DownsellPaywallView: View {
    /// "exit_intent" (once-per-install auto-show) or "reclaim" (the
    /// wall's saved-offer row). Analytics only.
    var trigger: String = "exit_intent"
    /// The tier whose abandon opened this recovery, when known.
    var abandonedPlan: String? = nil
    let onSubscribed: () -> Void
    let onDismiss: () -> Void

    @State private var working = false
    @State private var errorMessage: String?
    @State private var offering: Offering?
    @State private var defaultOffering: Offering?
    @State private var offeringsLoadFailed = false
    /// All loaded offerings — lets the standard-yearly lookup search
    /// broadly and lets the downsell mirror the paywall's mock-preview
    /// state so the "original price" always shows + agrees.
    @State private var allOfferings: [Offering] = []
    @State private var legalDoc: LegalDoc?

    // Entrance animation flags — quiet stagger: eyebrow → headline →
    // receipt card → CTA. (The heart/halo/sparkle-burst hero died in
    // the 2026-07-07 redesign — celebration chrome on a defusal beat.)
    @State private var eyebrowVisible = false
    @State private var headlineVisible = false
    @State private var cardVisible = false
    @State private var ctaVisible = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

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
        // Search every loaded offering so the ORIGINAL yearly price
        // reliably resolves (default/preview first, then discount, then
        // any other offering). First match wins. Fully live.
        let ordered = [defaultOffering, offering].compactMap { $0 } + allOfferings
        for off in ordered {
            if let pkg = off.availablePackages.first(where: {
                $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.yearly
            }) { return pkg }
        }
        return nil
    }

    /// Mirrors PaywallView.debugMockPricing: mock while the v1.0.7
    /// quarterly product isn't resolving (ASC/RC setup incomplete), so
    /// the downsell's original price MATCHES the paywall's yearly during
    /// preview instead of diverging. Always false in release.
    private var isMockPreview: Bool {
        #if DEBUG
        return !allOfferings.contains { off in
            off.availablePackages.contains {
                $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.quarterly
            }
        }
        #else
        return false
        #endif
    }

    /// The standard yearly price as a number — real package, or the
    /// shared mock value during the DEBUG preview. Drives the discount %.
    private var standardYearlyPrice: Decimal? {
        if let p = standardYearlyPackage?.storeProduct.price { return p }
        #if DEBUG
        if isMockPreview { return RevenueCatConfig.MockPrice.yearlyValue }
        #endif
        return nil
    }

    // MARK: Pricing text

    private var discountPriceText: String {
        discountPackage?.storeProduct.localizedPriceString
            ?? (isQAPreview ? "$34.99" : "—")
    }

    /// Strikethrough comparison price. Pulled live from the default offering's
    /// yearly so the comparison stays accurate if pricing changes.
    private var standardPriceText: String {
        // The ORIGINAL (pre-discount) price, struck through to emphasize
        // the discount. Real ASC price when resolved; the shared mock
        // during the DEBUG preview so it matches the paywall; hidden (not
        // fabricated) only in a release where it genuinely can't resolve.
        if let real = standardYearlyPackage?.storeProduct.localizedPriceString {
            return real
        }
        if isQAPreview { return "$49.99" }
        #if DEBUG
        if isMockPreview { return RevenueCatConfig.MockPrice.yearlyText }
        #endif
        return ""
    }

    /// Real discount magnitude from LIVE prices. nil until both packages
    /// load. Drives the copy so it never claims a fraction the ASC
    /// prices don't actually back.
    private var discountPercent: Int? {
        guard let discount = discountPackage, let s = standardYearlyPrice else {
            return isQAPreview ? 30 : nil
        }
        let d = (discount.storeProduct.price as NSDecimalNumber).doubleValue
        let sPrice = (s as NSDecimalNumber).doubleValue
        guard sPrice > 0, d < sPrice else { return nil }
        return Int(((sPrice - d) / sPrice * 100).rounded())
    }
    private var isHalfOff: Bool { (48...52).contains(discountPercent ?? -1) }
    /// Headline magnitude — "half off" ONLY when the prices back it,
    /// else the true percent, else neutral until loaded.
    private var magnitudeLabel: String {
        guard let pct = discountPercent else { return "your best price" }
        return isHalfOff ? "half off" : "\(pct)% off"
    }

    private static let defaultCurrencyFormatter: NumberFormatter = {
        let f = NumberFormatter()
        f.numberStyle = .currency
        return f
    }()

    private var renewalDisclosure: String {
        guard discountPackage != nil else { return "" }
        return "\(discountPriceText)/year. auto-renews at this same price. cancel anytime in settings."
    }

    // MARK: Body

    var body: some View {
        ZStack(alignment: .top) {
            Palette.bgPrimary.ignoresSafeArea()

            ScrollView {
                VStack(spacing: 0) {
                    Spacer().frame(height: 72)

                    headlineBlock

                    receiptCard
                        .padding(.top, Space.xl)

                    if discountPackage != nil {
                        Text("saved to your wall \u{00B7} yours to reclaim anytime")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                            .opacity(cardVisible ? 1 : 0)
                    }

                    if offeringsLoadFailed {
                        offeringsLoadFailedRow
                            .padding(.top, Space.md)
                    }

                    ctaBlock
                        .padding(.top, Space.xl)

                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.stateBad)
                            .multilineTextAlignment(.center)
                            .padding(.top, Space.sm)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    if !renewalDisclosure.isEmpty {
                        Text(renewalDisclosure)
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.textSecondary.opacity(0.8))
                            .multilineTextAlignment(.center)
                            .padding(.top, Space.md)
                            .fixedSize(horizontal: false, vertical: true)
                            .opacity(ctaVisible ? 1 : 0)
                    }

                    legalFooter
                        .padding(.top, Space.sm)
                        .opacity(ctaVisible ? 1 : 0)
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
            Analytics.captureScreen("DownsellPaywall")
            await loadOfferings()
            // Fire AFTER load so price_resolved reflects the real
            // StoreKit resolution — this is the signal that reveals a
            // silent discount-offering failure without a debug build.
            trackDownsellViewed()
            runEntrance()
        }
    }

    /// Emits `downsell_viewed` with the resolved pricing snapshot. The
    /// load-state properties (price_resolved / load_failed) make a silent
    /// discount-offering resolution failure visible in PostHog — the case
    /// where the user reaches the downsell but sees the dead "—" card and
    /// a disabled CTA, which reads in the funnel as "shown but nobody buys."
    private func trackDownsellViewed() {
        var props: [String: Any] = [
            "offering_id": RevenueCatConfig.discountOfferingID,
            "product_id": discountPackage?.storeProduct.productIdentifier
                ?? RevenueCatConfig.ProductID.yearlyDiscount,
            "price_resolved": discountPackage != nil,
            "load_failed": offeringsLoadFailed,
            "trigger": trigger,
            "abandoned_plan": abandonedPlan ?? "none"
        ]
        if let discount = discountPackage?.storeProduct.localizedPriceString {
            props["discount_price"] = discount
        }
        if let standard = standardYearlyPackage?.storeProduct.localizedPriceString {
            props["standard_price"] = standard
        }
        if let pct = discountPercent {
            props["discount_percent"] = pct
        }
        Analytics.track(.downsellViewed, properties: props)
    }

    // MARK: - Headline (defusal eyebrow + serif magnitude + one-line sub)

    /// "the year, 30% off." — the magnitude is live math, never a
    /// claim the ASC prices don't back. Quiet fallback pre-resolve.
    private var headlineParts: (base: String, italic: [String]) {
        guard discountPercent != nil else {
            return ("the year, quieter.", ["quieter."])
        }
        let label = isHalfOff ? "half off" : magnitudeLabel
        return ("the year, \(label).", ["\(label)."])
    }

    private var headlineBlock: some View {
        VStack(spacing: Space.sm) {
            // She just fled a payment sheet — answer "did that charge
            // me?" before selling anything.
            Text("nothing was charged")
                .font(Typo.captionTracked)
                .kerning(1.6)
                .foregroundStyle(Palette.cocoaTertiary)
                .opacity(eyebrowVisible ? 1 : 0)
                .offset(y: eyebrowVisible ? 0 : 8)

            ItalicAccentText(
                headlineParts.base,
                italic: headlineParts.italic,
                baseFont: Typo.heroHeadline,
                italicFont: Typo.heroHeadlineItalic,
                alignment: .center
            )
            .lineSpacing(Typo.heroHeadlineLineGap)
            .kerning(-0.4)
            .padding(.horizontal, Space.sm)
            .opacity(headlineVisible ? 1 : 0)
            .offset(y: headlineVisible ? 0 : 12)

            Text("same plan. same jeni. a price that stays.")
                .font(Typo.teachSub)
                .lineSpacing(Typo.teachSubLineSpacing)
                .foregroundStyle(Palette.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, Space.md)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(headlineVisible ? 1 : 0)
        }
    }

    // MARK: - The anchor card (v6.5 facelift — the wall's family look)

    /// DEBUG-only visual-pass mocks (the `--uitest-downsell-preview`
    /// cover can present before offerings resolve on a sim).
    private var isQAPreview: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.arguments
            .contains("--uitest-downsell-preview")
        #else
        return false
        #endif
    }

    /// The bare per-week lead ("$0.67") for the anchor layout.
    private var perWeekLeadText: String? {
        guard let pkg = discountPackage else {
            return isQAPreview ? "$0.67" : nil
        }
        let yearly = pkg.storeProduct.price as NSDecimalNumber
        let formatter = pkg.storeProduct.priceFormatter ?? Self.defaultCurrencyFormatter
        return formatter.string(from: yearly.dividing(by: NSDecimalNumber(value: 52)))
    }

    /// One clean card in the wall's anchor grammar: title + honest
    /// sub on the left; the per-week rate leading on the right with
    /// the REAL struck standard price and the billed year beneath.
    /// Selected-state chrome (this sheet has one choice — it wears
    /// the chosen look).
    private var receiptCard: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text("the year")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize()
                    if let pct = discountPercent {
                        Text("save \(pct)%")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Palette.textPrimary)
                            .fixedSize()
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(Capsule().fill(Palette.accentSubtle))
                    }
                }
                Text("renews at this price, every year")
                    .font(.system(size: 12))
                    .foregroundStyle(Palette.textSecondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                if let perWeekLeadText {
                    ((Text(perWeekLeadText)
                        .font(.custom("Fraunces72pt-SemiBold", size: 22))
                        .foregroundStyle(Palette.textPrimary)
                     + Text(" /wk")
                        .font(.system(size: 12))
                        .foregroundStyle(Palette.textSecondary)))
                        .lineLimit(1)
                        .fixedSize()
                    HStack(spacing: 6) {
                        if !standardPriceText.isEmpty {
                            Text(standardPriceText)
                                .font(.system(size: 11))
                                .foregroundStyle(Palette.cocoaTertiary)
                                .strikethrough(true, color: Palette.cocoaTertiary)
                        }
                        Text("\(discountPriceText) per year")
                            .font(.system(size: 11))
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                } else {
                    Text("loading your price…")
                        .font(.system(size: 13))
                        .foregroundStyle(Palette.textSecondary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Palette.bgElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Palette.bgInverse, lineWidth: 2)
                )
        )
        .scaleEffect(cardVisible ? 1 : 0.96)
        .opacity(cardVisible ? 1 : 0)
        .accessibilityElement(children: .combine)
    }

    // MARK: - CTA + maybe later

    private var ctaBlock: some View {
        VStack(spacing: 12) {
            Button {
                Haptics.medium()
                Analytics.track(.downsellCtaTapped, properties: [
                    "product_id": discountPackage?.storeProduct.productIdentifier
                        ?? RevenueCatConfig.ProductID.yearlyDiscount,
                    "price_resolved": discountPackage != nil
                ])
                Task { await purchase() }
            } label: {
                ZStack {
                    // Billed-today transparency, same grammar as the
                    // wall CTA — the sheet must never know more than
                    // the button did.
                    Text(discountPackage != nil
                         ? "keep the year \u{00B7} \(discountPriceText) today"
                         : "keep the year")
                        .font(.system(size: 17, weight: .semibold))
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
                // The wall CTA's single specular highlight — the cocoa
                // mass reads as a pressed, premium surface.
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
            .disabled(working || discountPackage == nil)
            .opacity(discountPackage == nil ? 0.5 : 1)

            Button {
                Haptics.light()
                Analytics.track(.downsellDismissed, properties: ["via": "maybe_later"])
                onDismiss()
            } label: {
                Text("maybe later")
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
                Analytics.track(.downsellDismissed, properties: ["via": "x"])
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

    /// Quiet stagger — a soft haptic (she just fled a payment sheet;
    /// a success buzz here read tone-deaf), then eyebrow → headline →
    /// receipt → CTA fade-rises. Reduce Motion lands everything at
    /// once.
    private func runEntrance() {
        Haptics.soft()

        guard !reduceMotion else {
            eyebrowVisible = true
            headlineVisible = true
            cardVisible = true
            ctaVisible = true
            return
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.10)) {
            eyebrowVisible = true
        }
        withAnimation(.easeOut(duration: 0.45).delay(0.28)) {
            headlineVisible = true
        }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.55)) {
            cardVisible = true
        }
        withAnimation(.easeOut(duration: 0.35).delay(0.80)) {
            ctaVisible = true
        }
    }

    // MARK: - Offerings + purchase

    private func loadOfferings() async {
        // Purchases.shared fatalErrors pre-configure — a presentation
        // that races PaymentService.configure() must degrade to the
        // failure row, not crash (crash-verified 2026-07-17; the
        // SmallerStepSheet always had this guard).
        guard Purchases.isConfigured else {
            offeringsLoadFailed = true
            return
        }
        offeringsLoadFailed = false
        do {
            let offerings = try await Purchases.shared.offerings()
            allOfferings = Array(offerings.all.values)
            offering = offerings.offering(identifier: RevenueCatConfig.discountOfferingID)
            // v3.0 bug fix: the strikethrough must read the SAME standard
            // yearly the main paywall shows. PaywallView uses the DEBUG
            // preview offering (v1_0_7) when present, else offerings.current
            // — mirror that exactly here, or the two screens show
            // different yearly prices (the "$69.99 vs $49.99" report).
            #if DEBUG
            defaultOffering = offerings.all[RevenueCatConfig.previewOfferingID] ?? offerings.current
            #else
            defaultOffering = offerings.current
            #endif
            #if DEBUG
            // Full price diagnostic — dumps every offering, every package,
            // its product id + REAL localized price, so we can see exactly
            // what ASC/RC returns vs the mock preview. Look for
            // "[PriceDiag]" in the Xcode console.
            print("[PriceDiag] ===== RevenueCat offerings dump =====")
            print("[PriceDiag] current offering id = \(offerings.current?.identifier ?? "nil")")
            for (offID, off) in offerings.all.sorted(by: { $0.key < $1.key }) {
                for pkg in off.availablePackages {
                    let pid = pkg.storeProduct.productIdentifier
                    let price = pkg.storeProduct.localizedPriceString
                    print("[PriceDiag]   offering '\(offID)' -> \(pid) = \(price)")
                }
            }
            let hasQuarterly = offerings.all.values.contains { off in
                off.availablePackages.contains { $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.quarterly }
            }
            print("[PriceDiag] app looks for yearly='\(RevenueCatConfig.ProductID.yearly)', discount='\(RevenueCatConfig.ProductID.yearlyDiscount)', quarterly='\(RevenueCatConfig.ProductID.quarterly)'")
            print("[PriceDiag] quarterly resolves? \(hasQuarterly)  (false => paywall shows MOCK $49.99, not a real price)")
            print("[PriceDiag] downsell standard yearly resolved = \(standardYearlyPackage?.storeProduct.localizedPriceString ?? "nil (would hide/mock)")")
            print("[PriceDiag] =====================================")
            #endif
            if offering == nil || discountPackage == nil {
                Analytics.trackException(
                    NSError(domain: "DownsellPaywall", code: 1, userInfo: [
                        NSLocalizedDescriptionKey: "discount offering or product missing"
                    ]),
                    context: "downsell.offerings_missing",
                    properties: [
                        "expected_offering_id": RevenueCatConfig.discountOfferingID,
                        "expected_product_id": RevenueCatConfig.ProductID.yearlyDiscount,
                        "offering_resolved": offering != nil
                    ]
                )
                #if DEBUG
                print("[DownsellPaywall] discount offering or product missing — expected offering '\(RevenueCatConfig.discountOfferingID)' with product '\(RevenueCatConfig.ProductID.yearlyDiscount)'")
                #endif
                offeringsLoadFailed = true
            }
        } catch {
            Analytics.trackException(error, context: "downsell.offerings_load")
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
            // Handoff marker — mirrors PaywallView's purchase_sheet_shown
            // so the downsell funnel (viewed → cta → sheet → completed)
            // is diffable at a glance. purchase_completed still fires off
            // the customerInfoStream with product_id == yearlyDiscount.
            Analytics.track(.downsellPurchaseSheetShown, properties: [
                "product_id": package.storeProduct.productIdentifier
            ])
            // v6 release pass — canonical purchase intent on the
            // recovery surface too, so revenue-per-install math sees
            // every start regardless of which door she bought through.
            PaymentService.shared.lastPurchaseSurface = "downsell_year"
            V6Funnel.track("purchase_started", properties: [
                "product_id": package.storeProduct.productIdentifier,
                "surface": "downsell_year",
            ])
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                V6Funnel.track("purchase_cancelled", properties: [
                    "product_id": package.storeProduct.productIdentifier,
                    "surface": "downsell_year",
                ])
                return
            }
            let isActive = result.customerInfo
                .entitlements[RevenueCatConfig.entitlementID]?.isActive == true
            if isActive {
                Haptics.success()
                onSubscribed()
            } else {
                V6Funnel.track("purchase_failed", properties: [
                    "product_id": package.storeProduct.productIdentifier,
                    "surface": "downsell_year",
                    "reason": "not_activated",
                ])
                errorMessage = "Purchase didn't activate Pro. Try again or contact support@jenifit.app."
            }
        } catch {
            Analytics.trackException(error, context: "downsell.purchase",
                                     properties: ["product_id": package.storeProduct.productIdentifier])
            #if DEBUG
            print("[DownsellPaywall] purchase FAILED: \(error)")
            #endif
            let classified = PaymentService.classifyPurchaseError(error)
            V6Funnel.track(classified.isPending ? "purchase_pending" : "purchase_failed",
                           properties: [
                               "product_id": package.storeProduct.productIdentifier,
                               "surface": "downsell_year",
                               "reason": classified.reason,
                           ])
            errorMessage = classified.message
        }
    }

    private func restore() async {
        PaymentService.shared.suppressPurchaseAnalytics(reason: "downsell_restore")
        do {
            let info = try await Purchases.shared.restorePurchases()
            let isActive = info.entitlements[RevenueCatConfig.entitlementID]?.isActive == true
            if isActive {
                Haptics.success()
                onSubscribed()
            }
        } catch {
            Analytics.trackException(error, context: "downsell.restore")
            #if DEBUG
            print("[DownsellPaywall] restore FAILED: \(error)")
            #endif
        }
    }
}
