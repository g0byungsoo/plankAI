import SwiftUI
import PlankFood

// MARK: - PlanRow fat-row embeds (v6 per founder QA 2026-06-09 evening)
//
// Three mini-components that render INSIDE fat PlanRows. v6 simplified
// per founder feedback on v5:
//   - StepsHourChartEmbed: ONE full-width bar with % completion
//     (replaced v5's 24-bar hourly chart — too complex)
//   - SnapMealEmbed: consumed kcal + 3 macro completion bars (replaced
//     v5's thumb + macro strip). NO burned-calorie deficit math per
//     [[feedback-post-ozempic-vocabulary]] — would surface to founder if
//     burned framing is wanted.
//   - MoveExerciseEmbed: text-only workout preview (replaced v5's 3
//     mini-tiles — "doesn't need graphics, just preview")
//
// All embeds sit BELOW the row header line. Indent matches title column.

// MARK: - Steps progress embed (v6 — single bar + %)

struct StepsProgressEmbed: View {

    let current: Int
    let target: Int

    private var fraction: Double {
        guard target > 0 else { return 0 }
        return min(1.0, max(0.0, Double(current) / Double(target)))
    }

    private var percent: Int {
        Int((fraction * 100).rounded())
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Single full-width bar — accentSubtle track + accent
            // rose filled portion. 6pt tall, more visually present
            // than v4's 3pt micro-bar but still hairline-coded.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.accentSubtle)
                        .frame(width: geo.size.width, height: 6)
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: geo.size.width * CGFloat(fraction), height: 6)
                }
            }
            .frame(height: 6)

            // Percent label aligned right under the bar.
            HStack {
                Spacer()
                Text("\(percent)%")
                    .font(.custom("DMSans-SemiBold", size: 13, relativeTo: .caption))
                    .foregroundStyle(fraction >= 1.0 ? Palette.accent : Palette.cocoaSecondary)
                    .monospacedDigit()
            }
        }
        .accessibilityHidden(true)
    }
}

// MARK: - Snap meal embed (v6 — consumed + macro bars)
//
// Founder direction 2026-06-09 evening: "snap a meal just need total
// calories (gained + burned) management chart + macros (completion)."
//
// IMPLEMENTATION NOTE: shipping with consumed-kcal only (no burned).
// Brand voice rules `feedback_post_ozempic_vocabulary` ("avoid: burn,
// earn, deficit") + `feedback_anti_shame_food_ux` ("no red bars,
// uncertainty-in-language not %") explicitly avoid the deficit math
// frame. AnalyticsView comments document the same rule: "NEVER shows
// calories-burned per the cohort we burnt out on."
//
// Flagged to founder — if they want the burned/net deficit math
// despite the prior brand rule, this is a small follow-up: add a
// burned-kcal HealthKit query + a third numeric line. Otherwise we
// keep consumed-only + macros completion.

struct SnapMealEmbed: View {

    let kcal: Int
    let proteinG: Int
    let carbsG: Int
    let fatG: Int

    // Macro targets — Phase 1 ship uses simple defaults. Phase 2
    // derives from the user's weight + activity profile.
    private static let proteinTargetG: Int = 100
    private static let carbsTargetG: Int = 200
    private static let fatTargetG: Int = 70

    private var isEmpty: Bool { kcal == 0 }

    var body: some View {
        if isEmpty {
            emptyState
        } else {
            VStack(alignment: .leading, spacing: 12) {
                consumedLine
                macroBars
            }
        }
    }

    // MARK: Empty state

    private var emptyState: some View {
        // v5 §v5.7 sanctioned italic Fraunces full-phrase here as
        // the empty-state CTA (the only spot on PlanView where italic
        // runs a full sentence vs punch word only).
        Text("tap to snap your first")
            .font(.custom("Fraunces72pt-SemiBoldItalic", size: 13, relativeTo: .caption))
            .foregroundStyle(Palette.cocoaSecondary)
    }

    // MARK: Consumed kcal line — accent rose pop

