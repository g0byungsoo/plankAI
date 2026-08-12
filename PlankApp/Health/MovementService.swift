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
    /// v25 E1 — minutes of HealthKit-written workouts today (any
    /// activity). ≥10 absorbs the walking action.
    private(set) var workoutMinutesToday: Int = 0
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
    private nonisolated static let requestedKey = "movement.hkRequested"
    var everRequested: Bool {
        UserDefaults.standard.bool(forKey: Self.requestedKey)
    }

    /// The system sheet for the movement read types — called by the
    /// surface that renders them (L5). As of E8.2 that surface is
    /// JENI MOVE: `MoveSheet` offers the ask when iOS says one is
    /// still worth showing.
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

    /// Records that a system sheet INCLUDING the movement read types
    /// has been shown, when another service union-asked on our behalf
    /// (StepsService rides workouts/energy/distance on its sheet the
    /// same way it rides vitals + cycle).
    nonisolated static func markRequested() {
        UserDefaults.standard.set(true, forKey: requestedKey)
    }

    /// Whether the movement ask is still worth offering. iOS never
    /// reveals a read GRANT, but it does say whether the request
    /// sheet would show anything new — which survives reinstalls,
    /// unlike the UserDefaults flag. `.shouldRequest` means some
    /// movement type has never been asked for on this device.
    func shouldOfferAsk() async -> Bool {
        guard HKHealthStore.isHealthDataAvailable() else { return false }
        let status = try? await healthStore.statusForAuthorizationRequest(
            toShare: [], read: Self.readTypes
        )
        return status == .shouldRequest
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

        // v25 E1 — any external workout today (watch/other apps)
        // absorbs the walking action: never ask for what iOS already
        // knows (passive law).
        workoutMinutesToday = Int(
            workouts
                .filter { $0.startDate >= startOfToday }
                .reduce(0.0) { $0 + $1.duration / 60.0 }
                .rounded()
        )

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

    #if DEBUG
    /// QA-only (E8.2 proof): the simulator has no sensors, but its
    /// HealthKit STORE is real — so write the exact sample shapes a
    /// watch or gym app would, then exercise the untouched production
    /// read path against them. Mirrors `BodyMassImportService
    /// .debugWriteSample` (v9 P0), which proved passive weight the
    /// same way.
    ///
    /// The §5 law "manual entries are never written back to HealthKit"
    /// is a PRODUCT-write law; this is a DEBUG-only test fixture,
    /// never compiled into release, and writes nothing a user entered.
    ///
    /// Seeds: two strength workouts this week (one traditional, one
    /// functional — both classifiers), one yoga (the negative control:
    /// it must NOT count), one 24-min walk today (the workout-minutes
    /// row + E1's walk-absorb), TWO active-energy samples today (the
    /// sum proves `.cumulativeSum`, not just presence) and two
    /// distance samples today (same).
    func debugWriteMoveSamples() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        // Deterministic base state: hand-recorded sessions persist in
        // UserDefaults across relaunches (the E7/E8.1 seeder trap), and
        // a leftover one would shift the strength hero off the pinned
        // expectation. Same wipe --debug-move performs.
        MoveManualStore.wipe()
        let energyType = HKQuantityType(.activeEnergyBurned)
        let distanceType = HKQuantityType(.distanceWalkingRunning)
        try? await healthStore.requestAuthorization(
            toShare: [HKWorkoutType.workoutType(), energyType, distanceType],
            read: Self.readTypes
        )
        UserDefaults.standard.set(true, forKey: Self.requestedKey)

        // Idempotent: HealthKit accumulates, so a second seeding run
        // would double the strength count and break every pinned
        // expectation. An app may delete its own samples; do so.
        for type in [HKWorkoutType.workoutType(), energyType, distanceType] {
            _ = try? await healthStore.deleteObjects(
                of: type,
                predicate: HKQuery.predicateForObjects(from: HKSource.default())
            )
        }

        let cal = Calendar.current
        let now = Date()
        func daysAgo(_ d: Int, hour: Int) -> Date {
            let day = cal.date(byAdding: .day, value: -d, to: now) ?? now
            return cal.date(bySettingHour: hour, minute: 10, second: 0, of: day) ?? day
        }

        // Workouts through HKWorkoutBuilder (the supported historical-
        // save path; the HKWorkout initializers are deprecated).
        let workouts: [(HKWorkoutActivityType, Date, TimeInterval)] = [
            (.traditionalStrengthTraining, daysAgo(2, hour: 18), 32 * 60),
            (.functionalStrengthTraining, daysAgo(5, hour: 7), 28 * 60),
            (.yoga, daysAgo(1, hour: 8), 20 * 60),
            (.walking, cal.startOfDay(for: now).addingTimeInterval(9 * 3600), 24 * 60),
        ]
        for (activity, start, duration) in workouts {
            let config = HKWorkoutConfiguration()
            config.activityType = activity
            let builder = HKWorkoutBuilder(
                healthStore: healthStore, configuration: config, device: .local()
            )
            do {
                try await builder.beginCollection(at: start)
                try await builder.endCollection(at: start.addingTimeInterval(duration))
                _ = try await builder.finishWorkout()
            } catch {
                print("[MovementService] QA workout seed failed: \(error)")
            }
        }

        // Standalone quantity samples, timestamped inside today —
        // the shape a phone/watch writes outside workouts.
        let morning = cal.startOfDay(for: now).addingTimeInterval(8 * 3600)
        let quantities: [(HKQuantityType, HKUnit, Double, Date)] = [
            (energyType, .kilocalorie(), 200, morning),
            (energyType, .kilocalorie(), 112, morning.addingTimeInterval(3 * 3600)),
            (distanceType, .meter(), 2_600, morning),
            (distanceType, .meter(), 800, morning.addingTimeInterval(3 * 3600)),
        ]
        for (type, unit, value, date) in quantities {
            let sample = HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: unit, doubleValue: value),
                start: date, end: date.addingTimeInterval(60)
            )
            try? await healthStore.save(sample)
        }

        // The launch bootstrap already ran refresh() and stamped
        // lastSyncedAt; without force the 900 s guard would hand the
        // proof stale nils.
        await refresh(force: true)
    }
    #endif
}
