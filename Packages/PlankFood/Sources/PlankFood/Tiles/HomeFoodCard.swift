#if canImport(UIKit)
import SwiftUI
import SwiftData

// MARK: - HomeFoodCard
//
// Per v5 Home redesign + D33: food card hero for Slot 4 of HomeView.
// Replaces the StepsPulseTile-only Slot 4 with a food-first card
// (because food usage will exceed workout usage per founder thesis),
// with steps + breath pills demoted to lateral siblings (rendered
// by the parent TodayHealthStrip composite).
//
// Reads today's food logs + last-7-days for the weekly average via
// @Query on FoodLogRecord. Fully reactive — adds a new log = bar
// fills automatically, no manual refresh.

public struct HomeFoodCard: View {

    public let userId: String
    public let dailyTarget: Double
    public let onTap: () -> Void

    @Query private var logs: [FoodLogRecord]

    public init(
        userId: String,
        dailyTarget: Double,
        onTap: @escaping () -> Void
    ) {
        self.userId = userId
        self.dailyTarget = dailyTarget
        self.onTap = onTap

        // Query for the last 7 days of this user's logs. Older logs
        // exist but aren't needed for the bar or weekly-avg caption.
        let now = Date.now
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: now)!
        let predicate = #Predicate<FoodLogRecord> { log in
            log.userId == userId && log.loggedAt >= sevenDaysAgo
        }
        self._logs = Query(
            filter: predicate,
            sort: [SortDescriptor(\.loggedAt, order: .reverse)]
        )
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

    // MARK: - Aggregations

    /// Today's logged kcal, summed across all FoodLogRecords with
    /// loggedAt in the current calendar day.
    private var todayKcal: Double {
        let start = Calendar.current.startOfDay(for: Date.now)
        return logs
            .filter { $0.loggedAt >= start }
            .reduce(0) { $0 + $1.kcalTotal }
    }

    /// Average daily kcal across the 7-day window, but ONLY counts
    /// days that actually have logs. Days with zero logs don't drag
    /// the average down (matches the "weekly trend" semantics of v5).
    /// Returns nil for first-day users.
    private var weeklyAvg: Double? {
        guard !logs.isEmpty else { return nil }

        // Group by day.
        let cal = Calendar.current
        var byDay: [Date: Double] = [:]
        for log in logs {
            let day = cal.startOfDay(for: log.loggedAt)
            byDay[day, default: 0] += log.kcalTotal
        }

        guard !byDay.isEmpty else { return nil }
        let total = byDay.values.reduce(0, +)
        return total / Double(byDay.count)
    }

    private var accessibilityLabel: String {
        if todayKcal == 0 {
            return "today's plate, empty, ready when you are"
        }
        return "today's plate, \(Int(todayKcal.rounded())) calories logged today"
    }
}
#endif  // canImport(UIKit)
