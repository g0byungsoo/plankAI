import Foundation
import SwiftData
import Combine

// MARK: - FoodLogPersister
//
// V1.0.7 STOP-GAP (2026-06-04): SwiftData @Model integration caused
// the app to hang on launch (suspect cross-package @Model
// registration on iOS 17). Until v1.0.8 lands a proper integration
// with VersionedSchema + MigrationPlan, FoodLogPersister keeps
// logs in an in-memory store. Data is lost across app restart.
// HomeFoodCard reads via `todayAndWeekly(userId:)` + observes
// `changeNotifier` for live updates after a scan.
//
// The `persist(_:userId:photoMode:into:)` signature is preserved so
// CaptureFlowView's call site doesn't change — the ModelContext
// argument is ignored, swap is invisible to call sites.

@MainActor
public enum FoodLogPersister {

    // MARK: - In-memory store

    private static var inMemoryEntries: [Entry] = []

    /// Combine publisher fires when a new entry is added. HomeFoodCard
    /// subscribes via .onReceive to refresh its bar on every log.
    public static let changeNotifier = PassthroughSubject<Void, Never>()

    private struct Entry {
        let userId: String
        let loggedAt: Date
        let kcal: Double
    }

    // MARK: - Public API

    /// Insert a CapturedFood. Returns a placeholder FoodLogRecord
    /// (caller may use the returned id for telemetry). The
    /// ModelContext argument is IGNORED in the stop-gap — kept in
    /// the signature so CaptureFlowView doesn't change.
    @discardableResult
    public static func persist(
        _ food: CapturedFood,
        userId: String,
        into context: ModelContext
    ) throws -> FoodLogRecord {

        let plateKcal: Double
        if let low = food.kcalLow, let high = food.kcalHigh {
            plateKcal = (low + high) / 2
        } else {
            plateKcal = food.items
                .compactMap { $0.kcal }
                .reduce(0, +)
        }

        let loggedAt = Date()
        inMemoryEntries.append(Entry(
            userId: userId,
            loggedAt: loggedAt,
            kcal: plateKcal
        ))

        changeNotifier.send(())

        // Apple Health write hook. The main app registers a closure at
        // launch that reads the user's "foodHealthKitWriteEnabled"
        // toggle, confirms HK auth, and saves an HKQuantitySample.
        // No-op if toggle off or write auth not granted. PlankFood
        // stays HealthKit-blind.
        FoodHealthKitWriter.writeIfRegistered(kcal: plateKcal, at: loggedAt)

        // Return a placeholder FoodLogRecord so the call-site signature
        // is preserved (the @Model class still exists; it's just not in
        // the app's ModelContainer until v1.0.8).
        return FoodLogRecord(
            userId: userId,
            kcalTotal: plateKcal,
            plateType: food.plateType.rawValue,
            source: food.source.rawValue,
            photoMode: nil  // D54 — column kept for v1.0.8 SwiftData
                            // migration safety; always nil now.
        )
    }

    /// Aggregate today's kcal + weekly average from the in-memory
    /// store. Called by HomeFoodCard on appear + every changeNotifier
    /// emission.
    public static func todayAndWeekly(userId: String) -> (today: Double, weekly: Double?) {
        let cal = Calendar.current
        let now = Date.now
        let startOfToday = cal.startOfDay(for: now)
        let sevenDaysAgo = cal.date(byAdding: .day, value: -7, to: now)!

        let userEntries = inMemoryEntries.filter { $0.userId == userId }

        let today = userEntries
            .filter { $0.loggedAt >= startOfToday }
            .reduce(0) { $0 + $1.kcal }

        // Group last-7-days entries by day for the weekly average.
        var byDay: [Date: Double] = [:]
        for entry in userEntries where entry.loggedAt >= sevenDaysAgo {
            let day = cal.startOfDay(for: entry.loggedAt)
            byDay[day, default: 0] += entry.kcal
        }
        let weekly: Double?
        if byDay.isEmpty {
            weekly = nil
        } else {
            weekly = byDay.values.reduce(0, +) / Double(byDay.count)
        }

        return (today, weekly)
    }
}
