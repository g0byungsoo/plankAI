#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ResultDayInContextCard
//
// v1.0.19 (2026-06-18) — slide 3 of the new post-scan carousel.
// Locked decisions from the panel synthesis:
//
//   - Keep 4 SEPARATE tiles (founder: skip the crosshair card).
//   - Replace the trend caption with the SATIETY PREDICTION line
//     ("should hold you about 4 hours") — the snap-bound observation
//     no competitor owns, the magical-moment insight.
//   - Apply her75 typography swaps: hairline-rule eyebrow, inline
//     italic hero ("1,400 *left*"), guillemet «…» pull-quote with
//     italic punch on a single word.
//   - GLP-1 cohort still flips the hero to protein-today.
//
// Layout (1080×1920, cream `bgPrimary`):
//
//   - Eyebrow with hairline rule: `your day so *far*` + rule + day
//     summary timestamp on the right
//   - Hero numeral via CountUpNumber + " left" italic suffix (or
//     " today" for GLP-1 protein variant)
//   - Satiety prediction line in italic Fraunces — snap-bound,
//     replaces the prior trend caption
//   - 4 separate scrapbook-chrome tiles in a 2×2 layout
//   - Guillemet pull-quote at the bottom with italic punch word

struct ResultDayInContextCard: View {

    let result: CapturedFood
    let targets: NutritionCarousel.MacroTargets
    let glp1Status: String

    var body: some View {
        ZStack {
            Color(red: 0.992, green: 0.965, blue: 0.957)

            VStack(alignment: .leading, spacing: 40) {
                eyebrowRule
                heroNumeral
                satietyLine
                tileGrid
                pullQuote
            }
            .padding(.horizontal, 80)
            .padding(.top, 130)
            .padding(.bottom, 100)
        }
        .frame(width: 1080, height: 1920)
        .clipShape(Rectangle())
    }

    // MARK: - Eyebrow with hairline rule

    @ViewBuilder private var eyebrowRule: some View {
        HStack(alignment: .center, spacing: 14) {
            (
                Text("your day so ")
                    .font(.custom("DMSans-Medium", size: 24))
                + Text("far")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 26))
            )
            .foregroundStyle(textSecondary)
            .kerning(0.4)

