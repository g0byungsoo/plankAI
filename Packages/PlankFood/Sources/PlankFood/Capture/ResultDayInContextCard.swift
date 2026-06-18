#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ResultDayInContextCard
//
// v1.0.18 (2026-06-18) — slide 3 of the new post-scan carousel.
// The "is it logged, and where does this leave me" answer that
// nobody else ships well (Cal AI's daily 10-pt health score + MFP's
// remaining-calories — fused with a GLP-1-aware protein-today hero
// when the cohort flag is set). Replaces JeniEvaluationCard.
//
// Layout (1080×1920, cream `bgPrimary` canvas):
//
//   - Eyebrow ("your day so far") + cohort-aware hero numeral.
//     Default cohort: "X cal left" (target - logged total including
//     this scan). GLP-1 cohort: "Yg protein today" (sarcopenia risk
//     mitigation matters more than calorie counts for them).
//   - Trend caption — single italic Fraunces line keyed on the
//     7-day rolling avg ("on pace for your week" / "week's tracking
//     soft" / "protein's coming through").
//   - 4-tile micro-strip (2×2 grid): protein today vs target, fiber
//     today, meals logged today, week deficit projection.
//   - Pull quote — JeniFit voice, italic Fraunces, observational
//     not coachy. ("three meals in. nice rhythm." etc.)

struct ResultDayInContextCard: View {

    let result: CapturedFood
    let targets: NutritionCarousel.MacroTargets
    let glp1Status: String

    var body: some View {
        ZStack {
            Color(red: 0.992, green: 0.965, blue: 0.957)  // bgPrimary cream

            VStack(alignment: .leading, spacing: 36) {
                Spacer().frame(height: 24)
                eyebrowAndHero
                trendCaption
                microStrip
                Spacer(minLength: 0)
                pullQuote
                Spacer().frame(height: 24)
            }
            .padding(.horizontal, 80)
        }
        .frame(width: 1080, height: 1920)
        .clipShape(Rectangle())
    }

    // MARK: - Hero

    @ViewBuilder private var eyebrowAndHero: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("your day so far")
                .font(.custom("DMSans-Medium", size: 28))
                .foregroundStyle(textSecondary)
                .tracking(1.4)
                .textCase(.lowercase)

