#if canImport(UIKit)
import SwiftUI

// MARK: - HomeFoodCard
//
// Per v5 Home redesign + D33: food card hero for Slot 4 of HomeView.
// Replaces the StepsPulseTile-only Slot 4 with a food-first card
// (because food usage will exceed workout usage per founder thesis),
// with steps + breath pills demoted to lateral siblings (rendered
// by the parent TodayHealthStrip composite).
//
// V1.0.7 STOP-GAP (2026-06-04): originally used SwiftData @Query
// over FoodLogRecord but cross-package @Model integration caused
// the app to hang on launch. Reads from FoodLogPersister's in-
// memory store instead. Data lost across app restart in v1.0.7;
// v1.0.8 ships proper SwiftData integration with explicit migration
// plan.

public struct HomeFoodCard: View {

    public let userId: String
    public let dailyTarget: Double
    public let onTap: () -> Void

    @State private var todayKcal: Double = 0
    @State private var weeklyAvg: Double? = nil

    public init(
        userId: String,
        dailyTarget: Double,
        onTap: @escaping () -> Void
    ) {
        self.userId = userId
        self.dailyTarget = dailyTarget
        self.onTap = onTap
    }

    public var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: FoodTheme.Space.md) {
                header

                if todayKcal == 0 {
                    emptyState
                } else {
                    WeeklyAvgBar(
                        todayKcal: todayKcal,
                        dailyTarget: dailyTarget,
                        weeklyAvgKcal: weeklyAvg
                    )
                }

                Spacer(minLength: 0)

                tapHint
            }
            .padding(FoodTheme.Space.lg)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(FoodTheme.bgElevated)
            .overlay(
                RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous)
                    .stroke(FoodTheme.textPrimary.opacity(0.08), lineWidth: 0.5)
            )
            .clipShape(RoundedRectangle(cornerRadius: FoodTheme.Radius.card, style: .continuous))
            .shadow(color: FoodTheme.textPrimary.opacity(0.05), radius: 3, x: 0, y: 2)
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityHint("tap to log a meal")
        .onAppear { refresh() }
        .onReceive(FoodLogPersister.changeNotifier) { _ in refresh() }
    }

    // MARK: - Subviews

    @ViewBuilder private var header: some View {
        HStack(spacing: 8) {
            Text("🍓")
                .font(.system(size: 22))
                .accessibilityHidden(true)
            Text("today's plate")
                .font(.custom("Fraunces72pt-SemiBold", size: 18))
                .foregroundStyle(FoodTheme.textPrimary)
            Spacer(minLength: 0)
        }
    }

    @ViewBuilder private var emptyState: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("ready when you are.")
                .font(.system(size: 15))
                .foregroundStyle(FoodTheme.textSecondary)
        }
        .padding(.vertical, FoodTheme.Space.sm)
    }

    @ViewBuilder private var tapHint: some View {
        HStack(spacing: 4) {
            Text("tap to log")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(FoodTheme.textSecondary)
            Image(systemName: "arrow.right")
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(FoodTheme.textSecondary)
        }
    }

    // MARK: - Refresh

    private func refresh() {
        let (today, weekly) = FoodLogPersister.todayAndWeekly(userId: userId)
        todayKcal = today
        weeklyAvg = weekly
    }

    private var accessibilityLabel: String {
        if todayKcal == 0 {
            return "today's plate, empty, ready when you are"
        }
        return "today's plate, \(Int(todayKcal.rounded())) calories logged today"
    }
}
#endif  // canImport(UIKit)
