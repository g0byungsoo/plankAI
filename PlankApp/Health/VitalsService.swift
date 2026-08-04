import Foundation
import Observation
import HealthKit

// MARK: - VitalsService
//
// The passive vitals rail (docs/app_v7/04_CLINICAL_CHECKLIST.md §4
// ship #2): resting heart rate + body composition — the between-
// visit streams that actually render. Read-only, zero input, zero
// new UI asks: the rail simply appears when the data does.
//
// v9 P0 truth pass (docs/app_v9, W5/D5): HRV, VO2max, respiratory
// rate, and blood pressure LEFT the request set — read-but-never-
// rendered violates L5 (never request what nothing shows). HRV
// returns WITH its rendered recovery surface (P3); the others
// return only if a surface ever earns them.
//
// Clinical framing (observed-never-prescribed, same stance as the
// overnight window): values display as trends against her own
// baseline. No thresholds, no alerts, no interpretation — a resting
// heart that reads "climbing" is a line she can bring to a clinician,
// never a diagnosis. (GLP-1 class effect: resting HR +1-4 bpm — the
// reason the trend is worth keeping visible.)
//
// Permission model: silent bootstrap (mirrors SleepService) — if a
// prior grant covers the types, data flows; otherwise the rail stays
// invisible. requestAccess() exists for the future connect line, and
// the steps/sleep connect sheets carry these read types so new users
// grant everything in one system sheet.

@MainActor
@Observable
final class VitalsService {
    static let shared = VitalsService()

    struct Read: Equatable {
        /// 7-day mean resting heart rate, whole bpm.
        var restingHR7d: Int?
        /// 30-day mean resting heart rate (the personal baseline).
        var restingHRBaseline: Int?
        /// Latest body composition from her own smart scale — the
        /// muscle-preservation stream (Prado 2024).
        var bodyFatPct: Double?
        var leanMassKg: Double?

        var isEmpty: Bool {
            restingHR7d == nil && bodyFatPct == nil && leanMassKg == nil
        }
    }

    private(set) var read = Read()
    private(set) var lastSyncedAt: Date?

    private let healthStore = HKHealthStore()

    /// The read-only quantity types the rail lives on — exactly the
    /// ones with rendered surfaces (L5). Shared so the steps/sleep
    /// connect sheets can carry them (one system sheet, every
    /// passive stream granted together).
    static var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        for id: HKQuantityTypeIdentifier in [
            .restingHeartRate,
            // Passive-if-owned: a smart scale she already uses is a
            // real composition source (never a photo — L3).
            .bodyFatPercentage, .leanBodyMass,
        ] {
            if let t = HKQuantityType.quantityType(forIdentifier: id) {
                set.insert(t)
            }
        }
        return set
    }

    private init() {}

    // MARK: - Bootstrap + access

    /// Silent: try to read; never prompts. Called at launch beside
    /// the steps/sleep bootstraps.
    func bootstrap() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        await refresh()
    }

    /// Surfaces the system sheet for the vitals read types (a future
    /// quiet "connect vitals" line; unused by v1 chrome).
    func requestAccess() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        do {
            try await healthStore.requestAuthorization(
                toShare: [], read: Self.readTypes
            )
        } catch {
            #if DEBUG
            print("[VitalsService] requestAuthorization failed: \(error)")
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

        var next = Read()

        if let type = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) {
            let bpm = HKUnit.count().unitDivided(by: .minute())
            if let avg7 = await discreteAverage(type, unit: bpm, days: 7) {
                next.restingHR7d = Int(avg7.rounded())
            }
            if let avg30 = await discreteAverage(type, unit: bpm, days: 30) {
                next.restingHRBaseline = Int(avg30.rounded())
            }
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .bodyFatPercentage),
           let latest = await latestSample(type, unit: .percent()) {
            next.bodyFatPct = latest * 100
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .leanBodyMass),
           let latest = await latestSample(type, unit: .gramUnit(with: .kilo)) {
            next.leanMassKg = latest
        }

        read = next
        lastSyncedAt = .now
    }

    // MARK: - Queries

    private func discreteAverage(
        _ type: HKQuantityType, unit: HKUnit, days: Int
    ) async -> Double? {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: .now)!
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: .now, options: .strictStartDate
        )
        return await withCheckedContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .discreteAverage
            ) { _, stats, _ in
                continuation.resume(
                    returning: stats?.averageQuantity()?.doubleValue(for: unit)
                )
            }
            healthStore.execute(query)
        }
    }

    private func latestSample(
        _ type: HKQuantityType, unit: HKUnit
    ) async -> Double? {
        let start = Calendar.current.date(byAdding: .day, value: -14, to: .now)!
        let predicate = HKQuery.predicateForSamples(
            withStart: start, end: .now, options: .strictStartDate
        )
        let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
        return await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: type, predicate: predicate,
                limit: 1, sortDescriptors: [sort]
            ) { _, samples, _ in
                let value = (samples?.first as? HKQuantitySample)?
                    .quantity.doubleValue(for: unit)
                continuation.resume(returning: value)
            }
            healthStore.execute(query)
        }
    }
}

// MARK: - VitalsTrend (pure — the trend word, tested)

/// The resting-heart trend word against her own baseline. Pure math
/// so the bounds live under test: within ±2 bpm of the 30-day
/// baseline reads steady; 3+ under reads easing; 3+ over reads
/// climbing. No thresholds against population norms — her baseline
/// is the only reference (observed, never graded).
enum VitalsTrend {
    static func word(current: Int, baseline: Int) -> String {
        let delta = current - baseline
        if delta <= -3 { return "easing" }
        if delta >= 3 { return "climbing" }
        return "steady"
    }

    /// The ledger value line: "62 · steady" when a baseline exists,
    /// the bare number while the baseline is still forming.
    static func ledgerValue(current: Int, baseline: Int?) -> String {
        guard let baseline, baseline > 0 else { return "\(current)" }
        return "\(current) · \(word(current: current, baseline: baseline))"
    }
}