            Rectangle()
                .fill(textPrimary.opacity(0.22))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)

            Text(currentTimeLabel)
                .font(.custom("DMSans-Medium", size: 22))
                .foregroundStyle(textSecondary)
                .kerning(0.6)
        }
    }

    private var currentTimeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: Date()).lowercased()
    }

    // MARK: - Hero numeral + inline italic suffix

    @ViewBuilder private var heroNumeral: some View {
        if isGlp1Cohort {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                CountUpNumber(
                    target: proteinToday,
                    fontName: "JeniHeroSerif-Regular",
                    italicFontName: "JeniHeroSerif-Italic",
                    size: 200,
                    color: textPrimary
                )
                Text("g protein today")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 48))
                    .foregroundStyle(textPrimary)
                    .baselineOffset(24)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 14) {
                CountUpNumber(
                    target: max(kcalLeftRounded, 0),
                    fontName: "JeniHeroSerif-Regular",
                    italicFontName: "JeniHeroSerif-Italic",
                    size: 200,
                    color: textPrimary
                )
                Text(kcalSuffix)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 52))
                    .foregroundStyle(textPrimary)
                    .baselineOffset(24)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var kcalSuffix: String {
        kcalLeftRounded < 0 ? "calories over" : "left"
    }

    // MARK: - Satiety prediction line

    @ViewBuilder private var satietyLine: some View {
        let hours = SatietyEstimate.hoursLabel(
            kcal: scanKcal,
            proteinG: scanProtein,
            fiberG: scanFiber
        )
        if !hours.isEmpty {
            (
                Text("this should hold you ")
                    .font(.custom("JeniHeroSerif-Regular", size: 38))
                + Text(hours)
                    .font(.custom("JeniHeroSerif-Italic", size: 38))
                + Text(".")
                    .font(.custom("JeniHeroSerif-Regular", size: 38))
            )
            .foregroundStyle(textPrimary)
            .kerning(-0.4)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 4 separate tiles

    @ViewBuilder private var tileGrid: some View {
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
                    sublabel: "today"
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
                .kerning(0.8)
            Text(value)
                .font(.custom("JeniHeroSerif-Regular", size: 88))
                .foregroundStyle(textPrimary)
                .kerning(-1.0)
            Text(sublabel)
                .font(.custom("DMSans-Light", size: 22))
                .foregroundStyle(textSecondary)
        }
        .padding(28)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color(red: 1.0, green: 0.98, blue: 0.973))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(textPrimary.opacity(0.16), lineWidth: 1.5)
        )
        .shadow(color: textPrimary.opacity(0.12), radius: 0, x: 2, y: 3)
    }

    // MARK: - Guillemet pull-quote

    @ViewBuilder private var pullQuote: some View {
        let quote = pullQuoteTuple
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            Text("«")
                .font(.custom("JeniHeroSerif-Italic", size: 44))
                .foregroundStyle(accent.opacity(0.5))
            (
                Text(quote.prefix)
                    .font(.custom("JeniHeroSerif-Regular", size: 34))
                + Text(quote.punch)
                    .font(.custom("JeniHeroSerif-Italic", size: 34))
                + Text(quote.suffix)
                    .font(.custom("JeniHeroSerif-Regular", size: 34))
            )
            .foregroundStyle(textPrimary)
            .kerning(-0.4)
            Text("»")
                .font(.custom("JeniHeroSerif-Italic", size: 44))
                .foregroundStyle(accent.opacity(0.5))
                .baselineOffset(-4)
        }
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }

    /// Observational pull-quote split as (prefix, punch, suffix) so
    /// the italic-Fraunces accent lands on a SINGLE word per phrase
    /// (locked memory rule). Mood keyed on meals logged + protein
    /// status.
    private var pullQuoteTuple: (prefix: String, punch: String, suffix: String) {
        switch (mealsLoggedToday, proteinToday >= 60) {
        case (0, _): return ("first plate of the ", "day", ".")
        case (1, _): return ("one logged. you're in ", "motion", ".")
        case (2, true): return ("two meals in. protein's ", "holding", ".")
        case (2, false): return ("two meals in. lighter on ", "protein", ".")
        case (3, true): return ("three meals in. nice ", "rhythm", ".")
        case (3, false): return ("three meals in. tomorrow has ", "room", ".")
        default:
            return mealsLoggedToday >= 4
                ? ("a full day, ", "logged", ".")
                : ("a quiet day. you're ", "tracking", ".")
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

    private var kcalToday: Int { Int(todayLogged.kcal.rounded()) + scanKcal }
    private var proteinToday: Int { Int(todayLogged.protein.rounded()) + scanProtein }
    private var fiberToday: Int { Int(todayLogged.fiber.rounded()) + scanFiber }

    private var kcalLeftRounded: Int {
        let raw = targets.kcal - kcalToday
        return Int((Double(raw) / 5).rounded()) * 5
    }

    private var mealsLoggedToday: Int {
        FoodLogPersister.todayLogCount() + 1
    }

    private var weekDeficitProjectionKcal: Int {
        let dayTarget = Double(targets.kcal)
        let pace = Double(kcalToday)
        let projected = pace * 7
        let target = dayTarget * 7
        return Int(projected - target)
    }

    private var weekPaceValue: String {
        let delta = weekDeficitProjectionKcal
        let hundreds = abs(delta) / 100 * 100
        return delta < 0 ? "−\(hundreds)" : "+\(hundreds)"
    }

    private var weekPaceLabel: String {
        weekDeficitProjectionKcal < 0 ? "cal under target" : "cal over target"
    }

    // MARK: - Palette

    private var textPrimary: Color { Color(red: 0.239, green: 0.165, blue: 0.165) }
    private var textSecondary: Color { Color(red: 0.482, green: 0.349, blue: 0.349) }
    private var accent: Color { Color(red: 0.769, green: 0.404, blue: 0.478) }
}

#endif  // canImport(UIKit)
