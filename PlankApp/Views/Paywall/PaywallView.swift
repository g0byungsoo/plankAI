import SwiftUI

// MARK: - PaywallView
//
// Post-onboarding paywall. Cal AI structural moves (direct verb headline,
// benefit checklist before pricing, trust microcopy above CTA, dynamic
// CTA copy, plain-English auto-renewal disclosure, footer link triplet),
// translated into absmaxxing's voice (calm, confident, terracotta accent
// on warm cream, no preachy or all-caps emphasis).
//
// Phase C scope: standalone view with placeholder pricing strings. Phase D
// wires RevenueCat: replaces the placeholder strings with
// package.storeProduct.localizedPriceString and hooks the CTA to
// Purchases.shared.purchase(package:). The closure plumbing is in place
// so Phase D is mostly substitution, not refactoring.

struct PaywallView: View {
    let onSubscribed: () -> Void
    let onRestore: () -> Void
    let onDismiss: () -> Void

    @AppStorage("focusArea") private var focusArea: String = ""

    @State private var selectedPlan: Plan = .yearly
    @State private var working = false
    @State private var errorMessage: String?
    @State private var legalDoc: LegalDoc?

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

    /// Phase C placeholder pricing. Phase D replaces with
    /// package.storeProduct.localizedPriceString from RevenueCat so
    /// international pricing works automatically.
    private let yearlyPriceText = "$29.99/year"
    private let yearlyPerWeekText = "Just $0.58/week"
    private let weeklyPriceText = "$4.99/week"

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
                    Spacer().frame(height: 40)  // breathing room below close button

                    Text(headline)
                        .font(Typo.title)
                        .foregroundStyle(Palette.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    benefitsSection
                    pricingSection
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

            closeButton
                .padding(.leading, Space.lg)
                .padding(.top, Space.sm)
        }
        .sheet(item: $legalDoc) { doc in
            SafariView(url: doc.url).ignoresSafeArea()
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
        .buttonStyle(CTAButtonStyle())
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

    // MARK: Purchase

    /// Phase C stub. Phase D replaces with the RevenueCat purchase flow:
    ///   try await Purchases.shared.purchase(package: selectedPackage)
    /// On success → onSubscribed(); on userCancelled → silent dismiss;
    /// on failure → friendly errorMessage.
    private func purchase() async {
        working = true
        defer { working = false }
        // Phase D wires this. For now, a brief pulse simulates the call so
        // the loading state can be previewed end-to-end.
        try? await Task.sleep(nanoseconds: 600_000_000)
        onSubscribed()
    }
}
