import Foundation
import Observation
import HealthKit
import SwiftData
import PlankSync

// MARK: - BodyMassImportService
//
// v1.1 Becoming P2 — reads Apple Health body-mass samples (smart
// scales like Withings/Eufy/Renpho write here, as do other apps) into
// WeightLogRecord. The round-2 cohort research made this the single
// highest-leverage build: typed weight logging runs at ~3% of WAU
// because typing your own scale number is an act of self-verdict;
// importing the scale removes the act entirely and the EMA trend
// artifact lights up on its own.
//
// Policy:
//   - READ ONLY. JeniFit never writes body mass back to Health.
//   - One-per-day stays canonical: the latest HK sample per calendar
//     day maps to at most one WeightLogRecord.
//   - A manual log always wins its day — HK never overwrites a row
//     the user typed. An HK-sourced row updates in place when the
//     sample for its day changes (re-weigh on the scale).
//   - kg canonical (HK unit converted at the boundary).
//
// Permission model mirrors StepsService: read-status is opaque on
// HealthKit, so .denied is inferred from a post-request empty read
// when other signals say data should exist. We keep it simpler here:
// after a grant we just import; an empty result is a valid state
// (no scale, no other app) and renders nothing.

@MainActor
@Observable
final class BodyMassImportService {
    static let shared = BodyMassImportService()

    enum Authorization: Equatable {
        case unavailable
        case notDetermined
        case requested   // sheet shown at least once; HK won't say yes/no for reads
    }

    private(set) var authStatus: Authorization
    private(set) var lastImportedAt: Date?
    /// Rows inserted or updated by the most recent import (debug/QA).
    private(set) var lastImportCount: Int = 0

    private let healthStore = HKHealthStore()
    private static let requestedKey = "bodyMassImportRequested"
    /// Import window — far enough back to seed a meaningful trend,
    /// short enough to stay cheap. Older history adds nothing the
    /// EMA needs.
    private static let importWindowDays = 90

    private init() {
        if !HKHealthStore.isHealthDataAvailable() {
            authStatus = .unavailable
        } else if UserDefaults.standard.bool(forKey: Self.requestedKey) {
            authStatus = .requested
        } else {
            authStatus = .notDetermined
        }
    }

    private var bodyMassType: HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: .bodyMass)
    }

    /// Fires the iOS permission sheet (first time only), then imports.
    func requestAccessAndImport(userId: String, into context: ModelContext) async {
        guard let type = bodyMassType, authStatus != .unavailable else { return }
        try? await healthStore.requestAuthorization(toShare: [], read: [type])
        UserDefaults.standard.set(true, forKey: Self.requestedKey)
        authStatus = .requested
        await importRecent(userId: userId, into: context)
    }

    /// Silent import — call at launch + Becoming appear once the
    /// permission sheet has been shown. No-op before that (never
    /// prompts from a passive path).
    func importIfEnabled(userId: String, into context: ModelContext) async {
        guard authStatus == .requested else { return }
        await importRecent(userId: userId, into: context)
    }

    private func importRecent(userId: String, into context: ModelContext) async {
        guard let type = bodyMassType, !userId.isEmpty else { return }
        let cal = Calendar.current
        guard let cutoff = cal.date(byAdding: .day, value: -Self.importWindowDays, to: .now) else { return }

        let samples = await fetchSamples(type: type, since: cutoff)
        guard !samples.isEmpty else {
            lastImportedAt = .now
            lastImportCount = 0
            return
        }

        // Latest sample per calendar day.
        var latestPerDay: [Date: HKQuantitySample] = [:]
        for sample in samples {
            let day = cal.startOfDay(for: sample.startDate)
            if let held = latestPerDay[day], held.startDate >= sample.startDate { continue }
            latestPerDay[day] = sample
        }

        // Existing rows in the window, newest-first irrelevant here.
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId && $0.loggedAt >= cutoff }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        var existingByDay: [Date: WeightLogRecord] = [:]
        for row in existing {
            existingByDay[cal.startOfDay(for: row.loggedAt)] = row
        }

        var touched: [WeightLogRecord] = []
        let kgUnit = HKUnit.gramUnit(with: .kilo)

        for (day, sample) in latestPerDay {
            let kg = sample.quantity.doubleValue(for: kgUnit)
            guard kg > 20, kg < 400 else { continue }

            if let row = existingByDay[day] {
                // Manual rows always win their day.
                guard row.source == "healthkit" else { continue }
                if abs(row.weightKg - kg) > 0.01 {
                    row.weightKg = kg
                    row.loggedAt = sample.startDate
                    row.pendingUpsert = true
                    touched.append(row)
                }
            } else {
                let row = WeightLogRecord(
                    userId: userId,
                    weightKg: kg,
                    loggedAt: sample.startDate,
                    source: "healthkit"
                )
                context.insert(row)
                touched.append(row)
            }
        }

        guard !touched.isEmpty else {
            lastImportedAt = .now
            lastImportCount = 0
            return
        }
        try? context.save()
        lastImportedAt = .now
        lastImportCount = touched.count
        for row in touched {
            await AppSync.shared.upsertWeightLog(row)
        }
    }

    private func fetchSamples(type: HKQuantityType, since cutoff: Date) async -> [HKQuantitySample] {
        await withCheckedContinuation { continuation in
            let predicate = HKQuery.predicateForSamples(withStart: cutoff, end: nil)
            let sort = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: true)
            let query = HKSampleQuery(
                sampleType: type,
                predicate: predicate,
                limit: HKObjectQueryNoLimit,
                sortDescriptors: [sort]
            ) { _, results, _ in
                continuation.resume(returning: (results as? [HKQuantitySample]) ?? [])
            }
            healthStore.execute(query)
        }
    }
}
