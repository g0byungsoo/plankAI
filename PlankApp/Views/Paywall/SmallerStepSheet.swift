import SwiftUI
import RevenueCat

// MARK: - SmallerStepSheet
//
// The quarterly-abandon recovery (2026-07-07 keep-wall). She confirmed
// the $24.99 receipt, saw Apple's sheet, and cancelled — the objection
// is the NUMBER, and the honest answer isn't a discount SKU we don't
// sell, it's a smaller step: the weekly product at $5.99, same plan,
// same jeni. De-escalation ($24.99 → $5.99), not a bribe.
//
// Register: calm, zero pressure, leads with "nothing was charged" —
// the defusal the 3-second sheet-cancellers need to keep reading.
// Yearly abandons keep routing to DownsellPaywallView (the discount
// SKU exists for that tier and it's historically the strongest yearly
// path); weekly abandons skip straight to the winback.

struct SmallerStepSheet: View {
    let onSubscribed: () -> Void
    let onDismiss: () -> Void

    @State private var working = false
    @State private var errorMessage: String?
    @State private var offering: Offering?
    @State private var loadFailed = false

    @State private var eyebrowVisible = false
    @State private var headlineVisible = false
    @State private var cardVisible = false
    @State private var ctaVisible = false

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var weeklyPackage: Package? {
        offering?.availablePackages.first {
            $0.storeProduct.productIdentifier == RevenueCatConfig.ProductID.weekly
        }
    }

    private var weeklyPriceText: String? {
        weeklyPackage?.storeProduct.localizedPriceString
    }

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                topBar

                Spacer()

                Text("nothing was charged")
                    .font(Typo.captionTracked)
                    .kerning(1.6)
                    .foregroundStyle(Palette.cocoaTertiary)
                    .opacity(eyebrowVisible ? 1 : 0)

                ItalicAccentText(
                    "start smaller?",
                    italic: ["smaller?"],
                    baseFont: Typo.heroHeadline,
                    italicFont: Typo.heroHeadlineItalic,
                    alignment: .center
                )
                .lineSpacing(Typo.heroHeadlineLineGap)
                .kerning(-0.4)
                .padding(.horizontal, Space.lg)
                .padding(.top, Space.sm)
                .opacity(headlineVisible ? 1 : 0)

                Text("same plan. same jeni. one week at a time.")
                    .font(Typo.teachSub)
                    .lineSpacing(Typo.teachSubLineSpacing)
                    .foregroundStyle(Palette.textSecondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, Space.lg + Space.sm)
                    .padding(.top, Space.sm)
                    .opacity(headlineVisible ? 1 : 0)

                weekCard
                    .padding(.horizontal, Space.lg)
                    .padding(.top, Space.xl)
                    .opacity(cardVisible ? 1 : 0)

