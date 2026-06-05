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

                    // D64 evening review surface — when the 8:30pm push
                    // lands the user back on Home and she has logs today,
                    // show a soft Jeni line that turns logging into
                    // reflection (Carver & Scheier self-regulation,
                    // Brief #5 §10). The push title is "today's plate ♥";
                    // this is the in-app payoff.
                    if isEveningReviewWindow {
                        eveningReviewLine
                    }
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

    // MARK: - Evening review

    /// 7pm-11pm local. The 8:30pm push lands in this window; the home
    /// card stays in evening-review state for ~4h around it so a user
    /// who opens late still sees the review surface.
    private var isEveningReviewWindow: Bool {
        let hour = Calendar.current.component(.hour, from: Date.now)
        return (19...22).contains(hour)
    }

    @ViewBuilder private var eveningReviewLine: some View {
        Text(eveningReviewCopy)
            .font(.system(size: 13))
            .foregroundStyle(FoodTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.top, 2)
    }

    /// Voice-locked reflection line. Branches on today vs target so the
    /// register matches the day. No shame anywhere — over-target reads
    /// as "happens" not "you failed" (anti-shame food UX lock per
    /// feedback_food_ux_antishame).
    private var eveningReviewCopy: String {
        guard dailyTarget > 0 else {
            return "today, logged. tomorrow opens fresh ♥"
        }
        let ratio = todayKcal / dailyTarget
        if ratio < 0.7 {
            return "easy today. listen to hunger tomorrow ♥"
        } else if ratio < 1.05 {
            return "today's gentle. tomorrow opens fresh ♥"
        } else if ratio < 1.25 {
            return "a bit more today — happens. tomorrow resets ♥"
        } else {
            return "today was a higher one. tomorrow resets ♥"
        }
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
