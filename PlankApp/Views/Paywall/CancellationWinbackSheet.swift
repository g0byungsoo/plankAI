import SwiftUI

// MARK: - CancellationWinbackSheet
//
// The final exit beat (2026-07-08 rebuild). Fires LAST in the recovery
// ladder — after she has already declined the discounted year AND the
// $5.99 smaller step. The old version was an abstract identity line
// ("the next you is still here") on an empty canvas whose message was
// "no pressure, we're here" — a polite surrender, not a reason to
// reconsider, and barren in the (common) no-personalization fallback.
//
// The rebuild is a LOSS frame around a concrete object: her plan,
// built and SAVED. She spent minutes building it; leaving means
// walking away from her goal, her date, and (once unlocked) her held
// discount — but re-entry is frictionless, which is exactly what makes
// coming back easy. The plan card is the same bgElevated receipt
// grammar as the wall + downsell, so the whole recovery chain reads as
// one premium system instead of a bare modal.
//
// Every value is her own data (entered weights → goal + ProjectionMath
// date; downsellShownOnce → the saved-discount row). Rows omit
// themselves when the data isn't there; the card always carries at
// least the "built + waiting" row so it's never empty.
//
// Voice locked: lowercase, italic-Fraunces punch, dusty-rose text
// hearts (U+FE0E), no scarcity, no scatter (recovery ≠ earned beat).

struct CancellationWinbackSheet: View {

    var onStayOpen: () -> Void
    var onLeave: () -> Void

    @AppStorage("userName")                  private var userName: String = ""
    @AppStorage("onb_v5_name")               private var v5Name: String = ""
    @AppStorage("onboardingCurrentWeightKg") private var storedCurrentKg: Double = 0
    @AppStorage("onboardingGoalWeightKg")    private var storedGoalKg: Double = 0
    @AppStorage("onb_v5_weight_kg")          private var v5CurrentKg: Double = 0
    @AppStorage("onb_v5_goal_kg")            private var v5GoalKg: Double = 0
    @AppStorage(ProjectionMath.paceDefaultsKey) private var paceChoice: String = ""
    /// Whether the discounted year has been unlocked this install — if
    /// so, "your best price · saved" becomes the sharpest re-entry row.
    @AppStorage("downsellShownOnce")         private var discountUnlocked: Bool = false

    @State private var hasAppeared = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            Palette.bgPrimary.ignoresSafeArea()

