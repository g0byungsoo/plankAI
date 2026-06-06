#if canImport(UIKit)
import SwiftUI
import Combine

// MARK: - FoodWeekBentoTile
//
// The depth read of food logging — slotted into the Becoming bento
// alongside steps + breath + weight trend. Matches the
// BreathworkBentoTile / StepsBentoTile chrome + ⓘ explainer pattern
// so all four passive identity reads feel like one family.
//
// What this is NOT: an actionable CTA. The Home food card carries
// "snap a meal" affordance; this tile is the post-hoc "here's your
// week" read. Tapping the tile body is a no-op; tapping the ⓘ opens
// the metric explainer in the parent view.
//
// Sourcing: FoodLogPersister.last7DaysKcal(userId:) — in-memory
// stop-gap until v1.0.8 lands the SwiftData @Model integration.
// Subscribes to changeNotifier so the bars refresh after a new scan.
//
// Honesty Doctrine: NEVER labels a day "over" or "under." Bars are
// pure data viz. No red bars, no goal lines, no comparison numbers
// shaming the user. The hero metric is the weekly AVERAGE in the
// user's own unit (kcal); the days-logged count below is celebration,
// not pressure.

public struct FoodWeekBentoTile: View {

    public let userId: String
    public var onExplain: () -> Void

    public init(userId: String, onExplain: @escaping () -> Void) {
        self.userId = userId
        self.onExplain = onExplain
    }

    @State private var weeklyAverage: Double = 0
    @State private var daysLogged: Int = 0
    @State private var dailyKcal: [(date: Date, kcal: Double)] = []
    @State private var cancellable: AnyCancellable?

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            header
            if daysLogged == 0 {
                emptyContent
            } else {
                stockedContent
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(chrome)
        .onAppear(perform: refresh)
        .onAppear {
            cancellable = FoodLogPersister.changeNotifier.sink { _ in refresh() }
        }
        .onDisappear {
            cancellable?.cancel()
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityText)
    }

    // MARK: - Layers

    private var header: some View {
        HStack(spacing: 5) {
            Text("plate")
                .font(.system(size: 10, weight: .semibold))
                .tracking(1.5)
                .foregroundStyle(FoodTheme.accent)
                .textCase(.uppercase)
            Button(action: onExplain) {
                Image(systemName: "info.circle")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(FoodTheme.textSecondary.opacity(0.55))
                    .frame(width: 22, height: 22)
            }
            .accessibilityLabel("what plate means")
        }
    }

    private var emptyContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("ready when you are")
                .font(.system(size: 14, weight: .medium))
                .foregroundStyle(FoodTheme.textPrimary)
            Text("snap your first plate from home ♥")
                .font(.system(size: 11))
                .foregroundStyle(FoodTheme.textSecondary)
        }
    }

    private var stockedContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(Int(weeklyAverage.rounded()).formatted(.number))
                    .font(.custom("Fraunces72pt-SemiBold", size: 28))
                    .foregroundStyle(FoodTheme.textPrimary)
                Text("kcal/day")
                    .font(.system(size: 11))
                    .foregroundStyle(FoodTheme.textSecondary)
                Spacer(minLength: 0)
                Text("avg this week")
                    .font(.system(size: 11))
                    .foregroundStyle(FoodTheme.textSecondary)
            }

            // 7-day bars — normalized to the highest day so the visual
            // shape reads as relative rhythm, not absolute amount.
            // Zero days render as a faint outline so the user can
            // count quiet days at a glance.
            let maxKcal = max(dailyKcal.map(\.kcal).max() ?? 0, 1)
            HStack(alignment: .bottom, spacing: 6) {
                ForEach(0..<dailyKcal.count, id: \.self) { idx in
                    let entry = dailyKcal[idx]
                    let ratio = entry.kcal / maxKcal
                    RoundedRectangle(cornerRadius: 3, style: .continuous)
                        .fill(entry.kcal > 0 ? FoodTheme.accent : Color.clear)
                        .frame(width: 16, height: max(2, ratio * 36))
                        .overlay(
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .stroke(FoodTheme.accent.opacity(entry.kcal > 0 ? 0 : 0.4),
                                        lineWidth: 1)
                        )
                }
                Spacer(minLength: 0)
            }
            .frame(height: 38)

            Text("\(daysLogged) \(daysLogged == 1 ? "day" : "days") logged ♥")
                .font(.system(size: 11))
                .foregroundStyle(FoodTheme.textSecondary)
        }
    }

    private var chrome: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(FoodTheme.accent.opacity(0.12))
                .offset(x: 3, y: 3)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(FoodTheme.bgElevated)
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(FoodTheme.accent.opacity(0.45), lineWidth: 1.5)
        }
    }

    // MARK: - Data

    private func refresh() {
        let week = FoodLogPersister.last7DaysKcal(userId: userId)
        let nonZero = week.filter { $0.kcal > 0 }
        dailyKcal = week
        daysLogged = nonZero.count
        weeklyAverage = nonZero.isEmpty ? 0 : nonZero.map(\.kcal).reduce(0, +) / Double(nonZero.count)
    }

    private var accessibilityText: String {
        if daysLogged == 0 {
            return "plate. ready when you are."
        }
        return "plate. \(daysLogged) days logged this week. average \(Int(weeklyAverage.rounded())) kcal per day."
    }
}

#endif  // canImport(UIKit)
