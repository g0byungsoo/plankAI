#if canImport(UIKit)
import SwiftUI

// MARK: - WeeklyAvgBar
//
// Per v5 D33 (Ring → Bar lock): Apple Watch's three rings created a
// generation of users with closure-debt anxiety. r/EatingDisorders +
// r/loseit have explicit threads on "ring guilt." The bar shape
// removes that gesture entirely — same data, no loop-closing
// psychology.
//
// Renders today's kcal vs the user's daily goal as a horizontal
// fill. Cocoa color, NEVER red. Over-target bars desaturate but
// don't change hue. Caption is the WEEKLY AVERAGE (per v5 §Home
// redesign: trend is hero, daily calorie is a footnote).

public struct WeeklyAvgBar: View {

    public let todayKcal: Double
    public let dailyTarget: Double
    public let weeklyAvgKcal: Double?

    public init(
        todayKcal: Double,
        dailyTarget: Double,
        weeklyAvgKcal: Double? = nil
    ) {
        self.todayKcal = todayKcal
        self.dailyTarget = dailyTarget
        self.weeklyAvgKcal = weeklyAvgKcal
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: FoodTheme.Space.sm) {
            // Centerpiece: today's count.
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text("\(Int(todayKcal.rounded()))")
                    .font(.custom("Fraunces72pt-SemiBold", size: 36))
                    .foregroundStyle(FoodTheme.textPrimary)
                Text("today")
                    .font(.system(size: 14))
                    .foregroundStyle(FoodTheme.textSecondary)
            }

            // The bar.
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(FoodTheme.accentSubtle.opacity(0.4))
                        .frame(height: 10)

                    Capsule()
                        .fill(barColor)
                        .frame(width: geo.size.width * fillRatio, height: 10)
                        .animation(.easeInOut(duration: 0.4), value: todayKcal)
                }
            }
            .frame(height: 10)

            // Weekly-avg caption — the actual hero per v5 (daily is
            // demoted to a footnote).
            Text(captionCopy)
                .font(.system(size: 13))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityCopy)
    }

    // MARK: - Computation

    /// Fill ratio. Caps at 1.0 visually (over-target bars don't
    /// extend past the track — keeps the closure-debt trigger off
    /// even at the edge).
    private var fillRatio: Double {
        guard dailyTarget > 0 else { return 0 }
        return min(1.0, todayKcal / dailyTarget)
    }

    /// Cocoa for normal range; desaturated cocoa for over-target.
    /// NEVER red. Per v5 anti-shame lock.
    private var barColor: Color {
        guard dailyTarget > 0 else { return FoodTheme.textPrimary }
        let ratio = todayKcal / dailyTarget
        if ratio > 1.0 {
            return FoodTheme.textPrimary.opacity(0.55)
        }
        return FoodTheme.textPrimary
    }

    /// Per v5 Home redesign + voice locks. Always references the
    /// WEEKLY trend (not today's over/under). Anti-shame copy when
    /// the week is high or low.
    private var captionCopy: String {
        guard let weeklyAvg = weeklyAvgKcal, weeklyAvg > 0 else {
            return "tracking your first day. ♥"
        }

        let weeklyDelta = (weeklyAvg - dailyTarget) / dailyTarget

        switch weeklyDelta {
        case ..<(-0.15):
            // Way under — under-target safety net per feedback_food_ux_antishame.
            return "averaging \(Int(weeklyAvg.rounded())). your body needs more."
        case -0.15..<0.10:
            return "tracking your week · avg \(Int(weeklyAvg.rounded()))"
        case 0.10..<0.20:
            return "averaging \(Int(weeklyAvg.rounded())). a higher week. tomorrow resets."
        default:
            return "averaging \(Int(weeklyAvg.rounded())). that's a normal week. ♥"
        }
    }

    private var accessibilityCopy: String {
        "today \(Int(todayKcal.rounded())) calories. \(captionCopy)"
    }
}

// MARK: - Preview

#Preview("WeeklyAvgBar") {
    VStack(alignment: .leading, spacing: 28) {
        WeeklyAvgBar(todayKcal: 0, dailyTarget: 1650)               // empty
        WeeklyAvgBar(todayKcal: 820, dailyTarget: 1650, weeklyAvgKcal: 1640)   // tracking
        WeeklyAvgBar(todayKcal: 1420, dailyTarget: 1650, weeklyAvgKcal: 1750)  // higher week
        WeeklyAvgBar(todayKcal: 1820, dailyTarget: 1650, weeklyAvgKcal: 2050)  // way high
        WeeklyAvgBar(todayKcal: 950, dailyTarget: 1650, weeklyAvgKcal: 1180)   // way low
    }
    .padding()
    .background(FoodTheme.bgPrimary)
}

#endif  // canImport(UIKit)