                if loadFailed {
                    Text("pricing didn't load. tap the card to try again.")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.top, 10)
                }

                Spacer()
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 10) {
                if let errorMessage {
                    Text(errorMessage)
                        .font(.system(size: 11))
                        .foregroundStyle(Palette.stateBad)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, Space.lg)
                }
                Button {
                    guard !working, weeklyPackage != nil else { return }
                    Haptics.medium()
                    Analytics.track(.smallerStepCtaTapped, properties: [
                        "product_id": weeklyPackage?.storeProduct.productIdentifier
                            ?? RevenueCatConfig.ProductID.weekly
                    ])
                    working = true
                    Task { await purchase() }
                } label: {
                    ZStack {
                        Text(weeklyPriceText.map { "start with a week \u{00B7} \($0)" }
                             ?? "start with a week")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Palette.textInverse)
                            .opacity(working ? 0 : 1)
                        if working { PulsingDots(color: Palette.textInverse) }
                    }
                    .frame(maxWidth: .infinity)
                    .frame(height: 56)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Palette.textPrimary)
                            .opacity(weeklyPackage == nil ? 0.55 : 1)
                    )
                }
                .buttonStyle(PressFeedbackStyle())
                .disabled(working || weeklyPackage == nil)

                Button {
                    Haptics.light()
                    Analytics.track(.smallerStepDismissed, properties: ["via": "not_today"])
                    onDismiss()
                } label: {
                    Text("not today")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.plain)

                if let price = weeklyPriceText {
                    Text("\(price)/week. renews weekly. cancel anytime in settings.")
                        .font(.system(size: 10))
                        .foregroundStyle(Palette.textSecondary.opacity(0.7))
                }
            }
            .padding(.horizontal, Space.lg)
            .padding(.bottom, Space.sm)
            .opacity(ctaVisible ? 1 : 0)
        }
        .task {
            await loadOfferings()
            Analytics.track(.smallerStepViewed, properties: [
                "product_id": weeklyPackage?.storeProduct.productIdentifier
                    ?? RevenueCatConfig.ProductID.weekly,
                "price_resolved": weeklyPackage != nil,
                "load_failed": loadFailed
            ])
            guard !reduceMotion else {
                eyebrowVisible = true; headlineVisible = true
                cardVisible = true; ctaVisible = true
                return
            }
            withAnimation(Motion.entrance) { eyebrowVisible = true }
            try? await Task.sleep(nanoseconds: 160_000_000)
            withAnimation(Motion.entrance) { headlineVisible = true }
            try? await Task.sleep(nanoseconds: 260_000_000)
            withAnimation(Motion.entranceSoft) { cardVisible = true }
            try? await Task.sleep(nanoseconds: 200_000_000)
            withAnimation(Motion.entranceSoft) { ctaVisible = true }
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                Haptics.light()
                Analytics.track(.smallerStepDismissed, properties: ["via": "x"])
                onDismiss()
            } label: {
                ZStack {
                    Color.clear.frame(width: 44, height: 44).contentShape(Rectangle())
                    Image(systemName: "xmark")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(Palette.textSecondary)
                        .frame(width: 32, height: 32)
                        .background(Palette.bgElevated, in: Circle())
                }
            }
            .accessibilityLabel("close")
            .buttonStyle(.plain)
            Spacer()
        }
        .padding(.horizontal, Space.sm)
        .padding(.top, Space.sm)
    }

    /// The week, as a receipt: what today costs, what stays true.
    private var weekCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text("one week")
                    .font(Typo.captionTracked)
                    .kerning(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer()
            }
            .padding(.bottom, 6)
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.66)

            JKReceiptRow(
                lead: "today",
                punch: weeklyPriceText ?? "—",
                showsRule: false
            )
            JKReceiptRow(
                lead: "your plan",
                punch: "stays exactly as built"
            )
            JKReceiptRow(
                lead: "renews",
                punch: "weekly · cancel anytime"
            )
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .shadow(color: Palette.cocoaPrimary.opacity(0.08), radius: 24, x: 0, y: 8)
        .contentShape(Rectangle())
        .onTapGesture {
            if loadFailed { Task { await loadOfferings() } }
        }
    }

    private func loadOfferings() async {
        guard Purchases.isConfigured else {
            loadFailed = true
            return
        }
        loadFailed = false
        do {
            let offerings = try await Purchases.shared.offerings()
            #if DEBUG
            offering = offerings.all[RevenueCatConfig.previewOfferingID] ?? offerings.current
            #else
            offering = offerings.current
            #endif
            if weeklyPackage == nil { loadFailed = true }
        } catch {
            Analytics.trackException(error, context: "smaller_step.offerings_load")
            loadFailed = true
        }
    }

    private func purchase() async {
        guard let package = weeklyPackage else {
            working = false
            return
        }
        errorMessage = nil
        defer { working = false }
        do {
            Analytics.track(.smallerStepSheetShown, properties: [
                "product_id": package.storeProduct.productIdentifier
            ])
            let result = try await Purchases.shared.purchase(package: package)
            if result.userCancelled {
                // Second cancel in a row — she's told us twice. Warm
                // exit only; the winback chain handles the goodbye.
                Analytics.track(.smallerStepDismissed, properties: ["via": "sheet_cancel"])
                onDismiss()
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
            Analytics.trackException(error, context: "smaller_step.purchase")
            errorMessage = "Couldn't complete purchase. Try again in a moment."
        }
    }
}
