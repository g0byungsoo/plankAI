#if canImport(UIKit)
import SwiftUI

// MARK: - ResultDetailCard  (carousel slide 2 — "a note from jeni")
//
// The explanatory + emotional beat. A full cream "page" (not a card on
// the photo) so the carousel reads photo → page → photo, a magazine
// spread rhythm. Native device points. Scatter-free per the brand rule
// (stickers are reserved for welcome / plan-reveal / graduation).
//
// Content comes from ResultDetailCopy — a pure, anti-shame, deterministic
// engine reading only measured fields + real user context. This view is
// presentation only; it does no nutrition math.
//
//   eyebrow        "a note from jeni"
//   jeni note      «…» pull-quote, rose left-rule — the centerpiece
//   ───────
//   how it fits    one-line day-fit read (module A)
//   detail rows    protein-today (sage progress) · balance · density · timing
//   consideration  one calm margin-note (never red), conditional
//   provenance     tiny honesty footnote

struct ResultDetailCard: View {

    let result: CapturedFood
    let mealLabel: String
    let dishName: String
    var loggedAt: Date = Date()

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("onboardingCurrentWeightKg") private var onboardingCurrentWeightKg: Double = 0
    @AppStorage("onboarding_glp1_status") private var glp1Status: String = ""
    @AppStorage("foodDailyTarget") private var foodDailyTarget: Double = 0

    @State private var revealed: Int = 0

    private var copy: ResultDetailCopy {
        ResultDetailCopy(food: result, ctx: context)
    }

    private var context: ResultDetailContext {
        ResultDetailContext(
            proteinTargetG: proteinTargetG,
            todayLoggedProtein: Int(FoodLogPersister.todayMacros().protein.rounded()),
            kcalTarget: Int(foodDailyTarget),
            isGlp1: isGlp1Cohort,
            hour: Calendar.current.component(.hour, from: loggedAt)
        )
    }

    private var proteinTargetG: Int {
        let kg = onboardingCurrentWeightKg
        let raw = kg > 30 ? 1.0 * kg : 0
        return max(70, min(150, Int(raw.rounded())))
    }

    private var isGlp1Cohort: Bool {
        let n = glp1Status.lowercased()
        return n.contains("current") || n.contains("on_glp1") || n == "on"
            || n == "post" || n.contains("triedoff") || n.contains("tried_off")
    }

    // MARK: Body

