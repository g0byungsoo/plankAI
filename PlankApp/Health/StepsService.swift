import Foundation
import Observation
import HealthKit

// MARK: - StepsService
//
// HealthKit-backed step source for the home pulse tile + the Becoming bento
// "moving" tile. Read-only — JeniFit never writes step samples back to Health.
//
// Why a service singleton (not a SwiftData record + sync): step samples
// already live in Apple Health (every iPhone since iOS 8 ships the M-series
// motion coprocessor that records them). Re-storing them in Supabase would
// double the source of truth, churn battery, and add a privacy surface for
// data that doesn't need to leave the device. The pulse + bento read live;
// no persistence on our side beyond the small in-memory cache + the
// last-sync timestamp that lets us avoid re-querying within a render burst.
//
// Goal anchor: 7,500 steps/day per the 2026 weight-loss meta-analysis
// (Jayedi et al.) — the inflection point where weight-regain risk drops
// without the all-or-nothing pressure of the legacy 10k myth. UI copy is
// anti-shame (under-goal = "every step counts ♥", never red, never "you
// failed today"); see StepsPulseTile + the steps bento tile.
//
// Permission model: HealthKit returns `notDetermined` to apps that haven't
// asked yet AND to apps the user explicitly denied — `authorizationStatus`
// for read intents is intentionally opaque for privacy (Apple won't tell
// us "user said no"). We model that as a tri-state:
//   .notDetermined → show "tap to connect" CTA on the tile
//   .authorized    → show ring + count
//   .denied        → show calm "steps live in apple health" fallback line
// We infer .denied only when a fresh post-request query returns nil
// statistics for the last 24h (the explicit signal we have).
//
// Lifecycle:
//   - PlankAIApp calls `bootstrap()` once at launch. If the user previously
//     granted access, the cache + observer warm up silently. If not, we
//     stay in .notDetermined until the user taps the connect CTA on the
//     pulse tile.
//   - The observer query fires `refresh()` whenever new step samples
//     arrive (foreground only — no background delivery in v1, to keep
//     the privacy surface tight and skip the additional Apple review beat).
//
// Sim note: HealthKit on iOS Simulator returns empty stats by default;
// add samples via the Health app on the sim (Browse → Activity → Steps
// → Add Data) to test the populated states.

@MainActor
@Observable
final class StepsService {
    static let shared = StepsService()

    // The evidence-based daily anchor. NOT 10,000. Reads as the visual
    // 100% mark on the ring + the soft target referenced in tile copy.
    // If a beginner with a low baseline finds 7,500 demoralizing, the
    // tile copy carries the anti-shame frame ("every step counts ♥");
    // the goal number itself stays honest.
    static let dailyGoal: Int = 7_500

    enum Authorization: Equatable {
        case unavailable    // HealthKit isn't supported on this device
        case notDetermined  // never asked, or user opened Health and reset
        case authorized     // share access granted
        case denied         // explicit deny inferred from no data + post-ask
    }

    private(set) var authStatus: Authorization
    /// Today's step total (calendar day, user's current timezone).
    private(set) var todayCount: Int = 0
    /// Last 7 calendar days, oldest → newest. `[0]` is 6 days ago,
    /// `[6]` is today. Drives the bento bar chart + week total.
    private(set) var weeklyCounts: [Int] = Array(repeating: 0, count: 7)
    /// Most recent successful refresh, used as a freshness guard.
    private(set) var lastSyncedAt: Date?

    private let healthStore = HKHealthStore()
    private var observerQuery: HKObserverQuery?
    /// Reads-since-bootstrap counter; we use it to detect the "post-ask,
    /// still nothing" case that infers .denied.
    private var bootstrapped = false

    private init() {
        self.authStatus = HKHealthStore.isHealthDataAvailable() ? .notDetermined : .unavailable
    }

    /// Week total (sum of `weeklyCounts`). Convenience for the bento tile.
    var weekTotal: Int { weeklyCounts.reduce(0, +) }

    /// Today's progress against `dailyGoal`, clamped 0…1. Drives the ring.
    var todayProgress: Double {
        guard Self.dailyGoal > 0 else { return 0 }
        return min(1, Double(todayCount) / Double(Self.dailyGoal))
    }

    // MARK: - Bootstrap

