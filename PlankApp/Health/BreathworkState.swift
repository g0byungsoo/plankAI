import Foundation
import Observation

// MARK: - BreathworkState
//
// UserDefaults-backed counter for completed breathwork sessions.
// Lightweight: no SwiftData record, no Supabase sync (the count is a
// local engagement signal, not data the user pays to keep across devices).
//
// What we track:
//   - `totalCompleted` — lifetime count, drives the "you've breathed N
//     times" framing on the Becoming tile after the first completion
//   - `lastCompletedAt` — for "last breath: 2h ago" style helper lines
//     and for the day-stamp check that prevents the Becoming tile from
//     surfacing "today" copy on a yesterday completion
//   - `weeklyDayKeys` — a small set (≤ 7) of "yyyy-MM-dd" keys for the
//     last 7 days, so the tile can show distinct-days-this-week without
//     scanning a full log
//
// All writes funnel through `recordCompletion()` — the breathwork session
// view calls it once on the "complete" handler. Idempotent re-calls within
// the same minute are coalesced (rare, but a double-tap on "ready to move"
// after a network hiccup shouldn't double-count).

@MainActor
@Observable
final class BreathworkState {
    static let shared = BreathworkState()

    private enum Key {
        static let total      = "breathwork.total_completed"
        static let lastAt     = "breathwork.last_completed_at"
        static let weeklyKeys = "breathwork.weekly_day_keys"
    }

    private(set) var totalCompleted: Int = 0
    private(set) var lastCompletedAt: Date? = nil
    /// Distinct day keys in the trailing 7-day window. Old keys are
    /// pruned on every read (see `weekDayKeys`).
    private(set) var weekDayKeys: Set<String> = []

    private init() { load() }

    // MARK: - Reads

    /// Distinct calendar days the user breathed within the last 7 days.
    /// Always derives from `weekDayKeys` so a session that ages past the
    /// 7-day window automatically drops without an explicit cleanup pass.
    var distinctDaysThisWeek: Int {
        pruned(weekDayKeys).count
    }

    /// Whether the user breathed today (any time, local timezone).
    var breathedToday: Bool {
        weekDayKeys.contains(Self.todayKey())
    }

    // MARK: - Writes

    /// Called from BreathworkSessionView once per completed session. Bumps
    /// total + stamps today + last-at. Idempotent within ~60s to absorb
    /// duplicate "complete" taps (e.g. fast user double-tap).
    func recordCompletion() {
        let now = Date()
        if let last = lastCompletedAt, now.timeIntervalSince(last) < 60 {
            return
        }
        totalCompleted += 1
        lastCompletedAt = now
        weekDayKeys.insert(Self.todayKey())
        weekDayKeys = pruned(weekDayKeys)
        persist()
    }

    /// Test/debug only — reset all state. Not called from production.
    func resetForTests() {
        totalCompleted = 0
        lastCompletedAt = nil
        weekDayKeys = []
        persist()
    }

    // MARK: - Persistence

    private func load() {
        let d = UserDefaults.standard
        totalCompleted = d.integer(forKey: Key.total)
        if let ts = d.object(forKey: Key.lastAt) as? Date { lastCompletedAt = ts }
        if let arr = d.array(forKey: Key.weeklyKeys) as? [String] {
            weekDayKeys = pruned(Set(arr))
        }
    }

    private func persist() {
        let d = UserDefaults.standard
        d.set(totalCompleted, forKey: Key.total)
        if let ts = lastCompletedAt { d.set(ts, forKey: Key.lastAt) }
        d.set(Array(weekDayKeys), forKey: Key.weeklyKeys)
    }

    /// Drops day keys older than 7 days. Pure — never reads UserDefaults,
    /// so it's safe to call from any thread / inside the @Observable read
    /// path.
    private func pruned(_ keys: Set<String>) -> Set<String> {
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -6, to: cal.startOfDay(for: Date())) else {
            return keys
        }
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return keys.filter { key in
            guard let date = f.date(from: key) else { return false }
            return date >= cutoff
        }
    }

    private static func todayKey() -> String {
        let f = DateFormatter(); f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