    private var consumedLine: some View {
        HStack(alignment: .firstTextBaseline, spacing: 4) {
            // v1.1.1 (2026-06-19) — bumped Light → SemiBold per
            // founder QA: the today-calorie numeral was reading thin
            // against the row chrome. SemiBold lands closer to her75's
            // headline weight + matches the Becoming hero numeral.
            Text("\(kcal.formatted(.number.grouping(.automatic)))")
                .font(.custom("Fraunces72pt-SemiBold", size: 28, relativeTo: .title2))
                .foregroundStyle(Palette.accent)
                .monospacedDigit()
            Text("cal today")
                .font(Typo.caption)
                .foregroundStyle(Palette.cocoaSecondary)
            Spacer()
        }
    }

    // MARK: 3 macro completion bars

    private var macroBars: some View {
        HStack(spacing: 16) {
            macroBar(label: "protein", current: proteinG, target: Self.proteinTargetG)
            macroBar(label: "carbs", current: carbsG, target: Self.carbsTargetG)
            macroBar(label: "fat", current: fatG, target: Self.fatTargetG)
        }
    }

    private func macroBar(label: String, current: Int, target: Int) -> some View {
        let fraction = target > 0 ? min(1.0, max(0.0, Double(current) / Double(target))) : 0.0
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 4) {
                // lineLimit + scale so "protein" never wraps to
                // "protei/n" in the narrow third-column width
                // (founder screenshot 2026-06-11).
                Text(label)
                    .font(.system(size: 11, weight: .regular))
                    .foregroundStyle(Palette.cocoaTertiary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Text("\(current)g")
                    .font(.custom("DMSans-Medium", size: 11, relativeTo: .caption2))
                    .foregroundStyle(Palette.cocoaSecondary)
                    .monospacedDigit()
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Palette.accentSubtle)
                        .frame(width: geo.size.width, height: 4)
                    Capsule()
                        .fill(Palette.accent)
                        .frame(width: geo.size.width * CGFloat(fraction), height: 4)
                }
            }
            .frame(height: 4)
        }
    }
}

// MARK: - Move workout preview embed (v6 — text-only)
//
// Founder direction 2026-06-09: "preview of workout for move
// doesn't need graphics, i guess it needs to just preview the
// workout of that day." Replaces v5's 3 mini-tiles. Just a clean
// text list — total + exercise names.

struct MoveExerciseEmbed: View {

    struct Exercise {
        let name: String
        let durationLabel: String   // e.g. "2 min" or "30s"
    }

    let exercises: [Exercise]   // ordered list of today's session

    /// Phase 1 placeholder list until Phase 1.B wires
    /// WorkoutGenerator.previewExercises.
    static let placeholder: [Exercise] = [
        .init(name: "warm-up",    durationLabel: "2 min"),
        .init(name: "main set",   durationLabel: "6 min"),
        .init(name: "stretch",    durationLabel: "2 min"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Summary line — exercise count only. The row subtitle
            // directly above already says "10 min · you've got this";
            // repeating the minutes here read as redundant (founder
            // QA 2026-06-11).
            HStack(spacing: 6) {
                Text("\(exercises.count) \(exercises.count == 1 ? "exercise" : "exercises")")
                    .font(.custom("DMSans-SemiBold", size: 13, relativeTo: .caption))
                    .foregroundStyle(Palette.accent)
                Spacer()
            }

            // Exercise list — name + duration per line.
            VStack(alignment: .leading, spacing: 4) {
                ForEach(Array(exercises.prefix(4).enumerated()), id: \.offset) { _, ex in
                    HStack(spacing: 6) {
                        Text(ex.name)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaSecondary)
                        Text("·")
                            .foregroundStyle(Palette.cocoaTertiary)
                        Text(ex.durationLabel)
                            .font(Typo.caption)
                            .foregroundStyle(Palette.cocoaTertiary)
                            .monospacedDigit()
                    }
                }
                if exercises.count > 4 {
                    Text("+ \(exercises.count - 4) more")
                        .font(Typo.caption)
                        .foregroundStyle(Palette.cocoaTertiary)
                }
            }
        }
    }
}
