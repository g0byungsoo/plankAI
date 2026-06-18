#if canImport(UIKit)
import SwiftUI
import UIKit

// MARK: - ResultDayInContextCard
//
// v1.0.23 (2026-06-18) — refocused per the cohort-prioritized research
// agent's spec. Per-meal post-snap moment shouldn't context-switch to
// weekly aggregates (research: dense per-meal screens with weekly
// data create anxiety in women 22-35). Dropped:
//
//   - Week-pace tile (research: belongs on Becoming, not per-meal)
//   - "Ingredients today" tile (we don't actually track unique
//     ingredient count across the day — was a fake stat)
//
// What ships:
//
//   - Hairline-rule eyebrow ("your day so *far*")
//   - Italic kcal-left hero (CountUpNumber + italic curtsy)
//   - Italic satiety prediction
//   - 4 cohort-prioritized tiles: protein today, fiber today,
//     calories today, meals logged. Protein + fiber gain a ♡ when
//     threshold met (high-leverage cohort signal per research:
//     per-meal protein distribution is the load-bearing metric).
//   - Italic guillemet pull-quote with punch-word italic
//
// Fonts bumped across the board per founder feedback: "fonts are
// too small to read for the cards." Tile labels 26pt, tile values
// 96pt JeniHeroSerif (was 88), pull quote 40pt (was 34), satiety
// 44pt (was 38).

struct ResultDayInContextCard: View {

    let result: CapturedFood
    let targets: NutritionCarousel.MacroTargets
    let glp1Status: String

    var body: some View {
        ZStack {
            // v1.0.25 (2026-06-18) — transparent backdrop; the frozen
            // camera photo behind the carousel slot shows around the
            // floating card per founder direction.
            Color.clear

            card
                .padding(.horizontal, 56)
                .padding(.top, 96)
                .padding(.bottom, 160)
                .frame(maxHeight: .infinity, alignment: .top)
        }
        .frame(width: 1080, height: 1920)
        .clipShape(Rectangle())
    }

