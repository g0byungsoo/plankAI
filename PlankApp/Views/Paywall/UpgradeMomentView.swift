import SwiftUI
import RevenueCat

// MARK: - UpgradeMomentView (v6.5, 2026-07-17)
//
// The day-6 weekly→quarterly moment — the LTV answer to the
// weekly-first cohort (docs/app_v6/03_CONVERSION.md, founder memo
// #3). The data said the weekly buyer pays a 2.4x premium for the
// right to quit; after her first kept week the premium has done its
// job. ONE quiet, dismissable offer: her week's receipt on top
// (proof from her own data), the quarter's per-week price beneath,
// Apple handles the switch. Presented at most once per install
// (TodayView owns the flag + preflight); "stay weekly" is a
// first-class exit — this is an offer, never a wall.
//
// Register: direct coach language. Every number is a live StoreKit
// price or arithmetic on one (no fabricated stats — brand law).
//
// QA: --uitest-upgrade-moment presents it on Today with mock
// pricing (weekly $7.99 / quarterly $25.99 → $1.99/wk, save 75%).

struct UpgradeMomentView: View {
    let programDay: Int
    /// Her first week's receipt rows, computed by the presenter from
    /// stores it already holds (provenance-only; empty rows dropped).
    let receipt: [(String, String)]
    let onDone: () -> Void

    @State private var offering: Offering?
    @State private var offeringsLoadFailed = false
    @State private var working = false
    @State private var errorMessage: String?

    @State private var eyebrowVisible = false
    @State private var headlineVisible = false
    @State private var cardVisible = false
    @State private var ctaVisible = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isQAPreview: Bool {
        #if DEBUG
        ProcessInfo.processInfo.arguments.contains("--uitest-upgrade-moment")
        #else
        false
        #endif
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Spacer()
                    Button {
                        Analytics.track(.upgradeMomentDismissed, properties: ["via": "x"])
                        onDone()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundStyle(Palette.cocoaSecondary)
                            .tappableArea(44)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("not now")
                }
                .padding(.top, Space.md)

                Spacer(minLength: 0)

                Text("week one, kept")
                    .font(Typo.captionTracked)
                    .kerning(1.98)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .opacity(eyebrowVisible ? 1 : 0)

                ItalicAccentText(
                    headlineText.0,
                    italic: headlineText.1,
                    baseFont: .custom("JeniHeroSerif-Regular", size: 30, relativeTo: .title),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 30, relativeTo: .title),
                    color: Palette.textPrimary,
                    alignment: .leading
                )
                .lineSpacing(-2)
                .padding(.top, 12)
                .fixedSize(horizontal: false, vertical: true)
                .opacity(headlineVisible ? 1 : 0)

