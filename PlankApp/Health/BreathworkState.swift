import Foundation
import Observation
import Auth

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
        // v1.0.7 QA fix (cross-account leak): keys namespaced by the
        // current user_id so sign-out → sign-in to a different account
        // doesn't inherit prior user's breath count + day stamps.
        // Anonymous users get the "anon" suffix until upgrade.
        static func total(_ uid: String) -> String      { "breathwork.\(uid).total_completed" }
        static func lastAt(_ uid: String) -> String     { "breathwork.\(uid).last_completed_at" }
        static func weeklyKeys(_ uid: String) -> String { "breathwork.\(uid).weekly_day_keys" }

        // Legacy unnamespaced keys (pre-v1.0.7). load() one-time
        // migrates these into the current user's namespace then
        // deletes them so the data follows the user that wrote it.
        static let legacyTotal      = "breathwork.total_completed"
        static let legacyLastAt     = "breathwork.last_completed_at"
        static let legacyWeeklyKeys = "breathwork.weekly_day_keys"
    }

    private(set) var totalCompleted: Int = 0
    private(set) var lastCompletedAt: Date? = nil
    /// Distinct day keys in the trailing 7-day window. Old keys are
    /// pruned on every read (see `weekDayKeys`).
    private(set) var weekDayKeys: Set<String> = []

    private init() { load() }

    /// Resolve the current user's id for key namespacing. Returns
    /// "anon" when no signed-in user is available (pre-bootstrap,
    /// or fully anonymous device). Accessing AuthService.shared
    /// from BreathworkState couples the two but the alternative
    /// (passing userId into every method) is more invasive than
    /// this release window allows.
    private static func currentNamespace() -> String {
        if let uid = AuthService.shared.currentUser?.id.uuidString {
            return uid
        }
        return "anon"
    }

    /// Wipe the in-memory cache so the next read reloads from the
    /// current user's UserDefaults namespace. Called from AppSync on
    /// auth change so a sign-in to a different account doesn't keep
    /// stale prior-account counts displayed in the UI.
    func reloadForCurrentUser() {
        totalCompleted = 0
        lastCompletedAt = nil
        weekDayKeys = []
        load()
    }

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
        let ns = Self.currentNamespace()

        // One-time migration: if legacy unnamespaced keys exist AND
        // the namespaced keys for the current user are empty, copy
        // the legacy values into the current namespace then delete
        // the legacy keys. This preserves the breath count for the
        // single-user device case (vast majority) and stops it from
        // leaking to future accounts on the same device.
        let hasNamespaced = d.object(forKey: Key.total(ns)) != nil
        if !hasNamespaced, d.object(forKey: Key.legacyTotal) != nil {
            let legacyTotal = d.integer(forKey: Key.legacyTotal)
            let legacyLast = d.object(forKey: Key.legacyLastAt) as? Date
            let legacyWeekly = (d.array(forKey: Key.legacyWeeklyKeys) as? [String]) ?? []
            d.set(legacyTotal, forKey: Key.total(ns))
            if let last = legacyLast { d.set(last, forKey: Key.lastAt(ns)) }
            d.set(legacyWeekly, forKey: Key.weeklyKeys(ns))
            d.removeObject(forKey: Key.legacyTotal)
            d.removeObject(forKey: Key.legacyLastAt)
            d.removeObject(forKey: Key.legacyWeeklyKeys)
        }

        totalCompleted = d.integer(forKey: Key.total(ns))
        if let ts = d.object(forKey: Key.lastAt(ns)) as? Date { lastCompletedAt = ts }
        if let arr = d.array(forKey: Key.weeklyKeys(ns)) as? [String] {
            weekDayKeys = pruned(Set(arr))
        }
    }

    private func persist() {
        let d = UserDefaults.standard
        let ns = Self.currentNamespace()
        d.set(totalCompleted, forKey: Key.total(ns))
        if let ts = lastCompletedAt { d.set(ts, forKey: Key.lastAt(ns)) }
        d.set(Array(weekDayKeys), forKey: Key.weeklyKeys(ns))
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