    var body: some View {
        GeometryReader { geo in
        // Clamp to the real screen width (the paging slot can over-propose).
        let w = min(geo.size.width, UIScreen.main.bounds.width)
        ZStack(alignment: .top) {
            // Transparent — the frozen food photo behind the carousel shows
            // around the floating card, so the card stays smaller than the
            // photo (matches slide 1's card-on-photo register).
            Color.clear

            card
                .frame(width: w - 36)
                .padding(.top, 46)
        }
        // Center within the VISIBLE screen width (the paging slot can be
        // proposed wider than the screen); pin to the slot's leading edge.
        .frame(width: w)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
        .onAppear(perform: startCascade)
    }

    /// The floating cream card — sized to its content so the food photo
    /// shows above and below. Same chrome register as slide 1.
    private var card: some View {
        VStack(alignment: .leading, spacing: 15) {
            eyebrow.reveal(0, revealed)
            jeniNote.reveal(1, revealed)
            rule.reveal(2, revealed)
            fitsLabel.reveal(2, revealed)
            dayFitLine.reveal(3, revealed)
            detailRows.reveal(4, revealed)
            if let c = copy.consideration {
                considerationView(c).reveal(5, revealed)
            }
            if let p = copy.provenance {
                Text(p)
                    .font(.custom("DMSans-Regular", size: 11))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.75))
                    .reveal(6, revealed)
            }
        }
        .padding(.horizontal, 22)
        .padding(.vertical, 22)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(red: 1.0, green: 0.992, blue: 0.984),
                            Color(red: 0.988, green: 0.957, blue: 0.945),
                        ],
                        startPoint: .top, endPoint: .bottom
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(FoodTheme.textPrimary.opacity(0.07), lineWidth: 0.75)
        )
        .shadow(color: Color(red: 0.36, green: 0.20, blue: 0.18).opacity(0.10), radius: 16, x: 0, y: 6)
    }

    // MARK: Eyebrow

    private var eyebrow: some View {
        Text("a note from jeni")
            .font(.custom("JeniHeroSerif-Italic", size: 18))
            .foregroundStyle(FoodTheme.accent)
    }

    // MARK: Jeni note (centerpiece)

    private var jeniNote: some View {
        let n = copy.jeniNote
        return HStack(alignment: .top, spacing: 14) {
            Capsule()
                .fill(FoodTheme.accent.opacity(0.85))
                .frame(width: 2.5)
            (Text("\u{00AB}")
                .font(.custom("JeniHeroSerif-Regular", size: 21))
                .foregroundStyle(FoodTheme.accent.opacity(0.45))
            + Text(n.prefix)
                .font(.custom("JeniHeroSerif-Regular", size: 20))
            + Text(n.punch)
                .font(.custom("JeniHeroSerif-Italic", size: 20))
            + Text(n.suffix)
                .font(.custom("JeniHeroSerif-Regular", size: 20))
            + Text("\u{00BB}")
                .font(.custom("JeniHeroSerif-Regular", size: 21))
                .foregroundStyle(FoodTheme.accent.opacity(0.45)))
                .foregroundStyle(FoodTheme.textPrimary)
                .lineSpacing(3)
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Day-fit

    private var fitsLabel: some View {
        Text("how it fits today")
            .font(.custom("DMSans-Regular", size: 11))
            .tracking(0.8)
            .textCase(.uppercase)
            .foregroundStyle(FoodTheme.textSecondary.opacity(0.7))
    }

    private var dayFitLine: some View {
        let l = copy.dayFit
        return (Text(l.prefix)
            .font(.custom("JeniHeroSerif-Regular", size: 17))
        + Text(l.punch)
            .font(.custom("JeniHeroSerif-Italic", size: 17))
        + Text(l.suffix)
            .font(.custom("JeniHeroSerif-Regular", size: 17)))
            .foregroundStyle(FoodTheme.textPrimary)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    // MARK: Detail rows

    private var detailRows: some View {
        let rows = copy.details
        return VStack(alignment: .leading, spacing: 0) {
            ForEach(Array(rows.enumerated()), id: \.offset) { idx, row in
                VStack(alignment: .leading, spacing: 7) {
                    HStack(alignment: .firstTextBaseline) {
                        Text(row.label)
                            .font(.custom("DMSans-Regular", size: 14))
                            .foregroundStyle(FoodTheme.textSecondary)
                        Spacer(minLength: 8)
                        Text(row.value)
                            .font(.custom("DMSans-Medium", size: 15))
                            .foregroundStyle(FoodTheme.textPrimary)
                            .monospacedDigit()
                    }
                    if let p = row.progress {
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                Capsule().fill(FoodTheme.textPrimary.opacity(0.08))
                                Capsule()
                                    .fill(FoodTheme.stateGood.opacity(0.8))
                                    .frame(width: max(4, geo.size.width * p))
                            }
                        }
                        .frame(height: 3)
                    }
                }
                .padding(.vertical, 11)
                if idx < rows.count - 1 {
                    Rectangle()
                        .fill(FoodTheme.textPrimary.opacity(0.10))
                        .frame(height: 0.5)
                }
            }
        }
    }

    // MARK: Consideration (calm margin-note, never red)

    private func considerationView(_ c: Consideration) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Capsule()
                .fill(FoodTheme.accentSubtle)
                .frame(width: 2)
            VStack(alignment: .leading, spacing: 3) {
                (Text(c.ackPrefix)
                    .font(.custom("DMSans-Regular", size: 13))
                + Text(c.ackPunch)
                    .font(.custom("JeniHeroSerif-Italic", size: 14))
                + Text(c.ackSuffix)
                    .font(.custom("DMSans-Regular", size: 13)))
                    .foregroundStyle(FoodTheme.textPrimary)
                Text(c.action)
                    .font(.custom("DMSans-Regular", size: 12))
                    .foregroundStyle(FoodTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
    }

    // MARK: Hairline

    private var rule: some View {
        Rectangle()
            .fill(FoodTheme.textPrimary.opacity(0.10))
            .frame(height: 0.5)
    }

    // MARK: Cascade

    private func startCascade() {
        if reduceMotion { revealed = 7; return }
        revealed = 0
        for i in 0...6 {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.09 * Double(i)) {
                withAnimation(.easeOut(duration: 0.45)) { revealed = max(revealed, i) }
            }
        }
    }
}

// MARK: - Reveal modifier (staggered fade + rise)

private extension View {
    func reveal(_ step: Int, _ revealed: Int) -> some View {
        modifier(RevealStep(step: step, revealed: revealed))
    }
}

private struct RevealStep: ViewModifier {
    let step: Int
    let revealed: Int
    func body(content: Content) -> some View {
        content
            .opacity(revealed >= step ? 1 : 0)
            .offset(y: revealed >= step ? 0 : 8)
    }
}
#endif