    /// Floating cream card with scrapbook chrome. Sized tight to
    /// content per founder direction "no empty space inside the
    /// card."
    @ViewBuilder private var card: some View {
        VStack(alignment: .leading, spacing: 36) {
            eyebrowRule
            heroNumeral
            satietyLine
            tileGrid
            pullQuote
        }
        .padding(.horizontal, 56)
        .padding(.vertical, 56)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(Color(red: 0.992, green: 0.965, blue: 0.957))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .stroke(textPrimary.opacity(0.18), lineWidth: 1.5)
        )
        .shadow(color: textPrimary.opacity(0.22), radius: 0, x: 6, y: 8)
    }

    // MARK: - Eyebrow with hairline rule

    @ViewBuilder private var eyebrowRule: some View {
        HStack(alignment: .center, spacing: 14) {
            (
                Text("your day so ")
                    .font(.custom("DMSans-Medium", size: 30))
                + Text("far")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 32))
            )
            .foregroundStyle(textSecondary)
            .kerning(0.4)

            Rectangle()
                .fill(textPrimary.opacity(0.22))
                .frame(height: 0.5)
                .frame(maxWidth: .infinity)

            Text(currentTimeLabel)
                .font(.custom("DMSans-Medium", size: 26))
                .foregroundStyle(textSecondary)
                .kerning(0.6)
        }
    }

    private var currentTimeLabel: String {
        let fmt = DateFormatter()
        fmt.dateFormat = "h:mma"
        return fmt.string(from: Date()).lowercased()
    }

    // MARK: - Hero numeral

    @ViewBuilder private var heroNumeral: some View {
        if isGlp1Cohort {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    CountUpNumber(
                        target: proteinToday,
                        fontName: "JeniHeroSerif-Regular",
                        italicFontName: "JeniHeroSerif-Italic",
                        size: 220,
                        color: textPrimary
                    )
                    Text("g")
                        .font(.custom("Fraunces72pt-SemiBoldItalic", size: 60))
                        .foregroundStyle(textSecondary)
                        .baselineOffset(36)
                }
                Text("protein today")
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 48))
                    .foregroundStyle(textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                CountUpNumber(
                    target: max(kcalLeftRounded, 0),
                    fontName: "JeniHeroSerif-Regular",
                    italicFontName: "JeniHeroSerif-Italic",
                    size: 220,
                    color: textPrimary
                )
                Text(kcalCaption)
                    .font(.custom("Fraunces72pt-SemiBoldItalic", size: 48))
                    .foregroundStyle(textSecondary)
            }
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var kcalCaption: String {
        kcalLeftRounded < 0 ? "calories over today" : "calories left today"
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
                    .font(.custom("JeniHeroSerif-Regular", size: 44))
                + Text(hours)
                    .font(.custom("JeniHeroSerif-Italic", size: 44))
                + Text(".  ")
                    .font(.custom("JeniHeroSerif-Regular", size: 44))
                + Text("♡")
                    .font(.custom("DMSans-Medium", size: 32))
                    .foregroundColor(accent.opacity(0.7))
            )
            .foregroundStyle(textPrimary)
            .kerning(-0.4)
            .lineSpacing(2)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - 4 tiles (2×2) — cohort-prioritized

    @ViewBuilder private var tileGrid: some View {
        VStack(spacing: 18) {
            HStack(spacing: 18) {
                tile(
                    label: "protein today",
                    value: "\(proteinToday)g",
                    sublabel: "of \(targets.protein)g",
                    accent: proteinToday >= targets.protein
                )
                tile(
                    label: "fiber today",
                    value: "\(fiberToday)g",
                    sublabel: "of 25g",
                    accent: fiberToday >= 25
                )
            }
            HStack(spacing: 18) {
                tile(
                    label: "calories today",
                    value: "\(kcalToday)",
                    sublabel: "of \(targets.kcal)",
                    accent: false
                )
                tile(
                    label: "meals logged",
                    value: "\(mealsLoggedToday)",
                    sublabel: mealsLoggedToday == 1 ? "first" : "today",
                    accent: false
                )
            }
        }
    }

    @ViewBuilder
    private func tile(
        label: String,
        value: String,
        sublabel: String,
        accent: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            (
                Text(label)
                    .font(.custom("DMSans-Medium", size: 26))
                + (accent
                    ? Text(" ♡")
                        .font(.custom("DMSans-Medium", size: 22))
                        .foregroundColor(self.accent.opacity(0.7))
                    : Text(""))
            )
            .foregroundStyle(textSecondary)
            .kerning(0.8)
            Text(value)
                .font(.custom("JeniHeroSerif-Regular", size: 96))
                .foregroundStyle(textPrimary)
                .kerning(-1.0)
                .monospacedDigit()
            Text(sublabel)
                .font(.custom("DMSans-Light", size: 26))
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
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Text("«")
                .font(.custom("JeniHeroSerif-Italic", size: 52))
                .foregroundStyle(accent.opacity(0.5))
            (
                Text(quote.prefix)
                    .font(.custom("JeniHeroSerif-Regular", size: 40))
                + Text(quote.punch)
                    .font(.custom("JeniHeroSerif-Italic", size: 40))
                + Text(quote.suffix)
                    .font(.custom("JeniHeroSerif-Regular", size: 40))
            )
            .foregroundStyle(textPrimary)
            .kerning(-0.4)
            Text("»")
                .font(.custom("JeniHeroSerif-Italic", size: 52))
                .foregroundStyle(accent.opacity(0.5))
                .baselineOffset(-4)
        }
        .lineLimit(2)
        .fixedSize(horizontal: false, vertical: true)
    }

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

    // MARK: - Palette

    private var textPrimary: Color { Color(red: 0.239, green: 0.165, blue: 0.165) }
    private var textSecondary: Color { Color(red: 0.482, green: 0.349, blue: 0.349) }
    private var accent: Color { Color(red: 0.769, green: 0.404, blue: 0.478) }
}

#endif  // canImport(UIKit)
