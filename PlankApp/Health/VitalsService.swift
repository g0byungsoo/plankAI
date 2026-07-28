import Foundation
import Observation
import HealthKit

// MARK: - VitalsService
//
// The passive vitals rail (docs/app_v7/04_CLINICAL_CHECKLIST.md §4
// ship #2): resting heart rate, HRV (SDNN), cardio fitness (VO2max
// estimate), and sleeping respiratory rate — the between-visit
// safety-and-fitness streams clinics read, already sitting in
// HealthKit. Read-only, zero input, zero new UI asks: the rail
// simply appears when the data does.
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
        /// Most recent nightly HRV (SDNN, ms).
        var hrvLatest: Int?
        /// Most recent VO2max estimate (ml/kg·min).
        var vo2Max: Double?
        /// Most recent sleeping respiratory rate (breaths/min).
        var respiratoryRate: Double?

        var isEmpty: Bool {
            restingHR7d == nil && hrvLatest == nil
                && vo2Max == nil && respiratoryRate == nil
        }
    }

    private(set) var read = Read()
    private(set) var lastSyncedAt: Date?

    private let healthStore = HKHealthStore()

    /// The four read-only quantity types the rail lives on. Shared so
    /// the steps/sleep connect sheets can carry them (one system
    /// sheet, every passive stream granted together).
    static var readTypes: Set<HKObjectType> {
        var set = Set<HKObjectType>()
        for id: HKQuantityTypeIdentifier in [
            .restingHeartRate, .heartRateVariabilitySDNN,
            .vo2Max, .respiratoryRate,
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
        if let type = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN),
           let latest = await latestSample(type, unit: .secondUnit(with: .milli)) {
            next.hrvLatest = Int(latest.rounded())
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .vo2Max) {
            let unit = HKUnit.literUnit(with: .milli)
                .unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .minute()))
            if let latest = await latestSample(type, unit: unit) {
                next.vo2Max = latest
            }
        }
        if let type = HKQuantityType.quantityType(forIdentifier: .respiratoryRate),
           let latest = await latestSample(type, unit: HKUnit.count().unitDivided(by: .minute())) {
            next.respiratoryRate = latest
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
