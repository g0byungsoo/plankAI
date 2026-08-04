import Foundation
import Observation
import HealthKit

// MARK: - MovementService
//
// v9 P0 (docs/app_v9/02_PLAN.md, W6) — the movement streams the
// brief names beyond steps: workouts (strength detection = the
// muscle-preservation input), active energy, walking distance.
//
// DORMANT BY DESIGN: silent probe only, mirroring VitalsService —
// if a prior grant covers the types, data flows into BodyState;
// otherwise everything stays nil and nothing renders. The actual
// authorization ask ships WITH the first rendered surface (P3's
// weekly body review) per L5 — never request what nothing shows.
// Verb law rider: movement is observed, never "earned" or "burned"
// — activeEnergy renders only inside observational frames.

@MainActor
@Observable
final class MovementService {
    static let shared = MovementService()

    /// Strength workouts in the trailing 7 days (the resistance
    /// signal; P3's preservation read).
    private(set) var strengthSessionsLast7: Int = 0
    /// Today's active energy, whole kcal; nil when nothing flows.
    private(set) var activeEnergyTodayKcal: Int?
    /// Today's walking+running distance, km; nil under 0.1 km.
    private(set) var distanceTodayKm: Double?
    private(set) var lastSyncedAt: Date?

    private let healthStore = HKHealthStore()

    /// The read types P3's surface will ask for (L5: the request
    /// lives with the surface, not here).
    static var readTypes: Set<HKObjectType> {
        var set: Set<HKObjectType> = [HKWorkoutType.workoutType()]
        for id: HKQuantityTypeIdentifier in [.activeEnergyBurned, .distanceWalkingRunning] {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                set.insert(t)
            }
        }
        return set
    }

    private init() {}

    /// Strength = the muscle-preservation signal (P3). Walking and
    /// cardio never count — the read is about resistance, not effort.
    /// Pure — nonisolated so engines and tests call it anywhere.
    nonisolated static func strengthCount(_ activities: [HKWorkoutActivityType]) -> Int {
        activities.filter {
            $0 == .traditionalStrengthTraining || $0 == .functionalStrengthTraining
        }.count
    }

    // MARK: - Bootstrap + access

    /// Silent: try to read; never prompts. Called at launch beside
    /// the steps/sleep/vitals bootstraps.
    func bootstrap() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        await refresh()
    }

    /// Whether the movement ask has ever been shown (HK read status
    /// is opaque; the flag is the honest "strength is knowable"
    /// signal for the preservation read's connect door). Device-
    /// level, like bodyMassImportRequested.
    private static let requestedKey = "movement.hkRequested"
    var everRequested: Bool {
        UserDefaults.standard.bool(forKey: Self.requestedKey)
    }

    /// The system sheet for the movement read types — called by the
    /// weekly read's connect door (P3), the surface that renders it.
    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await healthStore.requestAuthorization(
                toShare: [], read: Self.readTypes
            )
            UserDefaults.standard.set(true, forKey: Self.requestedKey)
        } catch {
            #if DEBUG
            print("[MovementService] requestAuthorization failed: \(error)")
            #endif
        }
        await refresh(force: true)
    }

    // MARK: - Refresh

    func refresh(force: Bool = false) async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        if !force, let synced = lastSyncedAt,
           Date().timeIntervalSince(synced) < 900 {
            return
        }

        let cal = Calendar.current
        let now = Date()
        let startOfToday = cal.startOfDay(for: now)
        guard let weekAgo = cal.date(byAdding: .day, value: -7, to: now) else { return }

        // Workouts, trailing 7 days.
        let workouts: [HKWorkout] = await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(
                withStart: weekAgo, end: now, options: .strictStartDate
            )
            let query = HKSampleQuery(
                sampleType: HKWorkoutType.workoutType(),
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: (samples as? [HKWorkout]) ?? [])
            }
            healthStore.execute(query)
        }
        strengthSessionsLast7 = Self.strengthCount(workouts.map(\.workoutActivityType))

        // Today's active energy.
        if let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) {
            let kcal = await cumulativeSum(
                type, unit: .kilocalorie(), from: startOfToday, to: now
            )
            activeEnergyTodayKcal = kcal.map { Int($0.rounded()) }
        }

        // Today's walking+running distance.
        if let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) {
            let meters = await cumulativeSum(
                type, unit: .meter(), from: startOfToday, to: now
            )
            let km = (meters ?? 0) / 1000
            distanceTodayKm = km >= 0.1 ? km : nil
        }

        lastSyncedAt = .now
    }

    private func cumulativeSum(
        _ type: HKQuantityType, unit: HKUnit, from start: Date, to end: Date
    ) async -> Double? {
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: end, options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, _ in
                continuation.resume(
                    returning: stats?.sumQuantity()?.doubleValue(for: unit)
                )
            }
            healthStore.execute(query)
        }
    }
}
