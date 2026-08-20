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
    private var observerQuery: HKObserverQuery?
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

    /// Another surface's system sheet included bodyMass (onboarding's
    /// connect-health ask does). Records that the ask happened so the
    /// silent import path activates — the grant stops being wasted
    /// (v9 P0, W3). Idempotent.
    func noteSystemAskIncludedBodyMass() {
        guard authStatus == .notDetermined else { return }
        UserDefaults.standard.set(true, forKey: Self.requestedKey)
        authStatus = .requested
    }

    /// v9 P0 (W4): new scale samples land without an app open.
    /// Observer + background delivery — active only after the ask;
    /// never prompts. Safe to call every launch.
    func startObservingIfEnabled(userId: String, into context: ModelContext) {
        guard authStatus == .requested, observerQuery == nil,
              let type = bodyMassType, !userId.isEmpty else { return }
        let query = HKObserverQuery(sampleType: type, predicate: nil) {
            [weak self] _, completion, error in
            defer { completion() }   // background-delivery contract
            guard error == nil, let self else { return }
            Task { @MainActor in
                await self.importIfEnabled(userId: userId, into: context)
            }
        }
        observerQuery = query
        healthStore.execute(query)
        healthStore.enableBackgroundDelivery(for: type, frequency: .immediate) { _, _ in }
    }

    #if DEBUG
    /// QA-only (v9 P0 proof): writes two bodyMass samples (today +
    /// three days back) so the sim — which has no scale — can
    /// exercise the full passive path: write → observer/import →
    /// trend across two distinct days. Requests write+read in one
    /// sheet. Never compiled into release.
    func debugWriteSample(kg: Double) async {
        guard let type = bodyMassType else { return }
        try? await healthStore.requestAuthorization(toShare: [type], read: [type])
        UserDefaults.standard.set(true, forKey: Self.requestedKey)
        authStatus = .requested
        let kgUnit = HKUnit.gramUnit(with: .kilo)
        let earlier = Calendar.current.date(byAdding: .day, value: -3, to: .now) ?? .now
        for (value, date) in [(kg, Date.now), (kg + 0.7, earlier)] {
            let sample = HKQuantitySample(
                type: type,
                quantity: HKQuantity(unit: kgUnit, doubleValue: value),
                start: date, end: date
            )
            try? await healthStore.save(sample)
        }
    }
    #endif

    // MARK: - The per-day rule (v25 §44)

    /// What the importer may do with one calendar day.
    enum ImportDecision: Equatable {
        /// No row for that day yet, and nothing forbids one.
        case insert
        /// A `healthkit` row already holds the day; the scale may
        /// correct it in place (a re-weigh).
        case update
        /// Leave the day alone.
        case skip
    }

    /// v25 §44 — **A DAY SHE CLEARED IS NOT A DAY WITH NO ROW.**
    ///
    /// This importer's whole rule was "a day with no local row is a day
    /// I create one for", and the row it creates carries a FRESH uuid.
    /// So once `34` gave the weigh-in a `remove it`, the two halves
    /// fought: she removed the row, the deletion ledger recorded the id
    /// she removed, and the very next launch re-read Apple Health, saw
    /// an empty day, and put the number back under a name the ledger had
    /// never heard of. The screen promises *"you can fix or remove any
    /// of them"*, and for the commonest weigh-in source in this product
    /// — a smart scale writing into Health — it was not true.
    ///
    /// The resurrected number is not cosmetic: the freshest weigh-in is
    /// the numerator of BOTH daily targets (`TargetsService
    /// .resolvedWeightKg`) and a row in the clinician packet's weight
    /// section.
    ///
    /// Pure over (day, existing source, ledger), so the rule is a
    /// sentence a test can read rather than a branch inside an async
    /// HealthKit walk (`36` §2).
    ///
    /// The two rules that were already here are unchanged and pinned by
    /// a control test: **a row she typed always wins its day**, and a
    /// `healthkit` row is the one the scale may correct in place.
    /// Pass 51 — two additions to the §44 rule, both timezone work:
    /// the injected `calendar` is now HONORED (it used to be an inert
    /// parameter — the day string always came from the device zone, so
    /// the whole timezone axis was structurally untestable), and the
    /// sample's INSTANT is checked against the zone-proof instant
    /// tombstone, so a weigh-in she cleared in Los Angeles stays
    /// cleared when the same Health sample is re-read in Tokyo.
    @MainActor
    static func importDecision(
        forDay day: Date,
        sampleAt: Date? = nil,
        existingSource: String?,
        userId: String,
        calendar: Calendar = .current
    ) -> ImportDecision {
        if let existingSource {
            return existingSource == "healthkit" ? .update : .skip
        }
        var gregorian = Calendar(identifier: .gregorian)
        gregorian.timeZone = calendar.timeZone
        let c = gregorian.dateComponents([.year, .month, .day], from: day)
        let dayKey = String(
            format: "%04d-%02d-%02d", c.year ?? 0, c.month ?? 0, c.day ?? 0
        )
        let cleared = DeletionLedger.clearedWeightDayId(
            userId: userId, dayKey: dayKey
        )
        if DeletionLedger.contains(id: cleared, userId: userId) { return .skip }
        if let sampleAt,
           DeletionLedger.contains(
               id: DeletionLedger.clearedWeightInstantId(userId: userId, at: sampleAt),
               userId: userId
           ) {
            return .skip
        }
        return .insert
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

        // p55 — EARLIEST sample per calendar day (was latest). The
        // whole trend fold is calibrated on the fasted-morning bias
        // (WeightSeries reduces to earliest-of-day), so keeping the
        // day's LAST Health reading silently made every scale user's
        // series an evening series — the one row per day the import
        // writes IS what the reduction later returns.
        var latestPerDay: [Date: HKQuantitySample] = [:]
        for sample in samples {
            let day = cal.startOfDay(for: sample.startDate)
            if let held = latestPerDay[day], held.startDate <= sample.startDate { continue }
            latestPerDay[day] = sample
        }

        // Existing rows in the window, newest-first irrelevant here.
        let descriptor = FetchDescriptor<WeightLogRecord>(
            predicate: #Predicate { $0.userId == userId && $0.loggedAt >= cutoff }
        )
        let existing = (try? context.fetch(descriptor)) ?? []
        // Pass 51 — deterministic day representative: when a day holds
        // two rows the fetch order used to decide which one the
        // per-day rule saw, making manual-wins order-dependent. A
        // MANUAL row is always the day's representative (it is the row
        // the rule protects); among equals the earliest wins.
        var existingByDay: [Date: WeightLogRecord] = [:]
        for row in existing {
            let day = cal.startOfDay(for: row.loggedAt)
            if let held = existingByDay[day] {
                let heldManual = held.source != "healthkit"
                let rowManual = row.source != "healthkit"
                if heldManual && !rowManual { continue }
                if heldManual == rowManual, held.loggedAt <= row.loggedAt { continue }
            }
            existingByDay[day] = row
        }

        var touched: [WeightLogRecord] = []
        let kgUnit = HKUnit.gramUnit(with: .kilo)

        for (day, sample) in latestPerDay {
            let kg = sample.quantity.doubleValue(for: kgUnit)
            guard kg > 20, kg < 400 else { continue }

            let existingRow = existingByDay[day]
            switch Self.importDecision(
                forDay: day, sampleAt: sample.startDate,
                existingSource: existingRow?.source, userId: userId
            ) {
            case .skip:
                continue
            case .update:
                guard let row = existingRow else { continue }
                if abs(row.weightKg - kg) > 0.01 {
                    row.weightKg = kg
                    row.loggedAt = sample.startDate
                    row.pendingUpsert = true
                    touched.append(row)
                }
            case .insert:
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
        #if DEBUG
        NSLog("[BodyMassImport] imported %d row(s) from Apple Health", touched.count)
        #endif
        for row in touched {
            await AppSync.shared.upsertWeightLog(row)
        }
        // v1.1.1 — HealthKit imports also bump the cross-view
        // signal so AnalyticsView's trend canvas redraws even
        // when the user wasn't on the Becoming tab during the
        // sync. Matches PlanView + saveWeightLog behavior.
        NotificationCenter.default.post(name: .weightLogDidChange, object: nil)
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