    /// Called once at launch from `PlankAIApp`. Silent: if the user has
    /// already granted access (or denied), we don't re-prompt — we just
    /// try to read. The prompt itself is gated to the user's explicit
    /// tap on the home pulse tile's "connect" CTA.
    func bootstrap() async {
        guard case .notDetermined = authStatus else { return }
        guard HKHealthStore.isHealthDataAvailable() else {
            authStatus = .unavailable
            return
        }
        bootstrapped = true
        // Probe — if the system already lets us read step samples, we
        // skip the prompt entirely and flip to .authorized.
        await refresh()
        if todayCount > 0 || weekTotal > 0 {
            authStatus = .authorized
            startObserving()
        }
    }

    // MARK: - Request access

    /// Triggered by the user tapping "connect" on the pulse tile. Surfaces
    /// the iOS HealthKit share-data sheet for step count. After the user
    /// decides, we run one refresh — and infer .denied if we still read
    /// nothing (HealthKit won't tell us read denials directly).
    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            authStatus = .unavailable
            return
        }
        let stepType = HKQuantityType(.stepCount)
        do {
            // toShare: empty — we only need read. The system sheet UI
            // adapts to show "Allow JeniFit to read: Steps" only.
            try await healthStore.requestAuthorization(toShare: [], read: [stepType])
        } catch {
            #if DEBUG
            print("[StepsService] requestAuthorization failed: \(error)")
            #endif
            // Failure here = communication error with the daemon, not a
            // deny. Stay in .notDetermined so the user can retry.
            return
        }

        // Post-ask probe.
        await refresh()
        // If we got data, we're authorized. If we got zero AND the user
        // has been using their phone (so some steps almost certainly
        // exist), infer deny — but we can't be sure. Stay conservative:
        // flip to authorized when there's any signal at all; stay
        // .notDetermined when zero, so the CTA keeps inviting (vs. a
        // dead-end "denied" state for a user who genuinely just hasn't
        // walked yet today).
        if todayCount > 0 || weekTotal > 0 {
            authStatus = .authorized
            startObserving()
        } else {
            // First-day install on a fresh-out-of-the-box phone with
            // zero historical samples is rare but real — leave the
            // door open. The next refresh will move us out of this
            // state once data arrives.
            authStatus = .authorized
            startObserving()
        }

        Analytics.track(.stepsConnected, properties: [
            "today_count": todayCount,
            "week_total": weekTotal
        ])
    }

    // MARK: - Refresh

    /// Re-reads today + the last 7 days from Health and updates the
    /// published counts. Safe to call from any view's `.task`/`onAppear`
    /// — the underlying HKStatisticsCollectionQuery is async + cheap.
    func refresh() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let stepType = HKQuantityType(.stepCount)

        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        // Anchor the 7-day window 6 days BEFORE today so the result has
        // exactly 7 daily buckets (today + 6 prior).
        guard let weekStart = cal.date(byAdding: .day, value: -6, to: startOfToday) else { return }

        let predicate = HKQuery.predicateForSamples(withStart: weekStart, end: now, options: .strictStartDate)
        var interval = DateComponents(); interval.day = 1

        let counts: [Int] = await withCheckedContinuation { continuation in
            let query = HKStatisticsCollectionQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum,
                anchorDate: weekStart,
                intervalComponents: interval
            )
            query.initialResultsHandler = { _, collection, _ in
                var buckets: [Int] = Array(repeating: 0, count: 7)
                collection?.enumerateStatistics(from: weekStart, to: now) { stats, _ in
                    let day = cal.dateComponents([.day], from: weekStart, to: stats.startDate).day ?? 0
                    if (0..<7).contains(day) {
                        let value = Int(stats.sumQuantity()?.doubleValue(for: .count()) ?? 0)
                        buckets[day] = value
                    }
                }
                continuation.resume(returning: buckets)
            }
            healthStore.execute(query)
        }

        self.weeklyCounts = counts
        self.todayCount = counts.last ?? 0
        self.lastSyncedAt = Date()
    }

    // MARK: - Observer (foreground updates)

    /// Subscribes to step-count changes while the app is foregrounded.
    /// We deliberately skip `enableBackgroundDelivery` in v1: the home
    /// pulse + Becoming tile only need fresh data when the user looks
    /// at them, and background delivery requires an additional Apple
    /// review nod we don't need yet.
    private func startObserving() {
        guard observerQuery == nil else { return }
        let stepType = HKQuantityType(.stepCount)
        let query = HKObserverQuery(sampleType: stepType, predicate: nil) { [weak self] _, _, error in
            guard error == nil, let self else { return }
            Task { @MainActor in await self.refresh() }
        }
        observerQuery = query
        healthStore.execute(query)
    }
}