                if !receipt.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(receipt.enumerated()), id: \.offset) { idx, row in
                            if idx > 0 {
                                Rectangle()
                                    .fill(Palette.hairlineCocoa)
                                    .frame(height: 0.66)
                            }
                            HStack(alignment: .firstTextBaseline) {
                                Text(row.0)
                                    .font(Typo.caption)
                                    .foregroundStyle(Palette.textSecondary)
                                Spacer(minLength: 12)
                                Text(row.1)
                                    .font(.custom("DMSans-Medium", size: 13))
                                    .monospacedDigit()
                                    .foregroundStyle(Palette.textPrimary)
                            }
                            .padding(.vertical, 9)
                        }
                    }
                    .padding(.top, Space.lg)
                    .opacity(headlineVisible ? 1 : 0)
                }

                Spacer(minLength: Space.lg)

                if offeringsLoadFailed && !isQAPreview {
                    Text("couldn't load pricing right now. the offer stays on your wall.")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .opacity(cardVisible ? 1 : 0)
                } else {
                    quarterCard
                        .opacity(cardVisible ? 1 : 0)
                }

                VStack(spacing: 10) {
                    if let errorMessage {
                        Text(errorMessage)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.textSecondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                    }

                    Button {
                        Analytics.track(.upgradeMomentCtaTapped, properties: [
                            "day": programDay
                        ])
                        Task { await purchase() }
                    } label: {
                        HStack(spacing: 8) {
                            if working { ProgressView().tint(Palette.bgPrimary) }
                            // 3.1.2(c) — the button names the charge,
                            // the same grammar the wall's CTA uses.
                            Text(quarterlyPriceText.map { "switch to the quarter \u{00B7} \($0) today" }
                                 ?? "switch to the quarter")
                                .font(.custom("DMSans-SemiBold", size: 16))
                        }
                        .foregroundStyle(Palette.bgPrimary)
                        .frame(maxWidth: .infinity)
                        .frame(height: 54)
                        .background(
                            RoundedRectangle(cornerRadius: 27, style: .continuous)
                                .fill(Palette.bgInverse)
                        )
                    }
                    .buttonStyle(JKPress())
                    .disabled(working || (quarterlyPackage == nil && !isQAPreview))

                    Text("apple confirms the switch and handles the timing · nothing to cancel yourself")
                        .font(.custom("DMSans-Regular", size: 11))
                        .foregroundStyle(Palette.cocoaTertiary)
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Button {
                        Analytics.track(.upgradeMomentDismissed, properties: ["via": "stay_weekly"])
                        onDone()
                    } label: {
                        Text("stay weekly")
                            .font(.custom("DMSans-Medium", size: 14))
                            .foregroundStyle(Palette.cocoaSecondary)
                            .tappableArea(44)
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 2)
                }
                .padding(.top, Space.lg)
                .opacity(ctaVisible ? 1 : 0)
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.lg)
        }
        .task {
            await loadOfferings()
            Analytics.track(.upgradeMomentViewed, properties: [
                "day": programDay,
                "price_resolved": quarterlyPackage != nil || isQAPreview,
                "save_pct": savePct ?? 0
            ])
            reveal()
        }
    }

    // MARK: The quarter, as one anchor card

    /// 2026-08-20, App Store 3.1.2(c): this used to read "keep going
    /// for $1.99 a week." — a CALCULATED rate in the most conspicuous
    /// element on the screen, while the amount actually charged sat at
    /// 11pt inside the card. The headline carries no price now; the
    /// card states the charge, dominant, and the weekly equivalent
    /// beneath it.
    private var headlineText: (String, [String]) {
        ("keep going for less each week.", ["less"])
    }

    @ViewBuilder
    private var quarterCard: some View {
        HStack(alignment: .center, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text("the quarter")
                    .font(.custom("DMSans-SemiBold", size: 15))
                    .foregroundStyle(Palette.textPrimary)
                    .fixedSize()
                if let pct = savePct {
                    Text("save \(pct)% vs weekly")
                        .font(.custom("DMSans-Medium", size: 10))
                        .lineLimit(1)
                        .fixedSize()
                        .foregroundStyle(Palette.bgPrimary)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 3)
                        .background(Capsule().fill(Palette.bgInverse))
                        .padding(.bottom, 1)
                }
                Text("same plan, same jeni")
                    .font(Typo.caption)
                    .foregroundStyle(Palette.textSecondary)
                    .fixedSize()
                Text("renews quarterly · cancel anytime")
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(Palette.cocoaTertiary)
            }
            .layoutPriority(1)
            Spacer(minLength: 8)
            // 3.1.2(c) — the charge leads, the calculated weekly rate
            // follows. Same SubscriptionPriceBlock the wall's tier rows
            // render from, so both surfaces obey one rule.
            VStack(alignment: .trailing, spacing: 3) {
                if let block = priceBlock {
                    HStack(alignment: .firstTextBaseline, spacing: 2) {
                        Text(block.dominant.text)
                            .font(.custom("Fraunces72pt-SemiBold", size: block.dominant.pointSize))
                            .monospacedDigit()
                            .foregroundStyle(Palette.textPrimary)
                        Text(block.periodSuffix)
                            .font(.custom("DMSans-Medium", size: 12))
                            .foregroundStyle(Palette.textSecondary)
                    }
                    .fixedSize()
                    if let sub = block.subordinate {
                        Text(sub.text)
                            .font(.custom("DMSans-Regular", size: sub.pointSize))
                            .monospacedDigit()
                            .foregroundStyle(Palette.cocoaTertiary)
                    }
                } else {
                    Text("—")
                        .font(.custom("Fraunces72pt-SemiBold", size: 24))
                        .foregroundStyle(Palette.textPrimary)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Palette.bgInverse, lineWidth: 2)
        )
    }

    // MARK: Pricing (live StoreKit or QA mock — never invented)

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

    private var quarterlyPriceText: String? {
        if let pkg = quarterlyPackage { return pkg.storeProduct.localizedPriceString }
        return isQAPreview ? "$25.99" : nil
    }

    /// The 3.1.2(c) pricing block: the quarter's charge, dominant,
    /// with its weekly equivalent subordinate. nil until StoreKit
    /// resolves — the card then shows a dash, never a made-up price.
    private var priceBlock: SubscriptionPriceBlock? {
        guard let billed = quarterlyPriceText else { return nil }
        return .make(
            billedAmount: billed,
            period: .quarter,
            calculatedWeekly: calculatedWeeklyRate,
            // 23 + 1 = the 24pt this card has always drawn.
            basePointSize: 23
        )
    }

    /// The quarter told in the weekly plan's own currency ("$1.99") —
    /// SUBORDINATE information, never the lead numeral (3.1.2(c)).
    private var calculatedWeeklyRate: String? {
        if let pkg = quarterlyPackage {
            let perWeek = pkg.storeProduct.price / 13
            if let formatter = pkg.storeProduct.priceFormatter,
               let text = formatter.string(from: perWeek as NSDecimalNumber) {
                return text
            }
            return String(format: "$%.2f", NSDecimalNumber(decimal: perWeek).doubleValue)
        }
        return isQAPreview ? "$1.99" : nil
    }

    /// Savings vs the VISIBLE weekly price — arithmetic on two live
    /// prices, or nil (badge hides) when either is missing.
    private var savePct: Int? {
        if let q = quarterlyPackage, let w = weeklyPackage {
            let qWeekly = NSDecimalNumber(decimal: q.storeProduct.price).doubleValue / 13
            let weekly = NSDecimalNumber(decimal: w.storeProduct.price).doubleValue
            guard weekly > 0, qWeekly < weekly else { return nil }
            return Int(((1 - qWeekly / weekly) * 100).rounded())
        }
        return isQAPreview ? 75 : nil
    }

    // MARK: Offerings + purchase

    private func loadOfferings() async {
        guard Purchases.isConfigured else {
            offeringsLoadFailed = true
            return
        }
        do {
            let offerings = try await Purchases.shared.offerings()
            #if DEBUG
            offering = offerings.all[RevenueCatConfig.previewOfferingID] ?? offerings.current
            #else
            offering = offerings.current
            #endif
            if quarterlyPackage == nil && !isQAPreview {
                offeringsLoadFailed = true
            }
        } catch {
            Analytics.trackException(error, context: "upgrade_moment.offerings_load")
            offeringsLoadFailed = true
        }
    }

    private func purchase() async {
        guard !working else { return }
        guard let package = quarterlyPackage else {
            errorMessage = isQAPreview
                ? nil
                : "couldn't load pricing. check your connection and try again."
            return
        }
        working = true
        errorMessage = nil
        defer { working = false }
        do {
            Analytics.track(.upgradeMomentSheetShown, properties: [
                "product_id": package.storeProduct.productIdentifier
            ])
            // Release audit 2026-08-08 — this surface fired no canonical
            // purchase events at all (the day-6 upgrade was invisible to
            // revenue funnels), and its catch treated Ask-to-Buy pending
            // as failure, inviting a re-tap against a pending transaction.
            // Now the full started/cancelled/pending/failed set, like
            // every sibling surface.
            PaymentService.shared.lastPurchaseSurface = "upgrade_moment"
            V6Funnel.track("purchase_started", properties: [
                "product_id": package.storeProduct.productIdentifier,
                "surface": "upgrade_moment",
            ])
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                V6Funnel.track("purchase_cancelled", properties: [
                    "product_id": package.storeProduct.productIdentifier,
                    "surface": "upgrade_moment",
                ])
                return
            }
            let isActive = result.customerInfo
                .entitlements[RevenueCatConfig.entitlementID]?.isActive == true
            if isActive {
                Haptics.success()
                onDone()
            } else {
                V6Funnel.track("purchase_failed", properties: [
                    "product_id": package.storeProduct.productIdentifier,
                    "surface": "upgrade_moment",
                    "reason": "not_activated",
                ])
                errorMessage = "the switch didn't go through. try again or contact support@jenifit.app."
            }
        } catch {
            Analytics.trackException(error, context: "upgrade_moment.purchase",
                                     properties: ["product_id": package.storeProduct.productIdentifier])
            let classified = PaymentService.classifyPurchaseError(error)
            V6Funnel.track(classified.isPending ? "purchase_pending" : "purchase_failed",
                           properties: [
                               "product_id": package.storeProduct.productIdentifier,
                               "surface": "upgrade_moment",
                               "reason": classified.reason,
                           ])
            errorMessage = classified.message
        }
    }

    // MARK: Reveal

    private func reveal() {
        guard !reduceMotion else {
            eyebrowVisible = true; headlineVisible = true
            cardVisible = true; ctaVisible = true
            return
        }
        withAnimation(.easeOut(duration: 0.4).delay(0.10)) { eyebrowVisible = true }
        withAnimation(.easeOut(duration: 0.45).delay(0.28)) { headlineVisible = true }
        withAnimation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.55)) { cardVisible = true }
        withAnimation(.easeOut(duration: 0.35).delay(0.80)) { ctaVisible = true }
    }
}
