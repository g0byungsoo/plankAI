import Foundation
import PlankSync

/// Pure helpers for weight analytics: goal progress (capped at 10% of
/// starting bodyweight per Wing & Phelan 2005), stall detection, and
/// summary stats. Kept out of the view so unit tests can hit them directly
/// once the Phase 8 test pass lands.
///
/// Source-of-truth for the numbers: `docs/weight_loss_analytics_research.md`.
enum WeightAnalytics {

    // MARK: - Goal progress

    /// Display goal — capped at 10% of starting bodyweight so the UI never
    /// tells a user with 18kg-to-go that they're "5% there". Per Wing &
    /// Phelan 2005, 5-10% loss yields full metabolic benefit; long-loss
    /// goals like 20kg+ correlate with demoralization curves
    /// (Jeffery 2004) — milestone-based capping keeps the bar climbable.
    static func displayGoalKg(startingKg: Double, declaredGoalKg: Double) -> Double {
        // Cap how far the displayed goal can be from start.
        let cap = startingKg * 0.90    // up to 10% loss
        return max(cap, declaredGoalKg)
    }

    /// Fraction of progress toward the (capped) goal. `nil` when there's
    /// no meaningful gap (already at or past goal, or no starting weight).
    static func goalProgress(
        startingKg: Double,
        currentKg: Double,
        declaredGoalKg: Double
    ) -> Double? {
        let displayGoal = displayGoalKg(startingKg: startingKg, declaredGoalKg: declaredGoalKg)
        let totalNeeded = startingKg - displayGoal
        guard totalNeeded > 0.5 else { return nil }   // already there or no real loss target
        let progressed = startingKg - currentKg
        return min(1.0, max(0, progressed / totalNeeded))
    }

    // MARK: - Stall detection

    /// True when the user's weight has barely moved over the last 14 days.
    /// Pulled from Linde 2004 + Thomas 2014 (NWCR): 91% of maintainers
    /// experience ≥ 1 multi-week plateau, and 30%+ of dropouts in the
    /// first 90 days are unaddressed plateaus. Surface a reframe when
    /// this fires.
    static func isStalled(logs: [WeightLogRecord], today: Date = .now) -> Bool {
        guard logs.count >= 3 else { return false }
        let cal = Calendar.current
        let startOfToday = cal.startOfDay(for: today)
        let twoWeeksAgo = cal.date(byAdding: .day, value: -14, to: startOfToday)!

        let recent = logs.filter { $0.loggedAt >= twoWeeksAgo }
        guard recent.count >= 3 else { return false }

        let weights = recent.map(\.weightKg)
        let span = (weights.max() ?? 0) - (weights.min() ?? 0)
        return span < 0.5
    }

    // MARK: - Identity-framed copy

    /// Subtitle copy for the weight card. Identity-framed when there's
    /// real movement; reframe when stalled; placeholder when there's
    /// barely any data yet. Carraça 2018 + Linde 2004.
    static func subtitle(
        logs: [WeightLogRecord],
        currentKg: Double?,
        startingKg: Double?,
        today: Date = .now
    ) -> String {
        let count = logs.count
        guard count >= 2 else {
            return "add a few more days of tracking to see your trend."
        }

        if isStalled(logs: logs, today: today) {
            // Pre-written reframe — research-backed. Don't punish the
            // plateau; recontextualize it.
            return "plateau week. your body is adjusting. maintainers see these too."
        }

        if let current = currentKg, let starting = startingKg {
            let delta = current - starting
            let logsThisWeek = countLogs(in: logs, days: 7, today: today)
            // Identity-framed: the user is "tracking", "moving", "showing up".
            // We do mention the delta but as a soft secondary fact, not a
            // headline number.
            let direction: String
            if delta < -0.3 { direction = "trending down. keep showing up." }
            else if delta > 0.3 { direction = "holding the line. consistency wins." }
            else { direction = "steady week. your body's settling." }

            let logged = logsThisWeek == 1 ? "1 log" : "\(logsThisWeek) logs"
            return "\(direction) \(logged) this week."
        }

        return "tracking \(count) day\(count == 1 ? "" : "s"). keep going."
    }

    private static func countLogs(in logs: [WeightLogRecord], days: Int, today: Date) -> Int {
        let cal = Calendar.current
        let cutoff = cal.date(byAdding: .day, value: -days, to: cal.startOfDay(for: today))!
        return logs.filter { $0.loggedAt >= cutoff }.count
    }
}