            heroNumeral
        }
    }

    @ViewBuilder private var heroNumeral: some View {
        if isGlp1Cohort {
            VStack(alignment: .leading, spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 12) {
                    Text("\(proteinToday)")
                        .font(.custom("JeniHeroSerif-Regular", size: 200))
                        .foregroundStyle(textPrimary)
                    Text("g")
                        .font(.custom("DMSans-Medium", size: 56))
                        .foregroundStyle(textSecondary)
                }
                Text("protein today")
                    .font(.custom("DMSans-Medium", size: 32))
                    .foregroundStyle(textSecondary)
                    .offset(y: -8)
            }
        } else {
            VStack(alignment: .leading, spacing: 0) {
                Text("\(kcalLeftRounded)")
                    .font(.custom("JeniHeroSerif-Regular", size: 200))
                    .foregroundStyle(textPrimary)
                Text(kcalLeftLabel)
                    .font(.custom("DMSans-Medium", size: 32))
                    .foregroundStyle(textSecondary)
                    .offset(y: -8)
            }
        }
    }

    // MARK: - Trend caption

    @ViewBuilder private var trendCaption: some View {
        Text(trendText)
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 38))
            .foregroundStyle(textPrimary)
            .lineSpacing(4)
    }

    /// Picks the trend line off whatever signal is most informative.
    /// Order: protein floor concern → kcal pace → default rhythm.
    /// Per the WL expert + GLP-1 doc — observation, not instruction.
    private var trendText: String {
        if proteinToday < 60 && mealsLoggedToday >= 2 {
            return "protein's coming in light today."
        }
        if kcalLeftRounded < 0 {
            return "the day's tracking heavier. tomorrow has room."
        }
        if kcalLeftRounded < (targets.kcal / 5) {
            return "you're close to the day's pace."
        }
        if kcalLeftRounded > (targets.kcal / 2) && mealsLoggedToday <= 1 {
            return "the day's still wide open."
        }
        return "on pace for your week."
    }

    // MARK: - Micro strip (2×2)

    @ViewBuilder private var microStrip: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                tile(
                    label: "protein today",
                    value: "\(proteinToday)g",
                    sublabel: "of \(targets.protein)g"
                )
                tile(
                    label: "fiber today",
                    value: "\(fiberToday)g",
                    sublabel: "of 25g"
                )
            }
            HStack(spacing: 18) {
                tile(
                    label: "meals logged",
                    value: "\(mealsLoggedToday)",
                    sublabel: mealsLoggedToday == 1 ? "today" : "today"
                )
                tile(
                    label: "week pace",
                    value: weekPaceValue,
                    sublabel: weekPaceLabel
                )
            }
        }
    }

    @ViewBuilder
    private func tile(label: String, value: String, sublabel: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(label)
                .font(.custom("DMSans-Medium", size: 22))
                .foregroundStyle(textSecondary)
                .tracking(0.6)
            Text(value)
                .font(.custom("JeniHeroSerif-Regular", size: 80))
                .foregroundStyle(textPrimary)
            Text(sublabel)
                .font(.custom("DMSans-Light", size: 22))
                .foregroundStyle(textSecondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.white.opacity(0.55))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(textPrimary.opacity(0.10), lineWidth: 1)
        )
    }

    // MARK: - Pull quote

    @ViewBuilder private var pullQuote: some View {
        Text(pullQuoteText)
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 32))
            .foregroundStyle(textPrimary)
            .lineSpacing(4)
    }

    /// Observational quote keyed on meals logged + protein status.
    /// Voice locked: lowercase, no labor verbs, no JeniFit-coined verbs.
    private var pullQuoteText: String {
        switch (mealsLoggedToday, proteinToday >= 60) {
        case (0, _): return "first plate of the day."
        case (1, _): return "one logged. you're in motion."
        case (2, true): return "two meals in. protein's holding."
        case (2, false): return "two meals in. lighter on protein."
        case (3, true): return "three meals in. nice rhythm."
        case (3, false): return "three meals in. tomorrow has room for more protein."
        default:
            return mealsLoggedToday >= 4
                ? "a full day, logged."
                : "a quiet day. you're tracking."
        }
    }

    // MARK: - Data sources

    private var isGlp1Cohort: Bool {
        let normalized = glp1Status.lowercased()
        return normalized.contains("on_glp1")
            || normalized == "on"
            || normalized == "post"
            || normalized.contains("currently")
            || normalized.contains("recently")
    }

    private var scanKcal: Int {
        let raw: Double = result.totalKcal
            ?? Double((result.kcalLow ?? 0) + (result.kcalHigh ?? 0)) / 2
        return Int(raw.rounded())
    }

    private var scanProtein: Int {
        Int(result.items.compactMap { $0.proteinG }.reduce(0, +).rounded())
    }

    private var scanFiber: Int {
        Int(result.items.compactMap { $0.fiberG }.reduce(0, +).rounded())
    }

    private var todayLogged: FoodLogPersister.TodayMacros {
        FoodLogPersister.todayMacros()
    }

    /// Includes the in-flight scan so the user sees their day after
    /// this meal is logged. Per the founder's "utility" call — show
    /// the post-log world, not the pre-log world.
    private var kcalToday: Int { Int(todayLogged.kcal.rounded()) + scanKcal }
    private var proteinToday: Int { Int(todayLogged.protein.rounded()) + scanProtein }
    private var fiberToday: Int { Int(todayLogged.fiber.rounded()) + scanFiber }

    private var kcalLeftRounded: Int {
        let raw = targets.kcal - kcalToday
        return Int((Double(raw) / 5).rounded()) * 5  // 5-cal increments
    }

    private var kcalLeftLabel: String {
        kcalLeftRounded < 0 ? "calories over" : "calories left today"
    }

    private var mealsLoggedToday: Int {
        FoodLogPersister.todayLogCount() + 1
    }

    private var weekDeficitProjectionKcal: Int {
        // Rough projection: today's pace × 7 - week target.
        // Negative number = deficit (good for WL); positive = surplus.
        let dayTarget = Double(targets.kcal)
        let pace = Double(kcalToday)
        let projected = pace * 7
        let target = dayTarget * 7
        return Int(projected - target)
    }

    private var weekPaceValue: String {
        let delta = weekDeficitProjectionKcal
        if delta < 0 {
            // Display deficit as a positive deficit number.
            return "−\(abs(delta) / 100)00"
        }
        return "+\(delta / 100)00"
    }

    private var weekPaceLabel: String {
        weekDeficitProjectionKcal < 0 ? "cal under target" : "cal over target"
    }

    // MARK: - Palette

    private var textPrimary: Color { Color(red: 0.239, green: 0.165, blue: 0.165) }
    private var textSecondary: Color { Color(red: 0.482, green: 0.349, blue: 0.349) }
}

#endif  // canImport(UIKit)