            VStack(spacing: 0) {
                // Centered composition — the plan card is the object; it
                // sits in the optical middle, not pinned to a barren top.
                Spacer(minLength: 0)

                VStack(spacing: 20) {
                    eyebrow
                    heroLine
                    planCard
                    subline
                }
                .padding(.horizontal, 24)
                .opacity(hasAppeared ? 1 : 0)
                .offset(y: hasAppeared ? 0 : 12)

                Spacer(minLength: 0)

                VStack(spacing: 8) {
                    stayCTA
                    leaveCTA
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 20)
                .opacity(hasAppeared ? 1 : 0)
            }
        }
        .onAppear {
            Haptics.soft()
            if reduceMotion {
                hasAppeared = true
            } else {
                withAnimation(.spring(response: 0.55, dampingFraction: 0.86).delay(0.08)) {
                    hasAppeared = true
                }
            }
        }
    }

    // MARK: - Data

    private var firstName: String {
        let raw = userName.isEmpty ? v5Name : userName
        return raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: " ").first.map { String($0).lowercased() } ?? ""
    }
    private var currentKg: Double { v5CurrentKg > 0 ? v5CurrentKg : storedCurrentKg }
    private var goalKg: Double { v5GoalKg > 0 ? v5GoalKg : storedGoalKg }
    private var hasLossGoal: Bool { goalKg > 0 && currentKg > goalKg }

    /// "151 lb" — her entered goal, in her display unit. nil unless a
    /// real loss goal is set.
    private var goalPunch: String? {
        guard hasLossGoal else { return nil }
        let unit = WeightUnit.current
        let v = unit.display(fromKg: goalKg)
        let s = (v == v.rounded()) ? String(format: "%.0f", v) : String(format: "%.1f", v)
        return "\(s) \(unit.label)"
    }

    /// "oct 13" — projected arrival via the canonical ProjectionMath, so
    /// it matches every other surface. nil when no loss goal.
    private var arrivalDate: String? {
        guard hasLossGoal else { return nil }
        return ProjectionMath.formattedShortDate(
            currentKg: currentKg, goalKg: goalKg, paceKey: paceChoice
        )
    }

    // MARK: - Eyebrow

    private var eyebrow: some View {
        HStack(spacing: 8) {
            Circle().fill(Palette.accent).frame(width: 5, height: 5)
            Text("before you go")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .tracking(0.8)
                .textCase(.uppercase)
        }
    }

    // MARK: - Hero — concrete, loss-framed ("it's all saved")

    private var heroLine: some View {
        ItalicAccentText(
            firstName.isEmpty ? "your plan is saved." : "\(firstName), it's all saved.",
            italic: ["saved."],
            baseFont: Typo.heroHeadline,
            italicFont: Typo.heroHeadlineItalic,
            color: Palette.textPrimary,
            alignment: .center
        )
        .lineSpacing(Typo.heroHeadlineLineGap)
        .kerning(-0.4)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - The plan card (the object she'd be leaving behind)

    private var planCard: some View {
        VStack(spacing: 0) {
            HStack(alignment: .firstTextBaseline) {
                Text(firstName.isEmpty ? "your plan" : "\(firstName)'s plan")
                    .font(Typo.captionTracked)
                    .kerning(1.6)
                    .textCase(.uppercase)
                    .foregroundStyle(Palette.cocoaTertiary)
                Spacer(minLength: 12)
                ItalicAccentText(
                    "waiting",
                    italic: ["waiting"],
                    baseFont: .custom("JeniHeroSerif-Regular", size: 15),
                    italicFont: .custom("JeniHeroSerif-Italic", size: 15),
                    color: Palette.accent,
                    alignment: .trailing
                )
            }
            .padding(.bottom, 8)
            Rectangle().fill(Palette.hairlineCocoa).frame(height: 0.66)

            planRows
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 16)
        .background(
            RoundedRectangle(cornerRadius: Radius.lg, style: .continuous)
                .fill(Palette.bgElevated)
        )
        .shadow(color: Palette.cocoaPrimary.opacity(0.08), radius: 24, x: 0, y: 8)
        .accessibilityElement(children: .combine)
    }

    /// Most-concrete-available rows: goal + date when she set a loss
    /// goal, the saved discount when unlocked, and always at least the
    /// "built + waiting" line so the card is never thin.
    @ViewBuilder
    private var planRows: some View {
        let showGoal = goalPunch != nil
        let showDate = arrivalDate != nil
        let showDiscount = discountUnlocked

        if let goal = goalPunch {
            JKReceiptRow(lead: "your goal", punch: goal, showsRule: false)
        }
        if let date = arrivalDate {
            JKReceiptRow(lead: "on track for", punch: date,
                         punchItalic: [date], showsRule: showGoal)
        }
        if showDiscount {
            JKReceiptRow(lead: "your best price", punch: "saved",
                         punchItalic: ["saved"], showsRule: showGoal || showDate)
        }
        if !showGoal && !showDate && !showDiscount {
            // No goal + no discount (uncommon — goal weight is a core
            // onboarding step). "everything" avoids echoing the
            // "your plan" masthead while still filling the card.
            JKReceiptRow(lead: "everything", punch: "built + waiting",
                         punchItalic: ["waiting"], showsRule: false)
        }
    }

    // MARK: - Subline — gentle loss frame

    private var subline: some View {
        Text("nothing's gone. it's exactly where you left it, whenever you're ready.")
            .font(.custom("Fraunces72pt-Regular", size: 14))
            .foregroundStyle(Palette.textSecondary)
        .multilineTextAlignment(.center)
        .lineSpacing(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: - CTAs

    private var stayCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .rigid).impactOccurred(intensity: 0.7)
            Analytics.track(.paywallDismissAttempted, properties: [
                "winback_outcome": "stayed",
                "placement": "cancellation_winback"
            ])
            onStayOpen()
        } label: {
            Text("keep going")
                .font(.custom("DMSans-SemiBold", size: 15))
                .foregroundStyle(Palette.bgPrimary)
                .frame(maxWidth: .infinity)
                .frame(height: 56)
                .background(Capsule().fill(Palette.textPrimary))
        }
        .buttonStyle(.plain)
    }

    private var leaveCTA: some View {
        Button {
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
            Analytics.track(.paywallDismissAttempted, properties: [
                "winback_outcome": "left",
                "placement": "cancellation_winback"
            ])
            onLeave()
        } label: {
            Text("not today")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Palette.textSecondary)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
    }
}
